# Faturas

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                    INVOICE — FLUXO DE EMISSÃO                        ║
╚══════════════════════════════════════════════════════════════════════╝

    ┌────────────────┐
    │  SALES ORDER   │
    │  (approved /   │
    │   picking)     │
    └───────┬────────┘
            │ usuário dispara faturamento
            │ (itens totais ou parciais)
            ▼
    ┌────────────────────────────────────────────────────────────┐
    │                        INVOICE                             │
    │                     status: draft                          │
    └───────────────────────────┬────────────────────────────────┘
                                │ usuário emite
                                ▼
    ┌────────────────────────────────────────────────────────────┐
    │                        INVOICE                             │
    │                     status: issued  ◄── imutável           │
    │                                                            │
    │  customer_snapshot (jsonb) ◄── congelado na emissão        │
    │  nf_number (texto livre, MVP)                              │
    └────────────────┬───────────────────────────────────────────┘
                     │
         ┌───────────┼────────────────────┐
         │           │                    │
         ▼           ▼                    ▼
  ┌─────────────┐  ┌─────────────────┐  ┌───────────────────────┐
  │   STOCK     │  │  CAR (contas    │  │    INVOICE ITEMS      │
  │  MOVEMENT   │  │   a receber)    │  │                       │
  │             │  │                 │  │  snapshot fiscal:     │
  │  type: out  │  │  1 por parcela  │  │  ncm, cest, cfop      │
  │  por SKU    │  │  percorrendo    │  │  origin               │
  │  ref: esta  │  │  payment_term_  │  │  icms/pis/cofins/ipi  │
  │  invoice    │  │  installment    │  │  cst + rates          │
  └─────────────┘  └─────────────────┘  │  ◄── copiado do       │
                                        │      tax_group AGORA  │
                                        │      congelado        │
                                        └───────────────────────┘

  SE A INVOICE FOR CANCELADA:

    issued ──► cancelled
         │
         ├──► STOCK MOVEMENT (type: adjustment_in,
         │    reference_type: invoice_cancellation) reverte a saída
         │    com o mesmo unit_cost do `out` original.
         │    Custo médio NÃO é recalculado.
         └──► todos os CARs ligados ficam como cancelled

  FATURAMENTO PARCIAL:
    1 Sales Order ──► Invoice A (itens 1-3) ──► issued
                 └──► Invoice B (item 4)    ──► issued
    O pedido acompanha a quantidade acumulada já faturada por item.
    Status do pedido → delivered quando todos os itens estão
    totalmente faturados + entregues.
```

Uma invoice representa o registro formal de uma venda. É sempre gerada a partir de um sales order (total ou parcial) e dispara a saída de estoque e a criação de contas a receber.

## Status

| Status | Comportamento |
|---|---|
| `draft` | Em preparação. **Editável**. Sem efeitos de estoque ou financeiros. Pode ser descartada. |
| `issued` | Finalizada. Estoque baixado. CAR gerado. Snapshots fiscal e do customer congelados. Imutável. |
| `cancelled` | Anulada. Movimentos de estoque revertidos. CARs associados cancelados. |

### Ciclo de vida do draft

- Disparado pelo usuário a partir de um sales_order em `approved` ou `picking` (ação "preparar invoice").
- Sistema cria invoice em `draft` copiando itens, quantidades e `unit_price` do sales_order.
- **Faturamento parcial**: o usuário escolhe quais itens e quais quantidades entram no draft. Múltiplos drafts podem coexistir para o mesmo sales_order.
- Draft é editável: quantidades, preços e notas podem ser ajustados.
- Draft pode ser descartado (deleção livre) enquanto estiver em `draft`.
- Snapshots (fiscal e `customer_snapshot`) **só acontecem na transição `draft → issued`**, não antes.

## Invoice

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `number` | string | Número legível interno (ex.: `INV-000001`). Gerado via `document_sequence` — ver `01-foundation.md`. Não é o número da NF-e (que vai em `nf_number`) |
| `sales_order_id` | uuid | FK → `sales_order` |
| `status` | enum | `draft \| issued \| cancelled` |
| `customer_snapshot` | jsonb | Dados fiscais do customer no momento da emissão: cnpj/cpf, legal_name, state_registration, endereço |
| `subtotal` | decimal | Soma dos totais dos itens |
| `discount_total` | decimal | |
| `total` | decimal | |
| `nf_number` | string | Texto livre. O usuário registra o número da NF emitida externamente. Nullable (MVP) |
| `nf_issued_at` | timestamp | Nullable |
| `notes` | text | Nullable |
| `issued_at` | timestamp | Preenchido quando o status vai para `issued`. Nullable |
| `cancelled_at` | timestamp | Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

## Invoice items

Cada item carrega um snapshot fiscal completo copiado do `tax_group` do produto no momento da emissão. Isso garante que o histórico fiscal nunca seja afetado por edições futuras no produto.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `invoice_id` | uuid | FK → `invoice` |
| `sales_order_item_id` | uuid | FK → `sales_order_item` |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | |
| `unit_price` | decimal | |
| `discount_amount` | decimal | |
| `total` | decimal | |
| — snapshot fiscal — | | Copiado do `tax_group` na emissão |
| `ncm` | string | |
| `cest` | string | Nullable |
| `cfop` | string | |
| `origin` | string | |
| `icms_cst` | string | |
| `pis_cst` | string | |
| `cofins_cst` | string | |
| `ipi_cst` | string | Nullable |
| `icms_rate` | decimal | Nullable |
| `pis_rate` | decimal | Nullable |
| `cofins_rate` | decimal | Nullable |
| `ipi_rate` | decimal | Nullable |

## O que acontece quando uma invoice é emitida

1. **Saída de estoque** — um stock movement de `out` é gerado por SKU com `reference_type = sales_invoice`.
2. **CAR gerado** — uma entrada de CAR por `payment_term_installment` do `payment_term_id` do pedido. Detalhes do cálculo de `due_date` e `amount` em `09-financial.md`.
3. **Snapshot fiscal** — todos os campos fiscais copiados do `tax_group` para cada `invoice_item`.
4. **Snapshot do customer** — dados fiscais atuais do customer copiados para `customer_snapshot` (jsonb) na invoice.

## O que acontece quando uma invoice é cancelada

1. **Reversão de estoque** — um movimento de `adjustment_in` é gerado por SKU com `reference_type = invoice_cancellation` e `reference_id` apontando para esta invoice. O `unit_cost` replica o do movimento `out` original para zerar o impacto no histórico. Custo médio **não** é recalculado.
2. **Cancelamento do CAR** — todos os registros de contas a receber ligados a esta invoice ficam com status `cancelled`.
3. A invoice passa a ser imutável com status `cancelled`.

## Faturamento parcial

Um sales order pode ser faturado em vários lotes. Cada invoice cobre um subconjunto dos itens do pedido ou quantidades parciais. O sales order acompanha as quantidades acumuladas por item para saber quando está concluído.
