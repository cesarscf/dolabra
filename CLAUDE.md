# Dolabra — guia de desenvolvimento

ERP estilo Bling/Olist em construção. Stack: Bun + Vite + React + Drizzle (Neon Postgres) + Better Auth.

## Antes de codar

A documentação em `docs/` é a fonte de verdade do comportamento. Sempre consulte:

1. **`docs/00-globais/README.md`** — convenções transversais (arredondamento, delete, validação de documentos, idempotência). Aplicam a todo módulo.
2. **`docs/NN-feature/README.md`** — schema e decisões arquiteturais do módulo. A seção *Decisões arquiteturais* explica o **porquê** das escolhas — leia antes de "melhorar" algo.
3. **`docs/NN-feature/*.feature`** — cenários Gherkin. São contrato de negócio executável.

Se a doc não cobre o caso, **pare e pergunte** antes de chutar. Não invente regra de negócio — registre a decisão na doc primeiro.

## Ordem de implementação

Os módulos têm dependências reais — siga essa sequência:

```
1. Foundation        (org, member, address, document_sequence)
2. Contacts
3. Tax Groups        → 4. Products (Products precisa de tax_group)
5. Sellers
6. Inventory         (movimentos + saldos)
7. Sales Orders
8. Invoices          (junta SO + inventory + tax_group + customer_snapshot)
9. Financial         (CAR, Bill, payment_terms, payments)
10. Purchase Orders
11. Comissão         (ponta final, exercita tudo — Sellers + Financial)
```

Não pule etapas para "ver funcionando" — a divida técnica fica visível depois.

## Estratégia de TDD

A doc tem ~330 cenários Gherkin. Não significa "escreva 330 testes antes da primeira tela". Significa: o comportamento esperado está descrito, use isso como contrato.

**Alto valor de TDD — escreva testes ANTES do código:**
- Arredondamento monetário (`docs/00-globais/arredondamento-monetario.feature`).
- Geração de CAR/Bill a partir de payment_term.
- Cálculo de comissão (regras + idempotência).
- Custo médio ponderado móvel.
- Transições de status (sales_order, purchase_order, invoice, inventory_count).
- Snapshot fiscal e snapshot do customer na emissão.
- Snapshot+delta do inventory_count.

**Médio valor — TDD ajuda mas não bloqueante:**
- Validações de input (DV de CNPJ/CPF/GTIN, formato NCM/CFOP).
- Regras de delete (em uso × sem uso).
- Pré-preenchimento de defaults (seller, price_list, payment_term).

**Baixo valor — escreva teste DEPOIS ou só smoke:**
- UI/forms.
- Upload para R2 (Cloudflare).
- Integração com Better Auth (já testado upstream).
- Migrations (rode contra ambiente local).

## Padrões de código a seguir

### Permissões (deferred — mas codifique o stub agora)

A matriz de roles × operações está deferida até o core estar implementado. Para evitar retrabalho:

```ts
// shared/permissions.ts
export function canDo(
  user: User,
  action: string,
  resource: { organizationId: string; [key: string]: unknown },
): boolean {
  // TODO: módulo de permissões granulares — por enquanto qualquer membro da org pode tudo
  return user.organizationId === resource.organizationId;
}
```

Toda action sensível (cancelar invoice, encerrar PO, criar Bill manual, deletar tax_group) chama `canDo(...)` antes de executar. Quando o módulo de permissões entrar, só preenche o corpo — testes não mudam.

### Tenancy (a invariante mais importante)

Toda query de tabela de domínio **precisa** filtrar por `organization_id`. Não há exceção. Se você está escrevendo uma query sem `organizationId`, está errado.

Padronize via repository/service que recebe `organizationId` no construtor — nunca aceite query "global".

### Transações para efeitos colaterais

Operações que disparam efeitos múltiplos (emitir invoice, confirmar PO, registrar pagamento) acontecem **dentro de uma única transação**. Falha em qualquer passo desfaz todos os anteriores.

Drizzle: use `db.transaction(async (tx) => { ... })`. Não monte "saga" manual.

### Idempotência

Não confie em "o usuário não vai clicar duas vezes". Garantia vem de constraint:

- `UNIQUE (invoice_id, installment_number)` em `car`.
- `UNIQUE (purchase_order_id, installment_number)` em `bill`.
- `UNIQUE (car_id) WHERE origin = 'commission'` em `bill`.
- Movimentos de estoque referenciam `purchase_receipt_item.id` direto — re-tentativa identifica e aborta.

Quando criar tabela nova com geração derivada, pense na constraint que impede duplicação.

### Decimal e arredondamento

Valores em R$ usam **scale 2 com HALF_UP**. Última parcela absorve resíduo em divisões proporcionais.

Use a biblioteca decimal já adotada (não `Number` para dinheiro). Cálculos intermediários podem ter mais precisão; só arredonde no momento de persistir.

Cenários canônicos: `docs/00-globais/arredondamento-monetario.feature`.

### Validação de documentos brasileiros

CNPJ/CPF/GTIN com DV; NCM/CFOP/CST/CSOSN só formato; UF contra lista de 27. Detalhes em `docs/00-globais/README.md`.

UI sempre aceita entrada com máscara — normalize para "só dígitos" antes de persistir e antes de validar.

## Decisões deferidas — não resolva agora

Estas estão documentadas e podem aparecer durante implementação. **Não invente solução** — anote e siga em frente:

- **Permissões granulares por role** — deferred.
- **Soft delete genérico** — não usar (ver `00-globais/README.md`).
- **Concorrência fina em emissão de invoice** (duas invoices simultâneas para mesmo SKU no limite do estoque) — primeiro-a-commitar via `UPDATE … WHERE quantity >= X` atômico. Documenta na implementação.
- **Reversão automática de comissão** quando pagamento é cancelado — admin cria Bill manual de ajuste negativo (B22).
- **Validação contra tabelas oficiais** (NCMs Receita, CFOPs por operação, IE por UF) — pós-MVP junto com NF-e.
- **DIFAL, FCP, MVA-ST** — pós-MVP.
- **`delivered` no sales_order** — pós-MVP (módulo de logística).
- **Multi-filial** — pós-MVP.
- **Reserva de estoque em `approved`** — pós-MVP (C3).

## Onboarding/seed

Ao criar uma organization, o sistema deve criar automaticamente:

- `document_sequence` para `sales_order`, `purchase_order`, `invoice` com `next_value = 1`.
- 1 `payment_term` "À vista" (1 parcela, 0 dias, 100%) marcado como default.
- 1 `price_list` "Varejo" marcado como default.

Sem isso o usuário não consegue criar o primeiro pedido. Implemente como parte do flow de criação de org, na mesma transação.

## Quando bater dúvida

Ordem de busca:

1. `docs/<modulo-relevante>/README.md` — schema + decisão arquitetural.
2. `docs/<modulo-relevante>/<feature>.feature` — cenário Gherkin.
3. `docs/00-globais/README.md` — convenções transversais.
4. Pergunte antes de chutar.

Não duplique regra de negócio em código sem que ela esteja na doc. Se a regra precisa existir e não está, **atualize a doc primeiro**, depois implementa.

## Escrita de código

- Prefira editar arquivos existentes a criar novos.
- Sem comentário que descreve o "o quê" — nomes já fazem isso. Comentário só para "porquê não-óbvio".
- Sem `try/catch` decorativo. Trate erro onde tem informação para tratar.
- Sem abstração premature. Três linhas similares é melhor que helper de 10 linhas que será usado uma vez.
- Sem feature flag/compat shim quando o código pode ser substituído direto.
