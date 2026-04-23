# Pedidos de Venda

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                  SALES ORDER — FLUXO COMPLETO                        ║
╚══════════════════════════════════════════════════════════════════════╝

  FLUXO DE STATUS:

    ┌───────┐   ┌──────────────────┐   ┌─────────┐   ┌─────────┐
    │ draft │──►│awaiting_approval │──►│approved │──►│ picking │
    └───────┘   │    (opcional)    │   └─────────┘   └────┬────┘
        │       └──────────────────┘        ▲             │
        │                                   │             │
        └───────────────────────────────────┘             │
         (quando a etapa de approval é desabilitada)      │
                                                          ▼
    ┌───────────┐      ┌───────────┐      ┌──────────────────────┐
    │ cancelled │      │ delivered │◄─────│      invoiced        │
    └───────────┘      └───────────┘      │  (parcial ou total)  │
          ▲                               └──────────┬───────────┘
          │                                          │
          │ só antes de invoiced                     │ dispara
          │                                          ▼
          │                         ┌────────────────────────────┐
          │                         │         INVOICE            │
          │                         │  (1 pedido → N invoices)   │
          │                         └──────────┬─────────────────┘
          │                                    │
          │                         ┌──────────┴─────────────┐
          │                         │                        │
          │                         ▼                        ▼
          │              ┌─────────────────┐    ┌─────────────────────┐
          │              │  STOCK MOVEMENT │    │  CAR (a receber)    │
          │              │  type: out      │    │  por parcela        │
          │              │  por SKU        │    │  baseado em         │
          │              └─────────────────┘    │  payment_terms      │
          │                                     └─────────────────────┘
          │
    REGRAS DE CANCELAMENTO:
      draft / awaiting_approval ──► cancela livremente
      approved / picking        ──► cancela com confirmação
      invoiced / delivered      ──► não pode cancelar (exige devolução)

  ESTRUTURA DO SALES ORDER:

    SALES ORDER
    ├── customer_id   ──► CONTACT
    ├── seller_id     ──► SELLER
    ├── price_list_id ──► PRICE LIST
    └── items[]
        ├── sku_id    ──► SKU
        ├── quantity
        ├── unit_price (da tabela de preço ou manual)
        ├── discount_pct
        └── total
```

Um sales order registra a intenção de vender produtos a um customer. Dispara a saída de estoque, o faturamento e a geração de contas a receber.

## Fluxo de status

```
draft → [awaiting_approval] → approved → picking → invoiced → delivered → cancelled
```

A etapa `awaiting_approval` é opcional e configurável por organization. Quando desabilitada, os pedidos vão direto de `draft` para `approved`.

**Exceção — credit limit excedido**: mesmo em orgs que desabilitam a etapa, se o customer tem `credit_limit` definido e

```
(SUM(car.amount - car.paid_amount) WHERE car.customer_id = X
   AND car.status IN (pending, partial, overdue))
   + sales_order.total
> contact.credit_limit
```

o pedido é forçado para `awaiting_approval` na saída de `draft`. Para desabilitar a verificação, deixar `contact.credit_limit = null`.

| Status | Comportamento |
|---|---|
| `draft` | Em construção. Totalmente editável. Sem reserva de estoque. |
| `awaiting_approval` | Enviado para análise. Read-only para o criador. |
| `approved` | Autorizado a prosseguir. Reserva de estoque pode ser aplicada (futuro). |
| `picking` | Itens sendo separados para envio. |
| `invoiced` | Ao menos uma invoice foi emitida. Estoque baixado. CAR gerado. |
| `delivered` | Todos os itens confirmados como recebidos pelo customer. |
| `cancelled` | Anulado. Não gera movimentos. Imutável. |

Um pedido passa para `invoiced` assim que a primeira invoice parcial é emitida. Permanece em `invoiced` até ser totalmente entregue.

## Sales order

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `number` | string | Número legível do pedido (ex.: `SO-000001`). Gerado via `document_sequence` — ver `01-foundation.md` |
| `status` | enum | Ver fluxo de status acima |
| `customer_id` | uuid | FK → `contact` (type precisa incluir `customer`) |
| `seller_id` | uuid | FK → `seller`. Nullable |
| `price_list_id` | uuid | FK → `price_list`. Tabela de preço usada neste pedido |
| `shipping_address_id` | uuid | FK → `contact_address`. Nullable |
| `payment_term_id` | uuid | FK → `payment_term` (ver `09-financial.md`). Pré-preenchido pelo `default_payment_term_id` do contact, editável |
| `subtotal` | decimal | Soma dos totais dos itens antes do desconto do pedido |
| `discount_total` | decimal | Valor do desconto aplicado no pedido |
| `total` | decimal | `subtotal - discount_total` |
| `notes` | text | Observações visíveis ao customer. Nullable |
| `internal_notes` | text | Observações internas. Não visíveis ao customer. Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

## Itens do sales order

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `sales_order_id` | uuid | FK → `sales_order` |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | |
| `unit_price` | decimal | Preço no momento do pedido (da tabela de preço ou definido manualmente) |
| `discount_pct` | decimal | Percentual de desconto no item. Default `0` |
| `discount_amount` | decimal | Calculado: `unit_price × quantity × discount_pct / 100` |
| `total` | decimal | Calculado: `unit_price × quantity - discount_amount` |

## Faturamento parcial

Um sales order pode gerar várias invoices. Isso atende cenários em que os itens saem em lotes ou são faturados em momentos diferentes.

- Cada invoice referencia o `sales_order_id` que a originou
- Cada `invoice_item` aponta para o `sales_order_item_id` que cobre
- O pedido acompanha a quantidade total já faturada por item — quando todos os itens estão totalmente faturados, o status avança para `invoiced`

## O que acontece no faturamento

Quando uma invoice é emitida a partir de um sales order:

1. **Estoque baixado** — um stock movement de `out` é gerado por SKU.
2. **CAR gerado** — uma entrada de CAR por parcela, percorrendo os `payment_term_installment` do `payment_term_id` do pedido (ver `09-financial.md`).
3. **Snapshot fiscal** — NCM, CEST, CFOP e CSTs são copiados do `tax_group` para cada `invoice_item` nesse momento. Edições futuras no produto não afetam este registro.
4. **Campo NF** — `nf_number` é um campo de texto livre para o usuário registrar o número da nota emitida externamente (MVP). Emissão nativa de NF-e é pós-MVP.

## Regras de cancelamento

- Pedidos em `draft` ou `awaiting_approval` podem ser cancelados livremente.
- Pedidos em `approved` ou `picking` podem ser cancelados com confirmação.
- Pedidos em `invoiced` ou `delivered` não podem ser cancelados — é necessário um processo de devolução/crédito (pós-MVP).
- Pedidos `cancelled` são imutáveis e não geram movimentos de estoque ou financeiros.
