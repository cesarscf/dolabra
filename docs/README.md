# Documentação dos módulos

Cada pasta `NN-feature/` contém:

- **`README.md`** — especificação do módulo (o "o quê" e o "porquê" do schema/comportamento). A seção *Decisões arquiteturais* no fim de cada README registra opções consideradas e tradeoffs das decisões que travam aquele módulo.
- **`*.feature`** — casos de uso em Gherkin (pt-BR). Servem como contrato de negócio executável e base para TDD.

## Estrutura

```
docs/
├── 00-globais/         # Convenções transversais (arredondamento, delete, validações, idempotência)
├── 01-foundation/      # Auth, organizations, numeração de documentos, endereços
├── 02-products/        # Produtos, SKUs, atributos, categorias, kits, tabelas de preço
├── 03-inventory/       # Saldos, movimentos, contagens, custo médio
├── 04-contacts/        # Customers e suppliers
├── 05-sellers/         # Vendedores e regras de comissão
├── 06-sales-orders/    # Pedidos de venda
├── 07-invoices/        # Faturas (NF)
├── 08-purchase-orders/ # Pedidos de compra e recebimentos
├── 09-financial/       # CAR, Bill, pagamentos, fluxo de caixa, cálculo de comissão
└── 10-tax-groups/      # Grupos fiscais e snapshot
```

A pasta `00-globais/` documenta convenções que afetam vários módulos (arredondamento monetário, política de delete, validação de documentos brasileiros, idempotência transacional). As regras de negócio específicas de cada feature continuam vivendo no módulo dono.

## Convenções dos `.feature`

- **Idioma**: pt-BR (keywords `Funcionalidade`, `Contexto`, `Cenário`, `Esquema do Cenário`, `Dado`, `Quando`, `Então`, `E`, `Mas`).
- **Nomes de entidades/campos** de schema permanecem em inglês (seguindo a convenção dos READMEs): `sales_order`, `tax_group`, `CAR`, `Bill`, `SKU`.
- Um arquivo `.feature` = uma capacidade de negócio. Cenários dentro são variações da mesma capacidade.
- **Dados de exemplo** vão em tabelas Gherkin. Evitar "placeholder mágico" quando o valor real ajuda a entender a regra (ex.: CNPJ formatado, valores em reais).
- Nunca mencionar tabelas, colunas, endpoints HTTP, nomes de funções, TypeScript, Drizzle. Só regras de negócio observáveis.

## Decisões arquiteturais

As decisões que travam schema/comportamento (originalmente centralizadas em um log único) foram distribuídas para a seção *Decisões arquiteturais* do README da feature **dona**. Os IDs (`A1`, `B6`, `D6`, …) são estáveis e podem ser cruzados — quando uma decisão afeta outra feature, o README secundário recebe um item em *Referências cruzadas* apontando para a dona.

| Bloco | Tipo | Donas |
|---|---|---|
| **A** | Estruturais (travam schema) | A1 → Contacts; A2, A3 → Products; A4 → Invoices; A5, A8 → Financial; A6 → Purchase Orders; A7 → Foundation |
| **B** | Comportamentais | B1, B2, B4, B14, B20, B22, B23 → Financial; B3, B8, B10, B11, B19 → Sales Orders; B5, B12, B13 → Sellers; B6, B18 → Foundation; B7, B15 → Tax Groups; B9, B16 → Invoices; B17 → Purchase Orders |
| **D** | Achados durante propagação | D1, D7, D9, D10 → Inventory; D2, D3 → Products; D4 → Financial; D5 → Purchase Orders; D6 → Foundation; D8 → Invoices |
| **C** | Gaps menores | C1, C5 → Products; C2 → Inventory; C3 → Sales Orders; C4, C8 → Contacts; C7 → Foundation; C9 → Tax Groups |
