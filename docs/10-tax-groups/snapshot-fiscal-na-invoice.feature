# language: pt

Funcionalidade: Snapshot fiscal imutável na invoice
  No momento da emissão, cada invoice_item recebe uma cópia congelada dos
  campos fiscais do tax_group. Depois disso, editar o tax_group não afeta
  mais a invoice. Isso protege o histórico fiscal da empresa — essencial
  para auditoria e escrituração.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o tax_group "Alimento — padaria" com ICMS CSOSN 102, PIS rate 0,65 e COFINS rate 3,00
    E um pedido pronto para faturamento

  Cenário: Campos copiados no momento da emissão
    Quando a invoice é emitida
    Então cada invoice_item recebe cópia dos campos:
      | Campo       |
      | NCM         |
      | CEST        |
      | CFOP        |
      | Origem      |
      | ICMS CST    |
      | ICMS rate   |
      | PIS CST     |
      | PIS rate    |
      | COFINS CST  |
      | COFINS rate |
      | IPI CST     |
      | IPI rate    |
    E esses valores ficam imutáveis mesmo se o tax_group for alterado depois

  Cenário: Edição no tax_group não afeta invoices antigas
    Dado uma invoice emitida com COFINS rate 3,00 (snapshot)
    Quando um admin edita o tax_group para COFINS rate 7,60
    Então a invoice antiga continua com COFINS rate 3,00
    E uma nova invoice emitida daqui pra frente usa 7,60

  Cenário: Draft não congela nada
    Dado uma invoice em "draft"
    Quando o tax_group associado ao produto é editado
    Então o draft ainda não tem snapshot fiscal (vai copiar os valores ATUAIS só quando for emitida)

  Cenário: Snapshot do customer também é congelado na emissão
    Dado o customer "Restaurante Sabor" com CNPJ "98.765.432/0001-10" e IE "123456789012"
    Quando a invoice é emitida
    Então customer_snapshot registra CNPJ, razão social, IE e endereço completos
    E se o customer tiver o CNPJ alterado depois (ex.: correção cadastral), a invoice antiga continua com o CNPJ original
