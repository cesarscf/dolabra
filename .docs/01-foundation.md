# Fundação — Auth e Organizações

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
           │    organizations     │                      │
           ▼    plugin            ▼                      ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                         member                              │
    │              (user_id + organization_id + role)             │
    └──────────────┬──────────────────────────┬───────────────────┘
                   │                          │
                   ▼                          ▼
    ┌──────────────────────┐    ┌──────────────────────┐
    │                      │    │                      │
    │   ORGANIZATION A     │    │   ORGANIZATION B     │
    │   (Empresa Alfa)     │    │   (Empresa Beta)     │
    │                      │    │                      │
    │  cnpj                │    │  cnpj                │
    │  legal_name          │    │  legal_name          │
    │  tax_regime          │    │  tax_regime          │
    │  address             │    │  address             │
    └──────────┬───────────┘    └──────────────────────┘
               │
               │  organization_id (em toda tabela)
               │
    ┌──────────▼──────────────────────────────────────────────┐
    │              TODAS AS TABELAS DE DOMÍNIO                 │
    │                                                          │
    │   products    contacts    sales_orders    invoices       │
    │   inventory   sellers     purchase_orders  financial     │
    │                                                          │
    │   Cada linha pertence a exatamente uma organization.     │
    │   Toda query filtra por organization_id.                 │
    │   Não há vazamento de dados entre orgs.                  │
    └──────────────────────────────────────────────────────────┘
```

Todo recurso no Dolabra é escopado a uma **organization**. Uma organization = uma empresa usando o ERP. Isso é garantido no data layer: cada tabela de domínio carrega `organization_id` como foreign key obrigatória (tenancy em nível de linha).

## Autenticação

Utiliza **Better Auth** com o plugin `organizations`.

- Um `user` pode pertencer a várias organizations pela join table `member` (padrão do Better Auth).
- Roles dentro da org: `owner | admin | member` — extensível via uma futura extensão de permissões.
- Sessions são escopadas por org: o `organization_id` ativo faz parte do contexto da session e é usado para filtrar todas as queries.

## Organization — campos extras

O Better Auth gera a tabela `organization` base. O Dolabra a estende com campos fiscais e operacionais brasileiros via `additionalFields` no plugin `organization()`:

| Campo | Tipo | Observações |
|---|---|---|
| `cnpj` | string | 14 dígitos, único por org. Null se `cpf` estiver preenchido |
| `cpf` | string | 11 dígitos. Para empreendedores individuais (MEI) |
| `legalName` | string | Razão social |
| `tradeName` | string | Nome fantasia |
| `stateRegistration` | string | Inscrição Estadual (IE). Nullable |
| `municipalRegistration` | string | Inscrição Municipal (IM). Nullable |
| `taxRegime` | string | `simples_nacional \| presumed_profit \| real_profit` |
| `phone` | string | Nullable |
| `email` | string | E-mail de contato fiscal |
| `logoUrl` | string | Nullable |
| `addressId` | string | FK → `address.id`. Nullable |

## Tabela address

Address é uma **tabela compartilhada** (`address`) referenciada por qualquer entidade que precise de um endereço físico. Organizations, contacts, filiais e outras entidades futuras apontam para ela via FK nullable `address_id`. Registros de address são criados e atualizados de forma independente da entidade que mantém a referência.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | string PK | — |
| `organization_id` | uuid | Chave de tenancy — address é escopado à org mesmo sendo compartilhado entre entidades |
| `street` | string | — |
| `number` | string | — |
| `complement` | string | Nullable |
| `neighborhood` | string | — |
| `city` | string | — |
| `state` | string | UF (sigla de 2 letras, ex.: SP, RJ) |
| `zipCode` | string | CEP (8 dígitos, sem hífen) |
| `country` | string | Default: `BR` |

## Regra de tenancy

Toda tabela de domínio **precisa** ter `organization_id`. Todas as queries **precisam** filtrar por ele. Vazamento de dados entre orgs é inaceitável. Essa é a invariante mais importante do sistema.

## Numeração de documentos (document_sequence)

Sales orders, purchase orders e invoices recebem um `number` legível único por org. A numeração é gerenciada por uma tabela central com incremento atômico, garantindo ausência de race conditions.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `entity_type` | enum | `sales_order \| purchase_order \| invoice` |
| `prefix` | string | `SO` \| `PO` \| `INV` |
| `next_value` | integer | Próximo número a ser atribuído. Default `1` |

Constraint: `UNIQUE (organization_id, entity_type)`.

Geração:

```
UPDATE document_sequence
   SET next_value = next_value + 1
 WHERE organization_id = X AND entity_type = Y
RETURNING next_value - 1 AS assigned;

number = prefix || '-' || LPAD(assigned::text, 6, '0');   -- ex.: SO-000001
```

Os três registros por org são criados no momento de criação da organization (ou lazy na primeira geração).

Gap-free **não** é exigido no MVP — `invoice.number` é interno do Dolabra. Quando a emissão nativa de NF-e entrar, o número fiscal vai em `invoice.nf_number` com sequência própria gap-free.

## Extensões futuras

- Permissões granulares (além de `owner | admin | member`) — via uma extensão de roles/permissions
- Suporte a multi-filial (várias localidades físicas por org) — via extensão; o schema não deve impedir isso
