# Financeiro

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                    FINANCIAL — FLUXO COMPLETO                        ║
╚══════════════════════════════════════════════════════════════════════╝

  CONTAS A RECEBER (CAR):

    INVOICE (issued)
         │ gera automaticamente
         ▼
    ┌────────────────────────────────────────────┐
    │   CAR  ×  installment_total                │
    │                                            │
    │  status: pending ──► partial ──► paid      │
    │  (se invoice for cancelada ──► cancelled)  │
    │                                            │
    │  "overdue" = derivado em runtime           │
    │  (status IN (pending,partial) AND          │
    │   due_date < current_date)                 │
    └───────────────┬────────────────────────────┘
                    │ usuário registra pagamento
                    ▼
    ┌────────────────────────────────────────────┐
    │             CAR PAYMENT                    │
    │  method: pix | boleto | credit_card | ...  │
    │  paid_at, amount                           │
    └───────────────┬────────────────────────────┘
                    │ quando status → paid
                    ▼
             TRIGGER DE COMISSÃO (ver abaixo)

  CONTAS A PAGAR (BILLS):

    ┌──────────────────┐   auto   ┌──────────────────────────────────┐
    │  Purchase Order  │─────────►│              BILL                │
    │  (confirmed)     │          │  origin: purchase_order          │
    └──────────────────┘          │                                  │
                                  │  status: pending ──► partial     │
    ┌──────────────────┐   auto   │         ──► paid                 │
    │  Commission      │─────────►│  origin: commission              │
    │  (CAR paid)      │          │                                  │
    └──────────────────┘          │  (se PO cancelada ──► cancelled) │
                                  │  overdue = derivado em runtime   │
                                  └────────────────┬─────────────────┘
    ┌──────────────────┐  manual  │
    │  Despesa         │─────────►│
    │  recorrente      │          │ usuário registra pagamento
    │  (aluguel, etc.) │          ▼
    └──────────────────┘ ┌──────────────────────────┐
                         │       BILL PAYMENT       │
                         │  method: pix | boleto... │
                         └──────────────────────────┘

  CÁLCULO DE COMISSÃO (disparado quando CAR → paid):

    CAR paid
      │
      ▼
    Lê o seller a partir da invoice ──► sales_order.seller_id
      │
      ├── por item da invoice:
      │     categoria do produto tem override? ──► usa % do override
      │                                   não?  ──► usa % default do seller
      │     aplica sobre: total gross ou net do item
      │
      └── SOMA a comissão ──► gera BILL (origin: commission)

  FLUXO DE CAIXA (calculado, sem tabela separada):

    ┌─────────────────────────────────────────────────────────┐
    │  REALIZADO  = car_payment.paid_at + bill_payment.paid_at│
    │  PROJETADO  = CARs e Bills pending/partial por due_date │
    │                                                         │
    │  Filtros: intervalo de data, financial_category         │
    └─────────────────────────────────────────────────────────┘
```

O módulo financeiro gerencia o que a empresa tem a receber (contas a receber) e o que tem a pagar (contas a pagar), além da visibilidade do fluxo de caixa. É o dono do cálculo de comissão.

Fora do escopo do MVP: contas bancárias, plano de contas hierárquico, conciliação bancária, DRE.

## Contas a Receber (CAR)

Geradas automaticamente quando uma sales invoice é emitida. Nunca criadas manualmente.

### Registro de CAR

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `invoice_id` | uuid | FK → `invoice` |
| `customer_id` | uuid | FK → `contact` |
| `installment_number` | integer | ex.: 1, 2, 3 em pagamentos parcelados |
| `installment_total` | integer | Quantidade total de parcelas desta invoice |
| `due_date` | date | |
| `amount` | decimal | |
| `paid_amount` | decimal | Valor acumulado recebido. Default `0` |
| `status` | enum | `pending \| partial \| paid \| cancelled`. "Overdue" **não** é um status — é derivado em runtime: `status IN (pending, partial) AND due_date < current_date` |
| `category_id` | uuid | FK → `financial_category`. Nullable |
| `notes` | text | Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### Pagamentos do CAR

Cada evento de pagamento é registrado. Múltiplos pagamentos permitidos até que `paid_amount = amount`.

**`car_payment`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `car_id` | uuid | FK → `car` |
| `amount` | decimal | Valor recebido neste pagamento |
| `payment_method` | enum | `cash \| pix \| boleto \| credit_card \| debit_card \| bank_transfer \| other` |
| `paid_at` | date | |
| `notes` | text | Nullable |

Transições de status:
- Primeiro pagamento com `paid_amount < amount` → `partial`
- Pagamento que leva a `paid_amount = amount` → `paid`
- Invoice cancelada → `cancelled`

"Overdue" não é uma transição — é uma condição derivada em queries/UI: `status IN (pending, partial) AND due_date < current_date`. Não há job agendado no MVP.

## Contas a Pagar (Bills)

Bills são criados de duas formas:
1. **Automaticamente** — quando um purchase order é confirmado.
2. **Manualmente** — para despesas recorrentes (aluguel, salários, contas de consumo) que não exigem purchase order.

### Registro de Bill

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `purchase_order_id` | uuid | FK → `purchase_order`. Null para bills manuais e de comissão |
| `supplier_id` | uuid | FK → `contact`. Nullable. Usado para `origin = purchase_order \| manual`. Null em bills de comissão |
| `seller_id` | uuid | FK → `seller`. Nullable. Usado apenas em bills com `origin = commission`; null caso contrário |
| `origin` | enum | `purchase_order \| manual \| commission`. Em `commission`, `seller_id` é obrigatório e `supplier_id` é null |
| `installment_number` | integer | |
| `installment_total` | integer | |
| `due_date` | date | |
| `amount` | decimal | |
| `paid_amount` | decimal | Default `0` |
| `status` | enum | `pending \| partial \| paid \| cancelled`. "Overdue" é derivado em runtime (mesma regra do CAR) |
| `category_id` | uuid | FK → `financial_category`. Nullable |
| `description` | string | Obrigatório para bills manuais |
| `notes` | text | Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### Pagamentos do Bill

**`bill_payment`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `bill_id` | uuid | FK → `bill` |
| `amount` | decimal | |
| `payment_method` | enum | `cash \| pix \| boleto \| credit_card \| debit_card \| bank_transfer \| other` |
| `paid_at` | date | |
| `notes` | text | Nullable |

Mesmas regras de transição de status do CAR.

## Payment terms (condições de pagamento)

Templates de parcelamento reutilizáveis. Evitam texto livre e permitem geração automática de CARs.

**`payment_term`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `name` | string | ex.: "À vista", "30/60/90", "Entrada + 2x" |
| `is_default` | boolean | Um default por org |

**`payment_term_installment`**

Uma linha por parcela dentro do template. A soma dos `pct` dentro de um template precisa fechar em 100.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `payment_term_id` | uuid | FK → `payment_term` |
| `sequence` | integer | Ordem da parcela (1, 2, 3, …) |
| `days_offset` | integer | Dias após a emissão. `0` = à vista |
| `pct` | decimal | Percentual do total desta parcela. Ex.: `33.33` |

### Uso

- `contact.default_payment_term_id` — condição default pré-preenchida ao criar um sales_order para esse customer (ver [Contacts](../04-contacts/README.md)).
- `sales_order.payment_term_id` — condição aplicada ao pedido (ver [Sales Orders](../06-sales-orders/README.md)). Editável no momento do pedido.
- `purchase_order.payment_term_id` — condição negociada com o supplier (ver [Purchase Orders](../08-purchase-orders/README.md)). Usada para gerar Bills na confirmação da PO.

### Geração de CARs na emissão da invoice

Quando uma invoice é emitida, o sistema percorre os `payment_term_installment` do `payment_term` do pedido e cria um CAR por linha:

- `due_date` = `invoice.issued_at + days_offset`
- `amount` = `invoice.total × pct / 100` (último CAR absorve o arredondamento para fechar com `invoice.total`)
- `installment_number` = `sequence`
- `installment_total` = quantidade total de parcelas no template

### Geração de Bills na confirmação do purchase_order

Mesma regra, base temporal diferente:

- `due_date` = `purchase_order.confirmed_at + days_offset`
- `amount` = `purchase_order.total × pct / 100` (última parcela absorve o arredondamento)
- `installment_number` = `sequence`
- `installment_total` = quantidade total de parcelas no template
- `origin` = `purchase_order`

## Financial categories

Lista plana de categorias por org. Usada para classificar bills e, opcionalmente, entradas de CAR para agrupar o fluxo de caixa.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `name` | string | ex.: "Aluguel", "Salários", "Receita de vendas", "Comissões" |
| `type` | enum | `income \| expense` |

Sem hierarquia no MVP. Plano de contas hierárquico fica para pós-MVP.

## Cálculo de comissão

Totalmente de responsabilidade deste módulo. Disparado **por CAR quitado** — cada CAR que atinge `status = paid` gera um Bill de comissão **proporcional** à parcela quitada. Isso alinha o pagamento de comissão ao caixa real: o seller recebe no ritmo em que o dinheiro da venda entra.

Passos (executados quando um CAR → `paid`):

1. Lê `seller_id` do sales order que originou a invoice.
2. Para cada item da invoice, define a taxa de comissão: usa `seller_category_commission` se a categoria do produto do item tiver override, senão usa `seller.default_commission_pct`. Produtos sem categoria (`category_id` null) usam sempre `default_commission_pct` — não há fallback de catch-all.
3. Aplica a taxa sobre a base definida em `seller.commission_base`:
   - `gross` = `sales_order_item.total` (pós-desconto de item, sem rateio do desconto do pedido).
   - `net` = `sales_order_item.total × (1 - sales_order.discount_total / sales_order.subtotal)` — inclui o rateio do desconto do pedido.
   - Impostos não são descontados no MVP.
4. Soma a comissão entre todos os itens → `comissão_total_da_invoice`.
5. Calcula o valor proporcional deste CAR:
   `bill_amount = (car.amount / invoice.total) × comissão_total_da_invoice`.
6. Gera um Bill com `origin = commission`, `seller_id = seller.id` (supplier_id fica null), `amount = bill_amount`, vencimento conforme configuração da org (default: imediato).

Os Bills de comissão são bills normais e seguem o mesmo fluxo de pagamento.

### Cancelamentos e imutabilidade dos Bills de comissão

Bills de comissão já emitidos são **imutáveis**. O sistema não reverte automaticamente.

- **Invoice cancelada** com uma ou mais CARs já pagas: os Bills de comissão já gerados permanecem (dinheiro entrou, comissão é devida). As CARs remanescentes (`pending` / `partial`) viram `cancelled` conforme A4 e não geram novos Bills.
- **CAR cancelado individualmente** (ex.: renegociação) após o Bill de comissão ter sido gerado: o Bill fica como está. Se for preciso reverter, o admin cria manualmente um Bill de ajuste (negativo).
- Reversão automática de comissão fica fora do MVP.

## Fluxo de caixa

Derivado dos registros de CAR e Bill. Sem tabela separada — calculado em tempo de consulta.

| Visão | Fonte |
|---|---|
| **Realizado** | Pagamentos de CAR (`car_payment.paid_at`) e pagamentos de Bill (`bill_payment.paid_at`) |
| **Projetado** | CARs e Bills com status `pending`/`partial` agrupados por `due_date` (vencidos aparecem como subcategoria via derivação em runtime) |

O fluxo de caixa é sempre escopado pela organization e pode ser filtrado por intervalo de data e financial category.

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`A5`, `B1`, `B2`, `B4`, `D4`) são estáveis e podem ser referenciados de outras features. Decisões cujo impacto principal mora em outro módulo aparecem em **Referências cruzadas** com link para a feature dona.

### A5. `payment_terms` como string livre vs. estrutura

**Onde**: `payment_terms` aparecia como texto livre em `contact` e `sales_order`, mas a geração de CAR exigia decompor "30/60/90" em parcelas com valores e vencimentos. Texto livre não basta sem parser.

**Decisão**: **templates `payment_term` reutilizáveis**.

- Nova tabela `payment_term` (org-scoped): `id`, `organization_id`, `name`, `is_default`.
- Nova tabela filha `payment_term_installment`: `id`, `payment_term_id`, `sequence`, `days_offset`, `pct`. Soma dos `pct` por payment_term = 100.
- Em `contact`: removido `payment_terms` (string livre); adicionado `default_payment_term_id` (FK, nullable).
- Em `sales_order`: removido `payment_terms` (string livre); adicionado `payment_term_id` (FK, obrigatório). Pré-preenchido pelo default do contact, editável.
- Geração de CARs na emissão da invoice: percorre `payment_term_installment` do pedido, cria 1 CAR por linha com `due_date = invoice.issued_at + days_offset` e `amount = invoice.total × pct / 100`.

**Status**: `decided`

### B1. `commission_base`: o que é "net"?

**Onde**: a documentação dizia "gross = antes de descontos, net = após descontos" sem explicitar quais descontos.

**Decisão**: **net inclui o rateio do desconto do pedido; impostos não são descontados no MVP**.

- `gross` = `sales_order_item.total` (pós-desconto de item, pré-rateio do desconto do pedido).
- `net` = `sales_order_item.total × (1 - sales_order.discount_total / sales_order.subtotal)`.
- Ex-impostos fica para pós-MVP (depende de emissão de NF-e e destaque correto de ICMS/PIS/COFINS) — pode entrar no futuro como um novo valor de `commission_base`, ex.: `fiscal_net`.

**Status**: `decided`

### B2. Comissão: por CAR paid ou por invoice totalmente paga?

**Onde**: uma invoice de 3 parcelas vira 3 CARs. Faltava decidir se a comissão saía por parcela ou só ao quitar a invoice.

**Decisão**: **por CAR paid, com regra clara de imutabilidade em cancelamentos**.

- Cada CAR → `paid` dispara geração de 1 Bill com `origin = commission`:
  - `amount = (car.amount / invoice.total) × comissão_total_da_invoice`
  - Supplier = seller (pagamento da comissão)
- **Bills de comissão gerados são imutáveis.**
- **Se a invoice for cancelada**: Bills já gerados para CARs pagos permanecem (dinheiro entrou, comissão é devida). Os CARs `pending/partial` remanescentes viram `cancelled` (ver A4 em Invoices) e não geram novo Bill de comissão.
- **Se um CAR for cancelado** sem cancelar a invoice (renegociação): o Bill de comissão já gerado para esse CAR fica como está — o evento exige intervenção manual do admin (gerar Bill de ajuste) caso seja necessário reverter.
- Reversão automática de comissão fica fora do MVP; o admin pode criar Bill manual negativo/ajuste se precisar.

**Status**: `decided`

### B4. `overdue`: na leitura ou em job?

**Decisão**: **derivado em runtime, nunca persistido**.

- `car.status` e `bill.status` são `pending | partial | paid | cancelled` (sem `overdue`).
- "Overdue" é uma condição derivada: `status IN (pending, partial) AND due_date < current_date`.
- Sem job scheduler no MVP. Notificações de vencido ficam para quando houver necessidade — e podem ser um job separado, sem mexer no `status`.
- UI mostra "overdue" como categoria visual, backing pela condição derivada.

**Status**: `decided`

### D4. Comissão quando o produto não tem categoria

**Onde**: `product.category_id` é nullable; `seller_category_commission` exige `category_id`.

**Decisão**: **produto sem categoria sempre usa `seller.default_commission_pct`**. Sem fallback adicional, sem obrigar categoria.

- Se a empresa quiser "só pagar comissão via categoria", basta setar `default_commission_pct = 0`.
- Não há "catch-all" de override para produtos sem categoria — mantém o modelo enxuto.

**Status**: `decided`

### Referências cruzadas

- **B5** — Seller sem user → `bill.supplier_id` nullable + `bill.seller_id` para Bills de comissão. Decisão completa em [Sellers → B5](../05-sellers/README.md#b5-seller-sem-user-representante-externo).
- **D5** — `due_date` dos Bills gerados na confirmação da PO segue o `payment_term` do PO. Decisão completa em [Purchase Orders → D5](../08-purchase-orders/README.md#d5-due_date-do-bill-gerado-na-confirmação-da-po).
