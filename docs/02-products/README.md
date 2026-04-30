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
| `store_id` | uuid | Chave de tenancy |
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
| `store_id` | uuid | Chave de tenancy |
| `product_id` | uuid | FK → `product` |
| `sku_code` | string | Único por org. Gerado automaticamente, editável pelo usuário |
| `ean_gtin` | string | Nullable. Dígito verificador validado |
| `supplier_ref` | string | Nullable. Código próprio do fornecedor para este item |
| `cost_price` | decimal | Custo de referência. Editável a qualquer momento e **não influencia `stock_balance.average_cost`** — média ponderada vem exclusivamente dos movimentos `in` (ver [Inventory](../03-inventory/README.md)). Ver [C5](#c5-cost_price-do-sku-é-editável-livremente). |
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

Atributos são definidos uma vez por loja e reutilizados entre produtos. Isso viabiliza filtros cruzados (ex.: "todos os SKUs azuis").

**`attribute`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `store_id` | uuid | |
| `name` | string | ex.: "Color", "Size", "Voltage" |

**`attribute_value`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `attribute_id` | uuid | FK → `attribute` |
| `value` | string | ex.: "Blue", "M", "220V" |

## Categorias

Árvore hierárquica de profundidade ilimitada (auto-referenciada). Servem apenas para navegação/organização e para regras de comissão por categoria (ver [Sellers](../05-sellers/README.md)). Não carregam dados fiscais — toda regra fiscal vive em `tax_group`.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `store_id` | uuid | |
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
| `store_id` | uuid | |
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

Os campos incluem: `ncm`, `cest`, `cfop`, `icms_cst`, `pis_cst`, `cofins_cst`, `ipi_cst`, `origin` e as alíquotas aplicáveis. A definição completa está em [Tax Groups](../10-tax-groups/README.md).

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`A2`, `A3`, `D2`, `D3`, `C1`) são estáveis e podem ser referenciados de outras features.

### A2. Dados fiscais duplicados em product × tax_group × category

**Onde**: `product` tinha `ncm`, `cest`, `cfop_default`, `origin`, `taxable_unit`; `tax_group` tinha os mesmos campos; `category` tinha `ncm_default`, `cfop_default`, `taxable_unit_default`. Três lugares podiam definir o mesmo NCM e a regra de herança só cobria `category × product`.

**Decisão**: **`tax_group` é a única fonte da verdade fiscal**.

- Removidos de `product`: `ncm`, `cest`, `cfop_default`, `origin`, `taxable_unit`.
- Removidos de `category`: `ncm_default`, `cfop_default`, `taxable_unit_default`. `category` passa a servir apenas para navegação e comissão.
- `product` aponta para regras fiscais apenas via `tax_group_id`.
- Produtos com fiscal atípico recebem um `tax_group` específico — barato e explícito.
- Snapshot na invoice continua protegendo o histórico.

**Status**: `decided`

### A3. Kit `price_mode`: onde mora

**Onde**: a documentação descrevia `price_mode: sum | fixed | discount` para kits sem definir onde armazenar `price_mode`, `fixed_price` e `discount_pct`.

**Decisão**: **preço fixo vive em `price_list_item`** (aproveita múltiplas price_lists); modos `sum` e `discount` são calculados em runtime.

- Todo product tem ≥1 SKU, inclusive kits — o SKU do kit é o identificador de venda e a chave em `price_list_item`.
- Campos novos em `product` (aplicáveis só quando `type = kit`):
  - `kit_price_mode`: enum `sum | fixed | discount`
  - `kit_discount_pct`: decimal, nullable, usado só quando `kit_price_mode = discount`
- Cálculo de preço do kit no momento da venda:
  - `sum` — soma dos `price_list_item.price` dos componentes (multiplicados pela quantidade do kit_item) na price_list ativa
  - `fixed` — lê `price_list_item.price` do SKU do kit na price_list ativa
  - `discount` — soma dos componentes × `(1 - kit_discount_pct/100)`
- Kit no modo `fixed` pode ter preços diferentes por price_list (atacado, varejo, etc.) — igual a qualquer SKU.

**Status**: `decided`

### D2. Campos do SKU para kit

**Onde**: A3 decidiu que todo product tem ≥1 SKU, inclusive kits. Mas campos de SKU (`cost_price`, `weight`, dims, `supplier_ref`) foram desenhados para produtos físicos.

**Decisão**: **sem constraint de DB**. Todos os campos do SKU continuam nullable.

- Para kits, `cost_price` e `weight` são **calculados em runtime** a partir dos componentes — a coluna no SKU do kit é ignorada.
- `height/width/depth` ficam livres (a embalagem do kit pode ter dimensões próprias).
- `supplier_ref` não se aplica a kit; a UI oculta o campo no formulário.
- `ean_gtin` e `image_url` funcionam normalmente (kit pode ter GTIN e foto próprios).
- Constraints em DB ficam fora: regras de negócio evoluem; UI e camada de serviço são as guardiãs.

**Status**: `decided`

### D3. `price_list_item` para kit conforme `kit_price_mode`

**Onde**: A3 deixou implícito o papel de `price_list_item` por modo, mas não tratou os casos de lixo/órfão quando o modo muda.

**Decisão**: **validação na camada de serviço**.

Regras ao editar `kit_price_mode`:

- **Mudar para `fixed`**: exigir `price_list_item` do SKU do kit na `price_list` default no mesmo request. Sem isso, bloquear. Price_lists adicionais (atacado etc.) podem ser preenchidas depois.
- **Mudar para `sum` ou `discount`**: deletar (ou ignorar) os `price_list_item` existentes para o SKU do kit — viram lixo.
- **Mudar entre `sum` e `discount`**: só o valor de `kit_discount_pct` precisa ser ajustado.

Regras na emissão/venda:

- Se `kit_price_mode = fixed` e não houver `price_list_item` na `price_list` do pedido, erro explícito ("preço do kit X não cadastrado na tabela Y"), sem fallback silencioso.

**Status**: `decided`

### C1. Unicidade de `product.name` por org

**Decisão**: **sem unique constraint em `name`**. `slug` é o identificador; nome é legível. Dois produtos com o mesmo nome são permitidos.

**Status**: `decided`

### C5. `cost_price` do SKU é editável livremente

**Onde**: faltava regra explícita sobre quando/quem pode editar `sku.cost_price` e se isso afeta o custo médio.

**Decisão**: **edição livre, sem efeito sobre `stock_balance.average_cost`**.

- `cost_price` é um custo de referência (estimativa, custo de tabela do fornecedor).
- Custo médio só vem de movimentos `in` reais (purchase receipts) — ver [Inventory](../03-inventory/README.md).
- Edição não gera movimento de estoque nem ajuste de saldo.
- Sem auditoria de histórico no MVP — edição direta sobrescreve o valor anterior.

**Status**: `decided`
