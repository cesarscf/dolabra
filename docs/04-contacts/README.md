# Contatos

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                    CONTACTS — MODELO DE DADOS                        ║
╚══════════════════════════════════════════════════════════════════════╝

    ┌─────────────────────────────────────────────────────────────┐
    │                         CONTACT                             │
    │                                                             │
    │  type: customer | supplier | both                           │
    │  person_type: individual | company                          │
    │                                                             │
    │  tax_id                                                     │
    │  legal_name / name / trade_name                             │
    │  state_registration (IE) / municipal_registration (IM)      │
    │                                                             │
    │  default_seller_id ──────────────────────► SELLER           │
    │  default_price_list_id ──────────────────► PRICE LIST       │
    │  credit_limit / payment_terms                               │
    │                                                             │
    │  status: active | inactive | blocked                        │
    └──────────────────────────┬──────────────────────────────────┘
                               │ 1:N
                               ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                     CONTACT ADDRESS                         │
    │                        (tabela-ponte)                       │
    │                                                             │
    │  contact_id ───────────────────────────► CONTACT            │
    │  address_id ───────────────────────────► ADDRESS            │
    │  type: main | billing | shipping                            │
    │  is_default                                                 │
    └─────────────────────────────────────────────────────────────┘

                       ADDRESS (compartilhada, ver 01-foundation)
                       street, number, complement, neighborhood
                       city, state (UF), zip_code (CEP), country

  COMO CONTACTS SE LIGAM AOS OUTROS MÓDULOS:

    CONTACT (customer) ──────────────────► SALES ORDER
                                            customer_id

    CONTACT (supplier) ──────────────────► PURCHASE ORDER
                                            supplier_id

    CONTACT (customer) ──────────────────► CAR (contas a receber)
                                            customer_id

    CONTACT (supplier) ──────────────────► BILL (contas a pagar)
                                            supplier_id

  SNAPSHOT FISCAL NA INVOICE:
    No momento da emissão, tax_id + legal_name +
    state_registration + address são copiados para
    invoice.customer_snapshot (jsonb) e congelados.
```

Um cadastro unificado para customers e suppliers. Um único registro de contact pode atuar como ambos. Isso evita duplicação quando uma empresa é cliente e fornecedor ao mesmo tempo.

## Contact

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `type` | enum | `customer \| supplier \| both` |
| `person_type` | enum | `individual \| company` |
| `tax_id` | string | CPF (11 dígitos) ou CNPJ (14 dígitos), conforme `person_type`. Obrigatório. Único por org. **Armazenado apenas com dígitos** (sem máscara) — a UI cuida da formatação na exibição |
| `legal_name` | string | Razão social. Usado quando `person_type = company` |
| `name` | string | Nome completo. Usado quando `person_type = individual` |
| `trade_name` | string | Nome fantasia. Nullable |
| `state_registration` | string | Inscrição Estadual (IE). Nullable |
| `municipal_registration` | string | Inscrição Municipal (IM). Nullable |
| `email` | string | Nullable |
| `phone` | string | Nullable |
| `mobile` | string | Nullable |
| `default_seller_id` | uuid | FK → `seller`. Vendedor default atribuído a este customer. Nullable |
| `default_price_list_id` | uuid | FK → `price_list`. Tabela de preço default para este customer. Nullable |
| `credit_limit` | decimal | Saldo em aberto máximo permitido. Nullable (sem limite). Quando excedido, o sales_order é forçado a `awaiting_approval` — ver [Sales Orders](../06-sales-orders/README.md) |
| `default_payment_term_id` | uuid | FK → `payment_term` (ver [Financial](../09-financial/README.md)). Condição de pagamento default pré-preenchida em novos sales_orders. Nullable |
| `status` | enum | `active \| inactive \| blocked` |
| `notes` | text | Observações internas. Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### Status do contact

| Status | Comportamento |
|---|---|
| `active` | Disponível para seleção em pedidos, compras e documentos financeiros |
| `inactive` | Temporariamente desabilitado. Oculto de novos formulários. Registros históricos preservados |
| `blocked` | Crédito bloqueado. Visível em listagens mas não pode ser usado em novos sales orders |

**Sem cascata**: mudar o status do contact afeta apenas a criação de novos documentos. CARs, Bills, sales_orders e purchase_orders já existentes seguem seu fluxo normal — não são cancelados automaticamente. Um CAR é um direito real da empresa e permanece ativo independente do status do customer.

## Endereços

Um contact pode ter vários endereços. Cada endereço tem um type indicando sua finalidade. A tabela `contact_address` é uma **ponte** entre `contact` e a tabela compartilhada `address` (ver [Foundation](../01-foundation/README.md)). Os campos de endereço (street, number, city, …) vivem apenas em `address` e são reutilizáveis por qualquer entidade.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `contact_id` | uuid | FK → `contact` |
| `address_id` | uuid | FK → `address` (tabela compartilhada) |
| `type` | enum | `main \| billing \| shipping` |
| `is_default` | boolean | Endereço default do seu type |

## Notas sobre dados fiscais

Quando uma sales invoice (NF-e) é emitida, os dados fiscais do customer no momento do faturamento são snapshotados na invoice — `tax_id`, `legal_name`, `state_registration` e endereço. Alterações no contact após a emissão não afetam documentos históricos.

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`A1`, `C4`) são estáveis e podem ser referenciados de outras features. Decisões cujo impacto principal mora em outro módulo aparecem em **Referências cruzadas** com link para a feature dona.

### A1. Address: tabela compartilhada vs. por entidade

**Onde**: dois modelos coexistiam — Foundation definia `address` compartilhada (referenciada via `address_id`), e Contacts definia `contact_address` com campos inline e FK em `contact_id`. Um contact pode ter vários endereços (main/billing/shipping, `is_default`); uma organization tem um só. Não estava claro se address era compartilhado ou por entidade.

**Decisão**: **única tabela `address` compartilhada**.

- `organization.address_id` continua apontando para `address`.
- `contact_address` vira tabela-ponte: `id`, `contact_id` FK, `address_id` FK, `type (main|billing|shipping)`, `is_default`. Sem campos de endereço inline.
- Campos de endereço (`street`, `number`, …) vivem só em `address`.
- Entidades futuras (filiais, shipping avulso, etc.) reutilizam `address` diretamente.

**Status**: `decided`

### C4. Transições de status do contact sem efeito cascata

**Onde**: bloquear um contact não cancela CARs em aberto. Comportamento esperado, mas precisava ficar explícito.

**Decisão**: **sem cascata**. Status do contact afeta apenas a criação de novos pedidos/documentos. CARs, Bills, sales_orders e purchase_orders existentes seguem o fluxo normal. Um CAR é um direito real da empresa — não desaparece porque o cliente foi bloqueado.

**Status**: `decided`

### Referências cruzadas

- **A5** — `payment_terms` como string livre vs. estrutura (afeta `contact.default_payment_term_id`). Decisão completa em [Financial → A5](../09-financial/README.md#a5-payment_terms-como-string-livre-vs-estrutura).
- **B3** — Credit limit: bloqueia, alerta ou exige aprovação? (define o significado de `contact.credit_limit`). Decisão completa em [Sales Orders → B3](../06-sales-orders/README.md#b3-credit-limit-do-contact-bloqueia-alerta-ou-exige-aprovação).
