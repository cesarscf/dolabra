# Fundação — Auth e Lojas

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                      DOLABRA — MODELO DE TENANCY                     ║
╚══════════════════════════════════════════════════════════════════════╝

    ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
    │   user A    │        │   user B    │        │   user C    │
    └──────┬──────┘        └──────┬──────┘        └──────┬──────┘
           │                      │                      │
           │    Better Auth       │                      │
           │    organization      │                      │
           ▼    plugin            ▼                      ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                         member                              │
    │              (user_id + store_id + role)                    │
    └──────────────┬──────────────────────────┬───────────────────┘
                   │                          │
                   ▼                          ▼
    ┌──────────────────────┐    ┌──────────────────────┐
    │                      │    │                      │
    │       STORE A        │    │       STORE B        │
    │   (Empresa Alfa)     │    │   (Empresa Beta)     │
    │                      │    │                      │
    │  tax_id              │    │  tax_id              │
    │  person_type         │    │  person_type         │
    │  legal_name          │    │  legal_name          │
    │  tax_regime          │    │  tax_regime          │
    │  address             │    │  address             │
    └──────────┬───────────┘    └──────────────────────┘
               │
               │  store_id (em toda tabela)
               │
    ┌──────────▼──────────────────────────────────────────────┐
    │              TODAS AS TABELAS DE DOMÍNIO                 │
    │                                                          │
    │   products    contacts    sales_orders    invoices       │
    │   inventory   sellers     purchase_orders  financial     │
    │                                                          │
    │   Cada linha pertence a exatamente uma store.            │
    │   Toda query filtra por store_id.                        │
    │   Não há vazamento de dados entre lojas.                 │
    └──────────────────────────────────────────────────────────┘
```

Todo recurso no Dolabra é escopado a uma **store** (loja). Uma store = uma empresa usando o ERP. Isso é garantido no data layer: cada tabela de domínio carrega `store_id` como foreign key obrigatória (tenancy em nível de linha).

> **Nota sobre nomenclatura**: o plugin do Better Auth se chama `organization` e a API do client expõe `authClient.organization.*` — esses nomes são fixos. No domínio do Dolabra a entidade se chama `store` (tabela `stores`, FK `store_id`) e em prosa usamos "loja". O mapeamento acontece no `auth.ts` via `schema.organization.modelName` e `fields`.

## Autenticação

Utiliza **Better Auth** com o plugin `organization` (renomeado para `store` no Dolabra via `schema.organization.modelName: "store"`).

- Um `user` pode pertencer a várias stores pela join table `member` (padrão do Better Auth).
- Roles dentro da store: `owner | admin | member` — extensível via uma futura extensão de permissões.
- Sessions são escopadas por store: o `activeStoreId` faz parte do contexto da session e é usado para filtrar todas as queries.

### Operações de membership

Operações suportadas (delegadas ao Better Auth):

- **Convidar** novo usuário com role (owner/admin/member). O convite é aceito pelo destinatário e cria o registro de `member`.
- **Trocar role** de um membro existente. Apenas `owner`/`admin` podem trocar; `owner` é o único que pode promover outro a `owner`.
- **Remover** membro (apenas `owner`/`admin`). Não cascateia: pedidos, invoices e bills criados pelo membro permanecem ligados ao `user_id` original — auditoria preservada.
- **Sair** voluntariamente da store (qualquer role, exceto o último `owner`). A store sempre tem ao menos um `owner`.

## Loja — campos extras

O Better Auth gera a tabela `stores` (via `schema.organization.modelName: "store"` + `usePlural: true`). O Dolabra a estende com campos fiscais e operacionais brasileiros via `additionalFields` no plugin `organization()`:

| Campo | Tipo | Observações |
|---|---|---|
| `taxId` | string | CPF (11 dígitos) ou CNPJ (14 dígitos), conforme `personType`. Único entre stores. **Armazenado apenas com dígitos** (sem máscara) — a UI cuida da formatação na exibição |
| `personType` | enum | `company \| individual` — define se `taxId` é CNPJ (`company`) ou CPF (`individual`, MEI) |
| `legalName` | string | Razão social |
| `tradeName` | string | Nome fantasia |
| `stateRegistration` | string | Inscrição Estadual (IE). Nullable |
| `municipalRegistration` | string | Inscrição Municipal (IM). Nullable |
| `taxRegime` | string | `simples_nacional \| presumed_profit \| real_profit` |
| `phone` | string | Nullable |
| `email` | string | E-mail de contato fiscal |
| `logoUrl` | string | Nullable |
| `addressId` | string | FK → `address.id`. Nullable |
| `requiresSalesOrderApproval` | boolean | Liga/desliga a etapa `awaiting_approval` para novos sales_orders. Default `false`. Verificação de credit_limit pode forçar a etapa mesmo quando `false` (ver [Sales Orders → B3](../06-sales-orders/README.md#b3-credit-limit-do-contact-bloqueia-alerta-ou-exige-aprovação)) |

## Tabela address

Address é uma **tabela compartilhada** (`address`) referenciada por qualquer entidade que precise de um endereço físico. Stores, contacts, filiais e outras entidades futuras apontam para ela via FK nullable `address_id`. Registros de address são criados e atualizados de forma independente da entidade que mantém a referência.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | string PK | — |
| `store_id` | uuid | Chave de tenancy — address é escopado à store mesmo sendo compartilhado entre entidades |
| `street` | string | — |
| `number` | string | — |
| `complement` | string | Nullable |
| `neighborhood` | string | — |
| `city` | string | — |
| `state` | string | UF (sigla de 2 letras, ex.: SP, RJ) |
| `zipCode` | string | CEP (8 dígitos, sem hífen) |
| `country` | string | Default: `BR` |

## Regra de tenancy

Toda tabela de domínio **precisa** ter `store_id`. Todas as queries **precisam** filtrar por ele. Vazamento de dados entre lojas é inaceitável. Essa é a invariante mais importante do sistema.

## Numeração de documentos (document_sequence)

Sales orders, purchase orders e invoices recebem um `number` legível único por store. A numeração é gerenciada por uma tabela central com incremento atômico, garantindo ausência de race conditions.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `store_id` | uuid | Chave de tenancy |
| `entity_type` | enum | `sales_order \| purchase_order \| invoice` |
| `prefix` | string | `SO` \| `PO` \| `INV` |
| `next_value` | integer | Próximo número a ser atribuído. Default `1` |

Constraint: `UNIQUE (store_id, entity_type)`.

Geração:

```
UPDATE document_sequence
   SET next_value = next_value + 1
 WHERE store_id = X AND entity_type = Y
RETURNING next_value - 1 AS assigned;

number = prefix || '-' || LPAD(assigned::text, 6, '0');   -- ex.: SO-000001
```

Os três registros por store são criados no momento de criação da store (ou lazy na primeira geração).

Gap-free **não** é exigido no MVP — `invoice.number` é interno do Dolabra. Quando a emissão nativa de NF-e entrar, o número fiscal vai em `invoice.nf_number` com sequência própria gap-free.

## Testes

Setup de testes do Foundation (e dos demais módulos que dependem de uma store seedada) usa o plugin [`testUtils()`](https://better-auth.com/docs/plugins/test-utils) do Better Auth numa instância **test-only** do auth.

- Não adicionar `testUtils()` em `src/lib/auth.ts` (instância de produção) — vive só no setup de teste.
- Helpers expostos via `(await auth.$context).test`:
  - `createUser` / `saveUser` / `deleteUser`
  - `createOrganization` / `saveOrganization` — apesar do nome, escrevem na tabela `stores` (graças ao `schema.organization.modelName: "store"`).
  - `addMember({ userId, organizationId, role })` — `organizationId` aqui é o `id` da store.
  - `login` / `getAuthHeaders` / `getCookies` — sessão autenticada.
- Cenários a cobrir como TDD:
  - Tenancy: lista de produtos da Store A não retorna nada da Store B (`escopo-de-dados-por-store.feature`).
  - Onboarding: criar store dispara seed automático de `document_sequence`, `payment_term` "À vista" e `price_list` "Varejo" — na **mesma transação**.
  - Numeração: 5 sales_orders concorrentes recebem números distintos sem gap (`numerar-documentos.feature`).

## Extensões futuras

- Permissões granulares (além de `owner | admin | member`) — via uma extensão de roles/permissions
- Suporte a multi-filial (várias localidades físicas por store) — via extensão; o schema não deve impedir isso

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`B6`, `D6`, …) são estáveis e podem ser referenciados de outras features. Decisões cujo impacto principal mora em outro módulo aparecem em **Referências cruzadas** com link para a feature dona.

### A7. Setting de aprovação por loja

**Onde**: a feature de credit_limit e o fluxo de status do sales_order assumem "store com etapa de aprovação habilitada/desabilitada", mas o setting não morava em lugar nenhum do schema.

**Decisão**: **coluna direta `requires_sales_order_approval boolean` em `store`** (default `false`).

- Coluna direta em vez de tabela genérica `store_setting` — premature abstraction até existirem 3+ settings.
- Quando `false`, sales_orders saem de `draft` direto para `approved`.
- Quando `true`, passam por `awaiting_approval` antes de `approved`.
- Independente do valor, o credit_limit excedido força `awaiting_approval` (ver [Sales Orders → B3](../06-sales-orders/README.md#b3-credit-limit-do-contact-bloqueia-alerta-ou-exige-aprovação)).

**Status**: `decided`

### B6. Numeração de sales_order, purchase_order, invoice

**Onde**: diversos pontos falavam em "gerado automaticamente, único por store" sem estratégia.

**Decisão**: tabela `document_sequence` por `(store_id, entity_type)` com incremento atômico — definição completa na seção *Numeração de documentos* acima.

- Registros (`sales_order`, `purchase_order`, `invoice`) são criados com `next_value = 1` na criação da store (ou lazy na primeira geração).
- **Gap-free não é obrigatório no MVP**: `invoice.number` é o número interno do Dolabra; o número oficial da NF-e vai em `invoice.nf_number` (campo separado). Quando a emissão nativa de NF-e entrar, a numeração fiscal usa sequência própria gap-free.
- **Numeração de invoice é lazy** — atribuída apenas na transição `draft → issued`. Drafts de invoice descartados não consomem número da sequência. Decisão completa em [Invoices → B9](../07-invoices/README.md#b9-numeração-da-invoice-é-lazy).

**Status**: `decided`

### B18. Operações de membership

**Onde**: convidar membro estava documentado, mas trocar role, remover e sair da store não tinham mecanismo nem cenário.

**Decisão**: **delegar ao Better Auth** — Dolabra não duplica o modelo. Apenas explicita as garantias operacionais:

- Apenas `owner`/`admin` podem trocar role ou remover membros.
- `owner` é o único que pode promover outro membro a `owner`.
- A store **sempre tem ao menos um `owner`** — sair/remover o último `owner` é bloqueado.
- Remoção/saída **não cascateia** dados: documentos criados pelo membro permanecem ligados ao `user_id` original (auditoria preservada).

**Status**: `decided`

### D6. `address.store_id`

**Onde**: a tabela `address` tinha sido definida sem `store_id`, violando a invariante de tenancy declarada neste módulo.

**Decisão**: `address` carrega `store_id`. Toda tabela de domínio tem tenancy direta, sem exceção.

**Status**: `decided`

### C7. Validação de DV em CNPJ/CPF é obrigatória

**Onde**: a regra dizia "11 ou 14 dígitos" mas não checava dígito verificador. Aceitar `12345678000100` como CNPJ válido era convite a fraude/erro de digitação.

**Decisão**: **validar DV de CNPJ e CPF** sempre, tanto em store quanto em contact.

- Cálculo padrão (módulo 11) — implementação compartilhada em camada de validação.
- A UI normaliza para "só dígitos" antes da validação.
- DV inválido retorna mensagem específica (`CNPJ inválido` / `CPF inválido`), distinta de `comprimento incorreto`.
- Validação contra base oficial (Receita Federal) fica para pós-MVP.

**Status**: `decided` — convenção completa em [docs/00-globais/README.md](../00-globais/README.md).

### Referências cruzadas

- **A1** — Address: tabela compartilhada vs. por entidade (afeta a tabela `address` deste módulo). Decisão completa em [Contacts → A1](../04-contacts/README.md#a1-address-tabela-compartilhada-vs-por-entidade).
- **Convenções globais** — arredondamento monetário, política de delete, validação de documentos brasileiros e idempotência transacional vivem em [docs/00-globais/README.md](../00-globais/README.md).
