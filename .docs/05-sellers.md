# Vendedores

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                  SELLERS — FLUXO DE COMISSÃO                         ║
╚══════════════════════════════════════════════════════════════════════╝

    ┌─────────────┐        ┌──────────────────────────────────────┐
    │    USER     │        │               SELLER                 │
    │ (Better Auth│───────►│                                      │
    │  user_id)   │        │  default_commission_pct: 5%          │
    └─────────────┘        │  commission_base: gross | net        │
                           └──────────────┬───────────────────────┘
                                          │ 1:N
                                          ▼
                           ┌──────────────────────────────────────┐
                           │     SELLER CATEGORY COMMISSION       │
                           │                                      │
                           │  category_id ──► Vestuário: 3%       │
                           │  category_id ──► Eletrônicos: 7%     │
                           └──────────────────────────────────────┘

  SELLER APARECE EM:

    CONTACT (customer)
    └── default_seller_id ──────────────────► pré-preenche em novo pedido

    SALES ORDER
    └── seller_id ──────────────────────────► editável no momento do pedido

  CÁLCULO DE COMISSÃO (responsabilidade do módulo Financial):

    CAR status ──► paid
         │
         ▼
    Financial lê seller a partir de sales_order
         │
         ├── por item: categoria com override? ──► usa % do override
         │                      não?           ──► usa % default
         │
         ├── aplica sobre: total do item gross ou net
         │
         └── gera BILL (origin = commission)
                  │
                  ▼
             Fluxo de pagamento do bill (igual a qualquer outro)

  OBS: O módulo Sellers nunca escreve em tabelas do Financial.
        Ele só armazena as regras. O cálculo é do Financial.
```

Sellers são vendedores designados a sales orders e customers. Podem ser **internos** (com login no sistema, ligados a um `user` do Better Auth) ou **externos** (representantes comerciais sem acesso ao ERP). Ambos aparecem em atribuições de pedido e recebem comissões.

As regras de comissão ficam aqui, mas o cálculo e a geração do bill pertencem ao módulo Financial.

## Seller

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `user_id` | uuid | FK → `user` do Better Auth. **Nullable** — null para representantes externos sem login. Um seller por user por org |
| `name` | string | Nome de exibição (pode diferir do nome de auth do user) |
| `email` | string | Nullable. Usado quando `user_id IS NULL`; ignorado caso contrário (fonte de verdade = user do auth) |
| `phone` | string | Nullable. Usado quando `user_id IS NULL` |
| `default_commission_pct` | decimal | Percentual de comissão default. ex.: `5.00` = 5% |
| `commission_base` | enum | `gross \| net`. `gross` = `sales_order_item.total` (pós-desconto de item). `net` = `sales_order_item.total × (1 - sales_order.discount_total / sales_order.subtotal)` (inclui rateio do desconto do pedido). Impostos não são descontados no MVP |
| `is_active` | boolean | Sellers inativos são ocultos de formulários de novo pedido |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

Constraint: `user_id IS NOT NULL OR email IS NOT NULL OR phone IS NOT NULL` — todo seller precisa de algum canal identificável.

## Overrides de comissão por categoria

Um seller pode ter uma taxa de comissão diferente para categorias específicas de produto. Se existir um override para a categoria, ele tem precedência sobre `default_commission_pct` para os itens dessa categoria.

**`seller_category_commission`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `seller_id` | uuid | FK → `seller` |
| `category_id` | uuid | FK → `category` |
| `commission_pct` | decimal | Sobrescreve o default do seller para essa categoria |

## Relacionamentos

- Um `contact` (customer) pode ter um `default_seller_id` — o seller é pré-preenchido ao criar um sales order para esse customer.
- Um `sales_order` tem um `seller_id` — pode ser alterado no momento do pedido, independente do default do customer.

## Cálculo de comissão

O cálculo da comissão **não** é disparado aqui. O módulo Financial faz o rateio quando uma sales invoice é paga:

1. Financial lê o `seller_id` a partir do sales order que originou a invoice.
2. Lê o `commission_pct` por item do pedido: usa `seller_category_commission` se a categoria do produto do item tiver override, senão usa `default_commission_pct`.
3. Aplica a taxa sobre o `commission_base` (total gross ou net do item).
4. Gera um Bill com o total da comissão.

Ou seja, o módulo Sellers só armazena as regras — nunca escreve em tabelas do Financial.
