# Grupos Fiscais

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                 TAX GROUPS — FLUXO DE SNAPSHOT                       ║
╚══════════════════════════════════════════════════════════════════════╝

  CONFIGURAÇÃO (feita uma vez pelo admin da org):

    ┌──────────────────────────────────────────────────────────────┐
    │                      TAX GROUP                               │
    │                                                              │
    │  name: "Vestuário — nacional"                                │
    │  ncm: 61091000                                               │
    │  cfop_same_state: 5102                                       │
    │  cfop_other_state: 6102                                      │
    │  icms_cst / icms_rate                                        │
    │  pis_cst  / pis_rate                                         │
    │  cofins_cst / cofins_rate                                    │
    │  ipi_cst  / ipi_rate (nullable)                              │
    └──────────────────────────────┬───────────────────────────────┘
                                   │ atribuído a
                                   ▼
    ┌──────────────────────────────────────────────────────────────┐
    │                       PRODUCT                                │
    │  tax_group_id ──────────────────────────────────────────►    │
    │  (todos os SKUs deste produto compartilham o mesmo group)    │
    └──────────────────────────────┬───────────────────────────────┘
                                   │ na emissão da invoice
                                   ▼
  ┌──────────────────────────────────────────────────────────────────┐
  │                        INVOICE ITEM                              │
  │                                                                  │
  │  RESOLUÇÃO DE CFOP:                                              │
  │  org.state == customer.state?                                    │
  │    sim ──► copia cfop_same_state                                 │
  │    não ──► copia cfop_other_state                                │
  │                                                                  │
  │  SNAPSHOT (congelado, imutável):                                 │
  │  ncm    cest    cfop (resolvido)    origin                       │
  │  icms_cst  icms_rate                                             │
  │  pis_cst   pis_rate                                              │
  │  cofins_cst cofins_rate                                          │
  │  ipi_cst   ipi_rate                                              │
  └──────────────────────────────────────────────────────────────────┘
                                   │
                                   │ após o snapshot:
                                   ▼
    Editar o TAX GROUP NÃO afeta esta invoice.
    Registros fiscais históricos ficam permanentemente protegidos.

  CST vs CSOSN (determinado por org.tax_regime):

    simples_nacional  ──► icms_cst armazena CSOSN (3 dígitos)
    presumed_profit   ──► icms_cst armazena CST   (2 dígitos)
    real_profit       ──► icms_cst armazena CST   (2 dígitos)
```

Um tax group é um conjunto reutilizável de regras fiscais brasileiras atribuído a um produto. Centraliza a configuração fiscal para que muitos produtos possam compartilhar as mesmas regras e as alterações se propaguem automaticamente — até que uma venda seja faturada, momento em que as regras são snapshotadas e congeladas.

## Conceito

O administrador da org cria tax groups nomeados (ex.: "Vestuário — nacional", "Eletrônicos importados — SP"). Cada produto é associado a um tax group. No momento do faturamento, os valores atuais do tax group são copiados para cada `invoice_item`. Depois desse ponto, editar o tax group não tem efeito sobre invoices históricas.

Tax groups são atribuídos no nível de **product**, não no nível de SKU — todos os SKUs de um produto compartilham as mesmas regras fiscais.

## Tax group

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `name` | string | Rótulo definido pelo usuário. ex.: "Vestuário — nacional" |
| `ncm` | string | Código NCM de 8 dígitos |
| `cest` | string | Nullable. Obrigatório em cenários de ICMS-ST |
| `origin` | enum | `0` domestic \| `1` foreign_direct \| `2` foreign_domestic \| `3` domestic_high_import \| `4` domestic_above_40 \| `5` domestic_below_40 \| `6` foreign_no_similar \| `7` foreign_customs_area — Tabela A de origem fiscal BR |
| `cfop_same_state` | string | CFOP para vendas dentro do estado |
| `cfop_other_state` | string | CFOP para vendas interestaduais |
| `taxable_unit` | string | Unidade fiscal (pode diferir da unidade de venda do produto) |
| `icms_cst` | string | Código CST ou CSOSN dependendo de `tax_regime` |
| `icms_rate` | decimal | Nullable. ex.: `12.00` para 12% |
| `icms_st_rate` | decimal | Nullable. Alíquota de ICMS-ST |
| `icms_bc_reduction` | decimal | Nullable. Percentual de redução de base |
| `pis_cst` | string | |
| `pis_rate` | decimal | Nullable |
| `cofins_cst` | string | |
| `cofins_rate` | decimal | Nullable |
| `ipi_cst` | string | Nullable |
| `ipi_rate` | decimal | Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

## Notas sobre a seleção de CFOP

O CFOP correto depende de o comprador estar ou não no mesmo estado do vendedor. No momento do faturamento, o sistema compara o estado da org (`organization.state`) com o estado do customer (`contact_address.state`) para escolher entre `cfop_same_state` e `cfop_other_state` do tax group.

## Notas sobre ICMS CST vs CSOSN

- Empresas no **Simples Nacional** (`tax_regime = simples_nacional`) usam códigos **CSOSN** (3 dígitos).
- Empresas no **Lucro Presumido** ou **Lucro Real** usam códigos **CST** (2 dígitos).
- O campo `icms_cst` guarda o que for aplicável. A camada de renderização da invoice usa `organization.tax_regime` para rotulá-lo corretamente na NF-e (pós-MVP).

## Snapshot no faturamento

Quando uma invoice é emitida, os seguintes campos são copiados do tax group resolvido para cada `invoice_item` e tornam-se imutáveis:

`ncm`, `cest`, `cfop`, `origin`, `icms_cst`, `icms_rate`, `pis_cst`, `pis_rate`, `cofins_cst`, `cofins_rate`, `ipi_cst`, `ipi_rate`

O `cfop` copiado é o resolvido (mesmo estado ou outro estado), não os dois.

## Edição e exclusão

| Operação | Regra |
|---|---|
| **Editar** | Sempre permitida. O snapshot na invoice já protege o histórico fiscal — invoices antigas continuam com os valores congelados. Novas invoices passam a usar os valores atualizados. |
| **Deletar** | **Bloqueada se houver `product` apontando para o tax_group.** Para "aposentar" um tax_group em uso, reatribua os produtos primeiro. Sem soft-delete no MVP — ver [B15](#b15-tax_group-edição-livre-deleção-bloqueada-se-em-uso). |

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final.

### B15. tax_group: edição livre, deleção bloqueada se em uso

**Onde**: não estava definido se editar/deletar um tax_group em uso era permitido.

**Decisão**:

- **Editar**: sempre. Snapshot na invoice já protege histórico (decisão A2/D8).
- **Deletar**: bloqueado se algum `product` aponta para o tax_group. UI lista os produtos afetados para o usuário decidir reatribuir antes.
- Sem soft-delete (`is_active`) no MVP — a complexidade adicional não se justifica enquanto a deleção dura é simples de bloquear.

**Status**: `decided`

### C9. Validação só de formato (sem tabela oficial)

**Onde**: campos fiscais (NCM, CFOP, CSOSN, CST, origem) precisavam de regra de validação. Validar contra tabela oficial da Receita Federal exigiria sincronização com base externa.

**Decisão**: **MVP valida apenas formato** (comprimento + dígitos). Validação contra tabela oficial fica para pós-MVP.

- NCM: 8 dígitos numéricos.
- CFOP: 4 dígitos numéricos.
- CSOSN: 3 dígitos (Simples Nacional).
- CST: 2 dígitos (Lucro Presumido/Real).
- Origem: enum 0-7 (Tabela A já restringe).
- O operador fiscal é responsável por informar códigos válidos para a operação.

**Status**: `decided` — convenção completa em [docs/00-globais/README.md](../00-globais/README.md).

### B7. DIFAL, FCP, MVA-ST

**Onde**: o módulo cobre ICMS/PIS/COFINS/IPI/ICMS-ST rate, mas não DIFAL (diferencial de alíquota), FCP (fundo de combate à pobreza), MVA/IVA (base de cálculo ST).

**Status**: `deferred` — pós-MVP junto com emissão de NF-e. O schema do `tax_group` deve permitir evolução sem migration destrutiva.

### Referências cruzadas

- **Convenções globais** — validação de formato (NCM 8d, CFOP 4d, etc.) e arredondamento monetário: [docs/00-globais/README.md](../00-globais/README.md).
