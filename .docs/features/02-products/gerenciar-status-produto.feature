# language: pt

Funcionalidade: Ciclo de vida do status do produto
  Um produto passa por uma trajetória explícita de status: draft → active,
  podendo alternar entre active e inactive, até chegar a archived
  (irreversível). Cada status define onde o produto aparece no ERP.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o produto "Pão Francês" em status "draft"

  Cenário: Publicar produto (draft → active)
    Quando Cesar muda o status de "Pão Francês" para "active"
    Então "Pão Francês" passa a aparecer em formulários de pedido de venda
    E passa a aparecer em relatórios de estoque
    E passa a aparecer em tabelas de preço

  Cenário: Desabilitar temporariamente (active → inactive)
    Dado que "Pão Francês" está com status "active"
    Quando Cesar muda o status para "inactive"
    Então "Pão Francês" não pode ser selecionado em novos pedidos de venda
    Mas pedidos e notas antigas que referenciam "Pão Francês" continuam intactos

  Cenário: Reativar produto inactive
    Dado que "Pão Francês" está com status "inactive"
    Quando Cesar muda o status para "active"
    Então "Pão Francês" volta a aparecer em formulários de novos pedidos

  Cenário: Arquivar produto é irreversível
    Dado que "Pão Francês" está com status "active"
    Quando Cesar arquiva o produto
    Então o status fica "archived"
    E o produto vira read-only (nenhum campo pode ser editado)
    E o produto é ocultado de todas as listagens operacionais
    E Cesar não consegue mais voltar o status para "active" ou "inactive"

  Esquema do Cenário: Transições inválidas são rejeitadas
    Dado que "Pão Francês" está com status "<origem>"
    Quando Cesar tenta mudar o status para "<destino>"
    Então a transição é rejeitada

    Exemplos:
      | origem   | destino  |
      | archived | active   |
      | archived | inactive |
      | archived | draft    |
      | active   | draft    |
      | inactive | draft    |
