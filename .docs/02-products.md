# Produtos

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                    PRODUCTS — MODELO DE DADOS                        ║
╚══════════════════════════════════════════════════════════════════════╝

    ┌───────────────────────────────────────┐
    │              CATEGORY                 │
    │  (árvore auto-referenciada)           │
    │                                       │
    │  parent_id ──► categoria pai          │
    │  name                                 │
    │  (apenas navegação e comissão)        │
    └───────────────────────────────────────┘

    ┌───────────────────────────────────────┐
    │              TAX GROUP                │
    │  ncm, cest, cfop, origin              │
    │  taxable_unit                         │
    │  alíquotas e CSTs de                  │
    │  icms/pis/cofins/ipi                  │
    │  (ÚNICA fonte de verdade fiscal)      │
    └──────────────────┬────────────────────┘
                       │ tax_group_id
                       ▼
    ┌───────────────────────────────────────┐
    │              PRODUCT                  │
    │  type: physical | kit                 │  category_id
    │  status: draft|active|inactive|       │
    │          archived                     │
    │  slug (único por org)                 │
    │  unit_of_measure                      │
    │  kit_price_mode (sum|fixed|discount)  │
    │  kit_discount_pct                     │
    └──────────┬────────────────────────────┘
               │                │
               │ 1:N            │ somente kit
               ▼                ▼
    ┌───────────────────┐   ┌───────────────────┐
    │       SKU         │   │     KIT ITEM      │
    │                   │◄──│  kit_product_id   │
    │  sku_code (único) │   │  sku_id           │
    │  ean_gtin         │   │  quantity         │
    │  supplier_ref     │   └───────────────────┘
    │  cost_price       │
    │  image_url        │
    │  weight/dims      │
    └──────┬────────────┘
           │ M:N
           ▼
    ┌───────────────────┐     ┌───────────────────┐
    │  SKU ATTR VALUE   │     │  PRICE LIST ITEM  │
    │                   │     │                   │
    │  sku_id           │     │  price_list_id    │
    │  attribute_       │     │  sku_id           │
    │  value_id         │     │  price            │
    └──────┬────────────┘     └──────┬────────────┘
           │                         │
           ▼                         ▼
    ┌───────────────────┐     ┌───────────────────┐
    │ ATTRIBUTE VALUE   │     │   PRICE LIST      │
    │  value (ex.: "M") │     │  name             │
    │  attribute_id     │     │  is_default       │
    └──────┬────────────┘     └───────────────────┘
           │
           ▼
    ┌───────────────────┐
    │    ATTRIBUTE      │
    │ name (ex."Size")  │
    └───────────────────┘

  TRANSIÇÕES DE STATUS:
    draft ──► active ◄──► inactive ──► archived (irreversível)
```

O módulo de produtos é a base do ERP. Modela o que a empresa vende ou usa, em dois tipos: bens físicos e kits.

## Tipos de produto

| Tipo | Descrição |
|---|---|
| `physical` | Bem tangível. Tem estoque, peso e dimensões próprios por SKU. |
| `kit` | Pacote virtual de SKUs. Não tem estoque próprio — a disponibilidade é derivada dos componentes. Não pode ser aninhado (sem kit dentro de kit). |

O tipo `service` está fora do escopo do MVP.

## Status do produto

```
draft → active ↔ inactive → archived
```

| Status | Comportamento |
|---|---|
| `draft` | Em configuração. Oculto de todas as listagens operacionais (pedidos, orçamentos, estoque). Pode estar incompleto. |
| `active` | Disponível para venda. Aparece em formulários de pedido, relatórios de estoque, tabelas de preço. |
| `inactive` | Temporariamente desabilitado. Não pode ser selecionado em novos pedidos. Referências históricas são preservadas. |
| `archived` | Descontinuado permanentemente. Read-only. Oculto de listagens. A transição é irreversível. |

## Product (pai)

O product-pai guarda os dados compartilhados. Toda unidade vendável é um SKU (variante) abaixo dele.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `name` | string | |
| `slug` | string | Único por org. Obrigatório — usado para integrações futuras de e-commerce/marketplace |
| `description` | text | Nullable |
| `type` | enum | `physical \| kit` |
| `status` | enum | `draft \| active \| inactive \| archived` |
| `category_id` | uuid | FK → `category`. Nullable |
| `unit_of_measure` | string | `un`, `kg`, `cx`, etc. Uma única UM por produto (sem conversão no MVP) |
| `tax_group_id` | uuid | FK → `tax_group`. **Única fonte** das regras fiscais (ncm, cest, cfop, origin, taxable_unit, alíquotas). Snapshot no faturamento |
| `kit_price_mode` | enum | `sum \| fixed \| discount`. Aplicável apenas quando `type = kit`. Null caso contrário |
| `kit_discount_pct` | decimal | Nullable. Usado apenas quando `kit_price_mode = discount` |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

Regras fiscais (ncm, cest, cfop, origin, taxable_unit, alíquotas e CSTs) vivem apenas em `tax_group`. Produtos com fiscal atípico recebem um tax_group próprio.

### Imagens do produto (galeria)

Armazenadas como lista ordenada no product-pai. Gerenciadas pelo ERP (upload para o Cloudflare R2).

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `product_id` | uuid | FK → `product` |
| `url` | string | URL pública do R2 |
| `position` | integer | Ordem de exibição |

## SKU (variante)

Cada combinação única e vendável de atributos é um SKU. Um produto sem atributos tem exatamente um SKU. **Todo product tem pelo menos 1 SKU — inclusive kits**, pois o SKU do kit é o identificador de venda e a chave em `price_list_item`.

No SKU de um kit:
- `cost_price` e `weight` são **calculados em runtime** a partir dos componentes — as colunas no SKU ficam null e são ignoradas pela camada de serviço.
- `height/width/depth` ficam livres (a caixa do kit pode ter dimensões próprias).
- `supplier_ref` não se aplica (UI oculta).
- `ean_gtin` e `image_url` funcionam normalmente.

Nenhuma constraint de DB impõe essas regras — a UI e a camada de serviço são as guardiãs, para não engessar evoluções futuras.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `product_id` | uuid | FK → `product` |
| `sku_code` | string | Único por org. Gerado automaticamente, editável pelo usuário |
| `ean_gtin` | string | Nullable. Dígito verificador validado |
| `supplier_ref` | string | Nullable. Código próprio do fornecedor para este item |
| `cost_price` | decimal | |
| `image_url` | string | Nullable. Sobrescreve a galeria do produto quando preenchido |
| `weight` | decimal | Em kg. Nullable |
| `height` | decimal | Em cm. Nullable |
| `width` | decimal | Em cm. Nullable |
| `depth` | decimal | Em cm. Nullable |
| `is_active` | boolean | Herda o status do produto, mas pode ser desabilitado individualmente |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

### Valores de atributo do SKU

Liga um SKU à sua combinação de valores de atributo (ex.: Color=Blue, Size=M).

| Campo | Tipo |
|---|---|
| `sku_id` | uuid |
| `attribute_value_id` | uuid |

## Atributos globais

Atributos são definidos uma vez por organization e reutilizados entre produtos. Isso viabiliza filtros cruzados (ex.: "todos os SKUs azuis").

**`attribute`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `name` | string | ex.: "Color", "Size", "Voltage" |

**`attribute_value`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `attribute_id` | uuid | FK → `attribute` |
| `value` | string | ex.: "Blue", "M", "220V" |

## Categorias

Árvore hierárquica de profundidade ilimitada (auto-referenciada). Servem apenas para navegação/organização e para regras de comissão por categoria (ver `05-sellers.md`). Não carregam dados fiscais — toda regra fiscal vive em `tax_group`.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `parent_id` | uuid | FK → `category`. Null = raiz |
| `name` | string | |

## Kit

Um kit é um produto do tipo `kit`. Seus componentes são definidos em `kit_item`.

**`kit_item`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `kit_product_id` | uuid | FK → `product` (type precisa ser `kit`) |
| `sku_id` | uuid | FK → `sku`. SKU componente |
| `quantity` | decimal | |

**Precificação do kit**

O modo é definido em `product.kit_price_mode`. O preço do kit no momento da venda é calculado assim:

| `kit_price_mode` | Cálculo |
|---|---|
| `sum` | Soma de `price_list_item.price × kit_item.quantity` de cada componente, na price_list ativa |
| `fixed` | Lê `price_list_item.price` do **SKU do kit** na price_list ativa. Permite preços diferentes por tabela (varejo, atacado, …) |
| `discount` | Soma dos componentes (como em `sum`) × `(1 - product.kit_discount_pct / 100)` |

Disponibilidade do kit = `floor(estoque_do_componente / quantidade_necessária)` para cada componente — o mínimo entre todos os componentes.

Regra de aninhamento: um componente de kit (`sku_id`) deve pertencer a um product do tipo `physical`. Kits não podem conter outros kits.

### Regras de serviço ao editar `kit_price_mode`

- Mudar para `fixed`: exige `price_list_item` do SKU do kit na `price_list` default no mesmo request. Sem isso, a alteração é bloqueada. Preços em price_lists adicionais podem ser preenchidos depois.
- Mudar para `sum` ou `discount`: os `price_list_item` existentes para o SKU do kit são removidos (viram lixo silencioso se mantidos).
- Mudar entre `sum` e `discount`: ajusta apenas `kit_discount_pct`.

Na venda, se `kit_price_mode = fixed` e não existir `price_list_item` para o SKU do kit na `price_list` do pedido, o sistema emite erro explícito — sem fallback silencioso para outro modo.

## Tabelas de preço

Produtos são precificados via tabelas de preço (ex.: Varejo, Atacado, Revendedor). Cada org pode ter várias tabelas. Customers podem ter uma tabela de preço default atribuída.

**`price_list`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `name` | string | ex.: "Retail", "Wholesale" |
| `is_default` | boolean | Uma default por org |

**`price_list_item`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `price_list_id` | uuid | |
| `sku_id` | uuid | |
| `price` | decimal | Preço de venda desse SKU nessa tabela |

## Tax group

Um `tax_group` agrupa as regras fiscais de um produto. No momento do faturamento, os dados do tax group são **snapshotados** em cada `invoice_item` — protegendo o histórico fiscal de edições futuras no produto.

O `tax_group` é atribuído no nível de **product**, não no nível de SKU.

Os campos incluem: `ncm`, `cest`, `cfop`, `icms_cst`, `pis_cst`, `cofins_cst`, `ipi_cst`, `origin` e as alíquotas aplicáveis. A definição completa está no doc do módulo Fiscal.
