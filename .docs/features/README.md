# Features — especificação executável

Estes arquivos descrevem o comportamento do Dolabra em linguagem natural (Gherkin em pt-BR). Servem como:

- **Contrato de negócio**: o que o ERP precisa fazer, descrito sem menção a tabelas, SQL, APIs ou frameworks.
- **Base para TDD**: cada cenário vira um ou mais testes automatizados. A stack pode trocar (Vitest, Playwright, runner em Go…) — os `.feature` permanecem.
- **Documentação viva**: lida por pessoa de produto, vendedor, contador. Não precisa ler código.

## Convenções

- Idioma: pt-BR (keywords `Funcionalidade`, `Contexto`, `Cenário`, `Esquema do Cenário`, `Dado`, `Quando`, `Então`, `E`, `Mas`).
- Nomes de entidades/campos de schema permanecem em inglês quando aparecem (seguindo a convenção dos docs): `sales_order`, `tax_group`, `CAR`, `Bill`, `SKU`.
- Um arquivo `.feature` = uma capacidade de negócio. Cenários dentro são variações da mesma capacidade.
- Dados de exemplo vão em tabelas Gherkin. Evitar "placeholder mágico" quando o valor real ajuda a entender a regra (ex.: CNPJ formatado, valores em reais).
- Nunca mencionar tabelas, colunas, endpoints HTTP, nomes de funções, TypeScript, Drizzle. Só regras de negócio observáveis.

## Organização

```
.docs/features/
├── 01-foundation/     # Auth, organizations, numeração de documentos, endereços
├── 02-products/       # Produtos, SKUs, atributos, categorias, kits, tabelas de preço
├── 03-inventory/      # Saldos, movimentos, contagens, custo médio
├── 04-contacts/       # Customers e suppliers
├── 05-sellers/        # Vendedores e regras de comissão
├── 06-sales-orders/   # Pedidos de venda
├── 07-invoices/       # Faturas (NF)
├── 08-purchase-orders/# Pedidos de compra e recebimentos
├── 09-financial/      # CAR, Bill, pagamentos, fluxo de caixa, cálculo de comissão
└── 10-tax-groups/     # Grupos fiscais e snapshot
```

## Referência cruzada

A ordem e os casos aqui espelham os docs de `.docs/01-foundation.md` até `.docs/10-tax-groups.md` (mesmo diretório, nível acima). O "porquê" das decisões mora em `.docs/00-decisions-log.md`.
