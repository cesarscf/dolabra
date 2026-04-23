# Log de decisões de arquitetura

Registra as decisões arquiteturais tomadas durante a definição dos docs 01–10. Cada item preserva **opções consideradas** e **tradeoffs**, não apenas a decisão final — para que o "porquê" sobreviva no tempo.

Os docs 01–10 são a fonte da verdade do **o quê**. Este arquivo é a fonte do **porquê**.

Formato de status:

- `decided` — decisão tomada; resumo + doc(s) onde foi propagada
- `deferred` — empurrado para pós-MVP
- `open` — (não deveria aparecer aqui; se aparecer, virou pendência)

---

## Bloco A — Estruturais (travam schema / implementação)

Decidir **antes** de começar a codar. Afetam colunas, FKs ou invariantes fundamentais.

### A1. Address: tabela compartilhada vs. por entidade

**Onde**: `01-foundation.md:76` (tabela `address` compartilhada, referenciada via `address_id`) × `04-contacts.md:97` (tabela `contact_address` com campos inline e FK em `contact_id`).

**Problema**: os dois modelos coexistem no mesmo sistema. Um contact pode ter vários endereços (main/billing/shipping, `is_default`); uma organization tem um só. Não está claro se address é compartilhado ou por entidade.

**Decisão**: opção 1 — **única tabela `address` compartilhada**.

- `organization.address_id` continua apontando para `address`
- `contact_address` vira tabela-ponte: `id`, `contact_id` FK, `address_id` FK, `type (main|billing|shipping)`, `is_default`. Sem campos de endereço inline.
- Campos de endereço (street, number, …) vivem só em `address`.
- Entidades futuras (filiais, shipping avulso, etc.) reutilizam `address` diretamente.

**Doc a atualizar**: `04-contacts.md` (tabela e diagrama).

**Status**: `decided`

---

### A2. Dados fiscais duplicados em product × tax_group × category

**Onde**: `02-products.md:112-118` (product tem `ncm`, `cest`, `cfop_default`, `origin`, `taxable_unit`) × `10-tax-groups.md:74-82` (tax_group tem os mesmos campos) × `02-products.md:194-196` (category tem `ncm_default`, `cfop_default`, `taxable_unit_default`).

**Problema**: a regra de herança só cobre `category × product`. Não cobre `product × tax_group`. Três lugares podem definir o mesmo NCM.

**Decisão**: opção 1 — **tax_group é a única fonte da verdade fiscal**.

- Remover de `product`: `ncm`, `cest`, `cfop_default`, `origin`, `taxable_unit`.
- Remover de `category`: `ncm_default`, `cfop_default`, `taxable_unit_default`. Category passa a servir apenas para navegação e comissão.
- Product aponta para regras fiscais apenas via `tax_group_id`.
- Produtos com fiscal atípico recebem um tax_group específico — barato e explícito.
- Snapshot na invoice continua protegendo o histórico.

**Docs a atualizar**: `02-products.md` (tabela product, tabela category, diagrama, regra de herança).

**Status**: `decided`

---

### A3. Kit `price_mode` não existe na tabela `product`

**Onde**: `02-products.md:214-222` descreve `price_mode: sum | fixed | discount`, mas os campos não aparecem na definição de colunas de `product` (`02-products.md:102-120`).

**Problema**: falta decidir onde guardar `price_mode`, `fixed_price` (para modo fixed), `discount_pct` (para modo discount).

**Decisão**: opção 3 — **preço fixo vive em `price_list_item`** (aproveita múltiplas price_lists); modos `sum` e `discount` são calculados em runtime.

- Todo product tem pelo menos 1 SKU, inclusive kits — o SKU do kit é o identificador de venda e a chave em `price_list_item`.
- Campos novos em `product` (aplicáveis só quando `type = kit`):
  - `kit_price_mode`: enum `sum | fixed | discount`
  - `kit_discount_pct`: decimal, nullable, usado só quando `kit_price_mode = discount`
- Cálculo de preço do kit no momento da venda:
  - `sum` — soma dos `price_list_item.price` dos componentes (multiplicados pela quantidade do kit_item) na price_list ativa
  - `fixed` — lê `price_list_item.price` do SKU do kit na price_list ativa
  - `discount` — soma dos componentes × `(1 - kit_discount_pct/100)`
- Kit no modo `fixed` pode ter preços diferentes por price_list (atacado, varejo, etc.) — igual a qualquer SKU.

**Docs a atualizar**: `02-products.md` (tabela product, seção Kit, diagrama).

**Status**: `decided`

---

### A4. Reversão de estoque no cancelamento de invoice: `in` ou `adjustment`?

**Onde**: `07-invoices.md:131` diz "um movimento de **ajuste do tipo `in`**" × `03-inventory.md:87-93` lista os tipos como `in | out | adjustment` e reserva `in` para purchase receipt.

**Problema**: texto ambíguo. Se o tipo for `in`, polui o histórico de entradas com algo que não é compra. Se for `adjustment`, contraria a literalidade do doc.

**Decisão**: opção 1 — **`adjustment` com `reference_type = invoice_cancellation`**.

- Tipos preservam semântica: `in` = compra (atualiza custo médio), `out` = venda, `adjustment` = tudo o mais.
- O movimento de reversão usa `type = adjustment`, `reference_type = invoice_cancellation`, `reference_id` apontando para a invoice cancelada.
- `unit_cost` do movimento de reversão bate com o `unit_cost` do movimento `out` original — zera impacto histórico. Custo médio **não** é recalculado.
- Direção do saldo: positiva (volta ao estoque). A direção é determinada pelo sinal/semântica do adjustment, já coberta por `03-inventory.md`.

**Docs a atualizar**: `07-invoices.md` (texto de cancelamento), `03-inventory.md` (incluir `invoice_cancellation` entre reference_types válidos).

**Status**: `decided`

---

### A5. `payment_terms` como string livre vs. estrutura

**Onde**: `06-sales-orders.md:95` e `04-contacts.md:80` definem como texto livre × `07-invoices.md:125` e `09-financial.md` dizem "CAR gerado com base em payment_terms".

**Problema**: não dá pra gerar N parcelas com valores e vencimentos a partir de texto livre como "30/60/90" sem parser.

**Decisão**: opção 3 — **templates `payment_term` reutilizáveis**.

- Nova tabela `payment_term` (org-scoped): `id`, `organization_id`, `name`, `is_default`.
- Nova tabela filha `payment_term_installment`: `id`, `payment_term_id`, `sequence`, `days_offset`, `pct`. Soma dos `pct` por payment_term = 100.
- Em `contact`: remover `payment_terms` (string livre), adicionar `default_payment_term_id` (FK, nullable).
- Em `sales_order`: remover `payment_terms` (string livre), adicionar `payment_term_id` (FK, obrigatório). Pré-preenchido pelo default do contact, editável.
- Geração de CARs na emissão da invoice: percorre `payment_term_installment` do pedido, cria um CAR por linha com `due_date = invoice.issued_at + days_offset` e `amount = invoice.total × pct / 100`.

**Docs a atualizar**: `09-financial.md` (onde viverá a definição das tabelas e a geração do CAR), `04-contacts.md` (FK), `06-sales-orders.md` (FK), `07-invoices.md` (texto do fluxo).

**Status**: `decided`

---

### A6. Rateio de despesas acessórias com recebimentos parciais

**Onde**: `08-purchase-orders.md:122` diz que o rateio entra no `unit_cost` do receipt.

**Problema**: o primeiro receipt não sabe se haverá mais. Ratear tudo no primeiro distorce o custo médio. Ratear proporcionalmente a cada receipt exige re-rateio retroativo quando o próximo chega.

**Decisão**: opção 2 — **rateio proporcional por receipt, à fração recebida**.

Para cada item em cada receipt:

```
qty_this_receipt = purchase_receipt_item.quantity
qty_expected_total = purchase_order_item.quantity

Para cada purchase_order_expense:
  base_de_rateio conforme apportionment:
    proportional → (item.subtotal / sum(items.subtotal))
    equal        → 1 / count(items)
    manual       → pct definido pelo usuário por item

  expense_for_item_total      = expense.amount × base_de_rateio
  expense_for_this_receipt    = expense_for_item_total × (qty_this_receipt / qty_expected_total)

unit_cost efetivo = item.unit_cost + sum(expense_for_this_receipt) / qty_this_receipt
```

- Custo médio coerente desde o primeiro receipt.
- Nenhum re-cálculo retroativo.
- Se a PO nunca atingir 100% (supplier entregou menos e PO foi fechada com quantidade parcial), o delta de despesas fica no limbo — aceitável no MVP. Ajustes de custo no fechamento ficam para pós-MVP.

**Docs a atualizar**: `08-purchase-orders.md` (seção de despesas acessórias, descrição do recebimento).

**Status**: `decided`

---

## Bloco B — Comportamentais (podem ser decididas durante implementação)

Não mudam schema, mas mudam comportamento. Decidir ao implementar o módulo correspondente.

### B1. `commission_base`: o que é "net"?

**Onde**: `05-sellers.md:67` e `09-financial.md:189` dizem "gross = antes de descontos, net = após descontos".

**Problema**: "após descontos" — só desconto de item, ou também desconto do pedido? Impostos entram (antes/depois do imposto)?

**Decisão**: opção 2 — **net inclui o rateio do desconto do pedido; impostos não são descontados no MVP**.

- `gross` = `sales_order_item.total` (pós-desconto de item, pré-rateio do desconto do pedido).
- `net` = `sales_order_item.total × (1 - sales_order.discount_total / sales_order.subtotal)`.
- Ex-impostos fica para pós-MVP (depende de emissão de NF-e e destaque correto de ICMS/PIS/COFINS) — pode entrar no futuro como um novo valor de `commission_base`, ex.: `fiscal_net`.

**Docs a atualizar**: `05-sellers.md` (definição de commission_base), `09-financial.md` (passo 3 do cálculo).

**Status**: `decided`

---

### B2. Comissão: por CAR paid ou por invoice totalmente paga?

**Onde**: `09-financial.md:184` diz "disparado quando CAR → paid".

**Problema**: uma invoice de 3 parcelas vira 3 CARs. Gera 3 Bills de comissão (um por parcela, proporcional) ou 1 Bill quando a última CAR fecha?

**Decisão**: opção 3 — **por CAR paid, com regra clara de imutabilidade em cancelamentos**.

- Cada CAR → `paid` dispara geração de 1 Bill com `origin = commission`:
  - `amount = (car.amount / invoice.total) × comissão_total_da_invoice`
  - Supplier = seller (pagamento da comissão)
- **Bills de comissão gerados são imutáveis.**
- **Se a invoice for cancelada**: Bills já gerados para CARs pagos permanecem (dinheiro entrou, comissão é devida). Os CARs `pending/partial` remanescentes viram `cancelled` (ver A4) e não geram novo Bill de comissão.
- **Se um CAR for cancelado** sem cancelar a invoice (renegociação): o Bill de comissão já gerado para esse CAR fica como está — o evento exige intervenção manual do admin (gerar Bill de ajuste) caso seja necessário reverter.
- Reversão automática de comissão fica fora do MVP; o admin pode criar Bill manual negativo/ajuste se precisar.

**Docs a atualizar**: `09-financial.md` (passos 4-5 do cálculo + seção nova sobre cancelamentos).

**Status**: `decided`

---

### B3. Credit limit do contact: bloqueia, alerta ou exige aprovação?

**Onde**: `04-contacts.md:79` define `credit_limit`, mas nenhum módulo descreve o que fazer quando é ultrapassado.

**Decisão**: opção 3 — **força `awaiting_approval`** quando o limite é excedido.

Regra:

```
saldo_em_aberto = SUM(car.amount - car.paid_amount)
                  WHERE customer_id = X
                    AND status IN (pending, partial, overdue)

excede = (saldo_em_aberto + sales_order.total) > contact.credit_limit

SE contact.credit_limit IS NOT NULL AND excede:
  status do pedido é forçado para 'awaiting_approval'
  (mesmo em orgs que desabilitam essa etapa por default)
```

- Org que não quer a verificação: deixar `contact.credit_limit = null`.
- Setting para trocar o comportamento (`block` / `warn_only`) fica como extensão futura.

**Docs a atualizar**: `04-contacts.md` (nota no campo), `06-sales-orders.md` (regra na seção de status / criação do pedido).

**Status**: `decided`

---

### B4. `overdue`: na leitura ou em job?

**Onde**: `09-financial.md:124` deixa em aberto.

**Decisão**: opção 1 — **derivado em runtime, nunca persistido**.

- `car.status` e `bill.status` viram `pending | partial | paid | cancelled` (remove `overdue`).
- "Overdue" é uma condição derivada: `status IN (pending, partial) AND due_date < current_date`.
- Sem job scheduler no MVP. Notificações de vencido ficam para quando houver necessidade — e podem ser um job separado, sem mexer no `status`.
- UI mostra "overdue" como categoria visual, backing pela condição derivada.

**Docs a atualizar**: `09-financial.md` (enum de status no CAR e Bill, regras de transição, diagrama).

**Status**: `decided`

---

### B5. Seller sem user (representante externo)?

**Onde**: `05-sellers.md:64` diz "um seller por user por org" mas não explicita se `user_id` é obrigatório.

**Decisão**: opção 2 — **`user_id` nullable**, com email/phone no próprio seller.

- `seller.user_id`: FK nullable. Null = representante externo sem acesso ao sistema.
- Campos novos em `seller`:
  - `email` — nullable, usado quando `user_id IS NULL`
  - `phone` — nullable, usado quando `user_id IS NULL`
- Constraint: `user_id IS NOT NULL OR email IS NOT NULL OR phone IS NOT NULL` (seller precisa ter algum canal identificável).
- Quando `user_id` preenchido, email/phone no seller são ignorados (fonte de verdade = user do Better Auth).
- **Bill de comissão**: `bill.supplier_id` vira nullable e um novo campo `bill.seller_id` (FK → `seller`, nullable) é adicionado. Bills com `origin = commission` usam `seller_id` (e `supplier_id` fica null). Bills com `origin = purchase_order | manual` usam `supplier_id`.

**Docs a atualizar**: `05-sellers.md` (tabela seller, validação), `09-financial.md` (tabela bill — nullability de supplier_id, novo seller_id, e como comissão aponta).

**Status**: `decided`

---

### B6. Numeração de sales_order, purchase_order, invoice

**Onde**: diversos docs dizem "gerado automaticamente, único por org" sem estratégia.

**Decisão**: opção 2 — **tabela `document_sequence` por (org, entity_type)** com incremento atômico.

Schema:

```
document_sequence
  id              uuid
  organization_id uuid
  entity_type     enum('sales_order' | 'purchase_order' | 'invoice')
  prefix          string        -- 'SO' | 'PO' | 'INV'
  next_value      integer       -- default 1
  UNIQUE (organization_id, entity_type)
```

Geração:

```
UPDATE document_sequence
   SET next_value = next_value + 1
 WHERE organization_id = X AND entity_type = Y
RETURNING next_value - 1 AS assigned;

number = prefix || '-' || LPAD(assigned::text, 6, '0');   -- ex.: SO-000001
```

- Registros (`sales_order`, `purchase_order`, `invoice`) são criados com `next_value = 1` no momento de criação da organization (ou lazy na primeira geração).
- **Gap-free não é obrigatório no MVP**: `invoice.number` é o número interno do Dolabra; o número oficial da NF-e vai em `invoice.nf_number` (campo separado). Quando a emissão nativa de NF-e entrar, a numeração fiscal usa sequência própria gap-free.

**Docs a atualizar**: `01-foundation.md` (definir tabela `document_sequence`), `06-sales-orders.md`, `07-invoices.md`, `08-purchase-orders.md` (nota no campo `number`).

**Status**: `decided`

---

### B7. Tax group: DIFAL, FCP, MVA-ST

**Onde**: `10-tax-groups.md` cobre ICMS/PIS/COFINS/IPI/ICMS-ST rate, mas não DIFAL (diferencial de alíquota), FCP (fundo de combate à pobreza), MVA/IVA (base de cálculo ST).

**Status**: `deferred` — pós-MVP junto com emissão de NF-e. Mas o schema do tax_group deve permitir evolução sem migration destrutiva.

---

## Bloco D — Achados durante propagação

### D1. Direção do movimento `adjustment`

**Onde**: `03-inventory.md:79` diz que `quantity` é sempre positiva e direção vem de `type`. Funciona para `in` (+) e `out` (−), mas `adjustment` pode ir para os dois lados (contagem pra mais/menos, cancelamento de invoice, correções manuais).

**Decisão**: opção 3 — **dois subtipos de adjustment**. `type` vira `in | out | adjustment_in | adjustment_out`.

- Mantém a invariante "quantity sempre positiva; direção pelo type".
- `adjustment_in`: invoice_cancellation, contagem onde `counted > system`, correção manual pra mais.
- `adjustment_out`: contagem onde `counted < system`, correção manual pra menos.
- Nenhum dos dois atualiza custo médio (igual ao `adjustment` atual).

**Docs a atualizar**: `03-inventory.md` (enum de type + tabela de tipos), `07-invoices.md` (texto de cancelamento usa `adjustment_in`).

**Status**: `decided`

---

### D9. Inventory counts concorrentes

**Onde**: `03-inventory.md:107-117` define `inventory_count` com status `draft | in_progress | completed` mas não diz se múltiplos counts podem estar em progresso simultaneamente.

**Decisão**: opção 3 — **um count por vez por org**. Enquanto houver count em `in_progress`, não pode abrir outro.

- Constraint: partial unique index em `inventory_count (organization_id)` onde `status = 'in_progress'`.
- Counts paralelos por escopo (categoria/filial) ficam para pós-MVP, junto com multi-filial.

**Docs a atualizar**: `03-inventory.md` (seção inventory_count — adicionar constraint).

**Status**: `decided`

---

### D8. Invoice `draft` — ciclo de vida

**Onde**: `07-invoices.md:69-72` define os status mas não explica quem cria o draft, se é editável, e quando os snapshots acontecem.

**Decisão**: opção 2 — **draft editável com cópia de dados do sales_order**.

Regras:
- Usuário dispara "preparar invoice" a partir de um sales_order (em `approved` ou `picking`). Sistema cria invoice em `draft` copiando itens, quantidades e `unit_price` do sales_order.
- Faturamento parcial: o usuário escolhe quais itens/quantidades entram neste draft. Múltiplos drafts coexistem por sales_order.
- Draft é **editável**: quantidades, preços e notas podem ser ajustados antes de emitir.
- Draft **não gera** stock_movement, CAR ou snapshot fiscal.
- `issued_at` é preenchido apenas na transição `draft → issued`.
- Snapshot fiscal (ncm/cst/rates do `tax_group`) e `customer_snapshot` são copiados **no momento da emissão** (`draft → issued`), não antes.
- Draft pode ser descartado — deleção livre enquanto em `draft`.

**Docs a atualizar**: `07-invoices.md` (seção sobre draft + quando snapshots acontecem).

**Status**: `decided`

---

### D7. Unique em `stock_balance(sku_id)`

**Onde**: `03-inventory.md:56` diz "um registro por SKU" mas o schema não declara unique constraint.

**Decisão**: **unique `(organization_id, sku_id)` no `stock_balance`**. DB garante a invariante; sem constraint, race conditions em upsert podem criar duplicatas.

**Docs a atualizar**: `03-inventory.md` (tabela stock_balance).

**Status**: `decided`

---

### D6. `address.organization_id`

**Onde**: `01-foundation.md:76-91` define `address` sem `organization_id`, violando a invariante declarada em `01-foundation.md:94`.

**Decisão**: **adicionar `organization_id` em `address`**. Toda tabela de domínio tem tenancy direta, sem exceção.

**Docs a atualizar**: `01-foundation.md` (tabela address).

**Status**: `decided`

---

### D5. `due_date` do Bill gerado na confirmação da PO

**Onde**: `08-purchase-orders.md:151` diz que o Bill "vence na data acordada" mas não existe tal campo no PO. `expected_date` é de entrega, não vencimento.

**Decisão**: opção 1 — **PO usa o mesmo `payment_term` do sales_order**. Simetria total.

- `purchase_order.payment_term_id`: FK → `payment_term` (ver `09-financial.md`), obrigatório.
- Na confirmação da PO, o sistema gera N Bills (1 por `payment_term_installment`):
  - `due_date` = `purchase_order.confirmed_at + days_offset`
  - `amount` = `purchase_order.total × pct / 100` (última parcela absorve arredondamento)
  - `installment_number` = `sequence`
  - `installment_total` = total de parcelas
- "À vista" = template com 1 parcela, `days_offset = 0`, `pct = 100`.

**Docs a atualizar**: `08-purchase-orders.md` (campo novo + texto da confirmação), `09-financial.md` (seção payment_term / geração de Bills na PO).

**Status**: `decided`

---

### D4. Comissão quando o produto não tem categoria

**Onde**: `product.category_id` é nullable. `seller_category_commission` exige `category_id`.

**Decisão**: opção 1 — **produto sem categoria sempre usa `seller.default_commission_pct`**. Sem fallback adicional, sem obrigar categoria.

- Se a empresa quiser "só pagar comissão via categoria", basta setar `default_commission_pct = 0`.
- Não há "catch-all" de override para produtos sem categoria — mantém o modelo enxuto.

**Docs a atualizar**: `09-financial.md` (passo 2 do cálculo — esclarecer fallback).

**Status**: `decided`

---

### D3. `price_list_item` para kit conforme `kit_price_mode`

**Onde**: decisão A3 deixou implícito o papel de `price_list_item` por modo, mas não tratou os casos de lixo/órfão quando o modo muda.

**Decisão**: opção 2 — **validação na camada de serviço**.

Regras ao editar `kit_price_mode`:

- **mudar para `fixed`**: exigir `price_list_item` do SKU do kit na `price_list` default no mesmo request. Sem isso, bloquear. Price_lists adicionais (atacado etc.) podem ser preenchidas depois.
- **mudar para `sum` ou `discount`**: deletar (ou ignorar) os `price_list_item` existentes para o SKU do kit — vira lixo.
- **mudar entre `sum` e `discount`**: só o valor de `kit_discount_pct` precisa ser ajustado.

Regras na emissão/venda:
- Se `kit_price_mode = fixed` e não houver `price_list_item` na `price_list` do pedido, erro explícito ("preço do kit X não cadastrado na tabela Y"), sem fallback silencioso.

**Docs a atualizar**: `02-products.md` (seção Kit / Precificação — adicionar regras de serviço).

**Status**: `decided`

---

### D2. Campos do SKU para kit

**Onde**: A3 decidiu que todo product tem ≥1 SKU, inclusive kits. Mas campos de SKU (cost_price, weight, dims, supplier_ref) foram desenhados pra produtos físicos.

**Decisão**: opção 1 — **sem constraint de DB**. Todos os campos do SKU continuam nullable.

- Para kits, `cost_price` e `weight` são **calculados em runtime** a partir dos componentes — a coluna no SKU do kit é ignorada.
- `height/width/depth` ficam livres (box do kit pode ter dimensões próprias).
- `supplier_ref` não se aplica a kit; a UI oculta o campo no formulário.
- `ean_gtin` e `image_url` funcionam normalmente (kit pode ter GTIN e foto próprios).
- Constraints em DB ficam fora: regras de negócio evoluem; a UI e a camada de serviço são as guardiãs.

**Docs a atualizar**: `02-products.md` (nota na seção SKU sobre comportamento em kits).

**Status**: `decided`

---

## Bloco C — Gaps menores / nice-to-have

### C1. Unicidade de `product.name` por org

`02-products.md:107` tem `slug` único, mas `name` pode se repetir. Ok no MVP?

**Decisão**: **sem unique constraint em `name`**. Slug é o identificador; nome é legível. Dois produtos com o mesmo nome são permitidos.

**Status**: `decided`

### C2. `inventory_count_item` sem `organization_id`

`03-inventory.md:121-127` — item do count não tem tenancy direta, herda via `inventory_count_id`. Query sempre precisa do join. Aceitável, mas vale considerar denormalizar para simplificar policies de RLS.

**Decisão**: **denormalizar `organization_id` em `inventory_count_item`**. Consistente com o princípio declarado em `01-foundation.md:94` ("toda tabela de domínio tem `organization_id`") e facilita RLS/queries no futuro.

**Docs a atualizar**: `03-inventory.md` (tabela `inventory_count_item`).

**Status**: `decided`

### C3. Reserva de estoque em sales_order aprovado

`06-sales-orders.md:75` menciona "reserva de estoque pode ser aplicada (futuro)". Sem reserva, aprovar pedido não garante estoque no picking — risco operacional declarado.

**Status**: `deferred` explícito, ok.

### C4. Transições de status do contact sem efeito cascata

`04-contacts.md:88-92`: bloquear um contact não cancela CARs em aberto. Comportamento esperado, mas vale documentar explicitamente.

**Decisão**: **sem cascata**. Status do contact afeta só criação de novos pedidos/documentos. CARs, Bills, sales_orders e purchase_orders existentes seguem seu fluxo normal. Um CAR é um direito real da empresa — não desaparece porque o cliente foi bloqueado.

**Docs a atualizar**: `04-contacts.md` (seção de status).

**Status**: `decided`

---

## Como usar este log

- Ao revisitar uma decisão: começar pelos docs 01–10 (o "o quê"); vir aqui se o "porquê" estiver faltando.
- Ao mudar uma decisão: atualizar os docs 01–10 primeiro, e adicionar uma nota aqui no item correspondente ("Revista em YYYY-MM-DD — nova decisão + motivo"). **Não reescrever** o histórico; sobrescrever perde a razão original.
- Ao tomar decisões novas (pós-MVP, novos módulos): criar um bloco novo (E, F, …) com o mesmo formato.
