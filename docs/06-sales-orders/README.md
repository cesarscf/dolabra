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
         (quando a org tem requires_sales_order_approval  │
          desligado e o credit_limit não força)           │
                                                          ▼
    ┌───────────┐                          ┌──────────────────────┐
    │ cancelled │                          │      invoiced        │
    └───────────┘                          │  (parcial ou total)  │
          ▲                                └──────────┬───────────┘
          │                                           │
          │ só antes de invoiced                      │ dispara
          │                                           ▼
          │                          ┌────────────────────────────┐
          │                          │         INVOICE            │
          │                          │  (1 pedido → N invoices)   │
          │                          └──────────┬─────────────────┘
          │                                     │
          │                          ┌──────────┴─────────────┐
          │                          │                        │
          │                          ▼                        ▼
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
      invoiced                  ──► não pode cancelar (exige devolução, pós-MVP)

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
draft → [awaiting_approval] → approved → picking → invoiced → cancelled
   ▲           │
   └───────────┘
   (rejeição volta para draft — ver B19)
```

A etapa `awaiting_approval` é controlada pelo setting `organization.requires_sales_order_approval` (ver [Foundation → A7](../01-foundation/README.md#a7-setting-de-aprovação-por-organization)). Quando `false`, os pedidos vão direto de `draft` para `approved`.

**Exceção — credit limit excedido**: mesmo em orgs com o setting desligado, se o customer tem `credit_limit` definido e

```
(SUM(car.amount - car.paid_amount) WHERE car.customer_id = X
   AND car.status IN (pending, partial))
   + sales_order.total
> contact.credit_limit
```

o pedido é forçado para `awaiting_approval` na saída de `draft`. Para desabilitar a verificação, deixar `contact.credit_limit = null`.

> `overdue` não entra na soma — não é status persistido (ver [Financial → B4](../09-financial/README.md#b4-overdue-na-leitura-ou-em-job)). CARs vencidos continuam em `pending`/`partial`.

| Status | Comportamento |
|---|---|
| `draft` | Em construção. Totalmente editável. Sem reserva de estoque. |
| `awaiting_approval` | Enviado para análise. Read-only para o criador. |
| `approved` | Autorizado a prosseguir. Reserva de estoque pode ser aplicada (futuro). |
| `picking` | Itens sendo separados para envio. |
| `invoiced` | Ao menos uma invoice foi emitida. Estoque baixado. CAR gerado. Estado terminal do MVP — registro de entrega fica fora do escopo. |
| `cancelled` | Anulado. Não gera movimentos. Imutável. |

Um pedido passa para `invoiced` assim que a primeira invoice parcial é emitida e permanece nesse status. **Status `delivered` está fora do escopo do MVP** — registro de entrega física exige um módulo de logística próprio (ver [B8](#b8-delivered-fora-do-escopo-do-mvp)).

## Sales order

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `number` | string | Número legível do pedido (ex.: `SO-000001`). Gerado via `document_sequence` — ver [Foundation](../01-foundation/README.md) |
| `status` | enum | Ver fluxo de status acima |
| `customer_id` | uuid | FK → `contact` (type precisa incluir `customer`) |
| `seller_id` | uuid | FK → `seller`. Nullable |
| `price_list_id` | uuid | FK → `price_list`. Tabela de preço usada neste pedido |
| `shipping_address_id` | uuid | FK → `contact_address`. Nullable |
| `payment_term_id` | uuid | FK → `payment_term` (ver [Financial](../09-financial/README.md)). Pré-preenchido pelo `default_payment_term_id` do contact, editável |
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
| `sku_id` | uuid | FK → `sku`. SKU precisa estar `active` no momento da adição (ver [B11](#b11-sku-não-active-bloqueia-adição-em-sales_order)) |
| `quantity` | decimal | |
| `unit_price` | decimal | Preço no momento do pedido (da tabela de preço ou definido manualmente) |
| `discount_pct` | decimal | Percentual de desconto no item. Default `0` |
| `discount_amount` | decimal | Calculado: `unit_price × quantity × discount_pct / 100` |
| `total` | decimal | Calculado: `unit_price × quantity - discount_amount` |

## Faturamento parcial

Um sales order pode gerar várias invoices. Isso atende cenários em que os itens saem em lotes ou são faturados em momentos diferentes.

- Cada invoice referencia o `sales_order_id` que a originou
- Cada `invoice_item` aponta para o `sales_order_item_id` que cobre
- O pedido acompanha a quantidade total já faturada por item
- O status avança para `invoiced` **assim que a primeira invoice parcial é emitida** e permanece nesse status (estado terminal do MVP)

### Controle de qty comprometida em drafts (B10)

Múltiplos drafts de invoice podem coexistir para o mesmo sales_order, mas a soma de:

```
qty_já_faturada (invoices em issued)
  + qty_em_drafts_abertos
```

**não pode exceder** `sales_order_item.quantity`. A validação ocorre tanto na criação quanto na edição do draft. Drafts descartados liberam a qty imediatamente.

## O que acontece no faturamento

Quando uma invoice é emitida a partir de um sales order, são disparados — atomicamente — saída de estoque (`out`), geração de CAR por parcela do `payment_term`, snapshot fiscal e snapshot do customer. O fluxo completo, com validações pré-emissão e ordem dos efeitos colaterais, está em [Invoices → O que acontece quando uma invoice é emitida](../07-invoices/README.md#o-que-acontece-quando-uma-invoice-é-emitida).

## Regras de cancelamento

- Pedidos em `draft` ou `awaiting_approval` podem ser cancelados livremente.
- Pedidos em `approved` ou `picking` podem ser cancelados com confirmação.
- Pedidos em `invoiced` não podem ser cancelados — é necessário um processo de devolução/crédito (pós-MVP).
- Pedidos `cancelled` são imutáveis e não geram movimentos de estoque ou financeiros.

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`B3`, `C3`) são estáveis e podem ser referenciados de outras features. Decisões cujo impacto principal mora em outro módulo aparecem em **Referências cruzadas** com link para a feature dona.

### B3. Credit limit do contact: bloqueia, alerta ou exige aprovação?

**Onde**: o módulo Contacts define `credit_limit` mas não dizia o que acontecia ao ultrapassá-lo.

**Decisão**: **força `awaiting_approval`** quando o limite é excedido.

Regra:

```
saldo_em_aberto = SUM(car.amount - car.paid_amount)
                  WHERE customer_id = X
                    AND status IN (pending, partial)

excede = (saldo_em_aberto + sales_order.total) > contact.credit_limit

SE contact.credit_limit IS NOT NULL AND excede:
  status do pedido é forçado para 'awaiting_approval'
  (mesmo em orgs que desabilitam essa etapa por default)
```

- Org que não quer a verificação: deixar `contact.credit_limit = null`.
- `overdue` **não** entra na soma — não é status persistido (ver [Financial → B4](../09-financial/README.md#b4-overdue-na-leitura-ou-em-job)).
- Setting para trocar o comportamento (`block` / `warn_only`) fica como extensão futura.

**Status**: `decided`

### B8. `delivered` fora do escopo do MVP

**Onde**: o fluxo do SO terminava em `delivered`, mas não havia campo para registrar entrega nem feature acionando a transição.

**Decisão**: **remover `delivered` do MVP**. Estado terminal do fluxo é `invoiced`.

- Registro de entrega física exige granularidade por item, romaneio, integração com transportadora — fora do escopo do MVP.
- Quando entrar, vira módulo de logística próprio (similar ao `purchase_receipt` do PO), e o SO ganha um novo status terminal.

**Status**: `decided`

### B10. Múltiplos drafts simultâneos: controle de qty comprometida

**Onde**: a feature `faturamento-parcial` permitia múltiplos drafts coexistindo, mas nenhum mecanismo impedia que a soma dos drafts excedesse a qty do item — risco de faturar mais do que pediu.

**Decisão**: **bloquear na criação/edição do draft** se a soma de qty (issued + drafts abertos) exceder `sales_order_item.quantity`.

- Drafts descartados liberam qty imediatamente.
- Permite o cenário comum (preparar dois drafts paralelos para fechar com clientes finais distintos) sem permitir a inconsistência.
- A validação roda também na emissão (defesa em profundidade), com erro explícito se outro draft "passou na frente".

**Status**: `decided`

### B19. Rejeição em `awaiting_approval` volta para `draft`

**Onde**: o fluxo previa apenas `aprovar`. Se admin negasse, não havia transição definida — pedido ficava preso ou tinha que ser cancelado (perdendo conteúdo).

**Decisão**: **rejeição é uma transição reversa explícita `awaiting_approval → draft`**, com motivo persistido em `internal_notes`.

- Diferente de `cancelar` — rejeitar mantém o pedido editável; o criador ajusta e re-submete.
- Sem campo dedicado `rejection_reason` no MVP — o motivo entra em `internal_notes` (já existe). Quando aparecer demanda de relatório de rejeições, vira coluna própria.
- Sem fluxo de aprovação multi-nível no MVP — uma rejeição basta.

**Status**: `decided`

### B11. SKU não-`active` bloqueia adição em sales_order

**Onde**: status `inactive`/`archived` do produto/SKU está documentado em Products, mas Sales Orders não dizia se o erro acontece na adição.

**Decisão**: **bloquear na adição**. Itens já adicionados antes da inativação ficam — pedidos em curso seguem normalmente.

- `draft`/`awaiting_approval`/`approved`: adicionar item de SKU não-`active` é rejeitado com erro explícito.
- `picking`: edição de itens já não é permitida pelo fluxo, então a regra é vacuosa.
- Inativar um SKU **não cancela** itens existentes em sales_orders abertos.

**Status**: `decided`

### C3. Reserva de estoque em sales_order aprovado

**Onde**: o módulo mencionava "reserva de estoque pode ser aplicada (futuro)". Sem reserva, aprovar pedido não garante estoque no picking — risco operacional declarado.

**Status**: `deferred` — pós-MVP.

### Referências cruzadas

- **A5** — `payment_terms` estruturado via templates (afeta `sales_order.payment_term_id`). Decisão completa em [Financial → A5](../09-financial/README.md#a5-payment_terms-como-string-livre-vs-estrutura).
- **B6** — Numeração de `sales_order` via `document_sequence`. Decisão completa em [Foundation → B6](../01-foundation/README.md#b6-numeração-de-sales_order-purchase_order-invoice).
