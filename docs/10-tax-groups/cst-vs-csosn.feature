# language: pt

Funcionalidade: Interpretação de ICMS CST vs CSOSN conforme o regime
  O campo "icms_cst" do tax_group guarda o código de tributação do ICMS,
  mas o significado depende do regime da organization:

  - Simples Nacional → o valor é um **CSOSN** (3 dígitos, ex.: 102).
  - Lucro Presumido ou Lucro Real → o valor é um **CST** (2 dígitos, ex.: 00).

  O campo é o mesmo na tabela — o rótulo e a validação mudam.

  Cenário: Simples Nacional usa CSOSN
    Dado a organization "Padaria do Cesar LTDA" com regime "Simples Nacional"
    Quando Cesar cadastra um tax_group com icms_cst "102"
    Então o valor é aceito e rotulado como "CSOSN" na UI

    Quando Cesar tenta cadastrar outro tax_group com icms_cst "00"
    Então a validação rejeita com a mensagem "Para Simples Nacional, use um CSOSN de 3 dígitos"

  Cenário: Lucro Presumido usa CST
    Dado a organization "Bicicletaria Express LTDA" com regime "Lucro Presumido"
    Quando Cesar cadastra um tax_group com icms_cst "00"
    Então o valor é aceito e rotulado como "CST" na UI

    Quando Cesar tenta cadastrar um tax_group com icms_cst "102"
    Então a validação rejeita com a mensagem "Para Lucro Presumido, use um CST de 2 dígitos"

  Cenário: Lucro Real usa CST
    Dado a organization com regime "Lucro Real"
    Quando Cesar cadastra um tax_group com icms_cst "40"
    Então o valor é aceito como CST

  Cenário: Mudar regime da organization após cadastrar tax_groups
    Dado tax_groups cadastrados em Simples Nacional (CSOSN)
    Quando a organization migra para "Lucro Presumido"
    Então os tax_groups existentes precisam ser revisados
    E a UI sinaliza os tax_groups com CSOSN inválido sob o novo regime
    # a migração é uma exceção e fica documentada para intervenção manual
