# language: pt

Funcionalidade: Galeria de imagens do produto
  Cada produto tem uma galeria ordenada de imagens. SKUs podem sobrescrever
  com uma imagem própria (ex.: cor diferente). As imagens ficam armazenadas
  no Cloudflare R2 e expostas via URL pública.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o produto "Croissant" com SKUs por sabor (Doce, Salgado)

  Cenário: Upload de múltiplas imagens na galeria
    Quando Cesar faz upload de 3 imagens para o produto "Croissant"
    Então as 3 imagens aparecem na galeria com "position" 1, 2 e 3

  Cenário: Reordenar a galeria
    Dado o produto "Croissant" com imagens nas posições 1, 2, 3
    Quando Cesar arrasta a imagem da posição 3 para a posição 1
    Então a ordem fica: a antiga 3ª em 1, a antiga 1ª em 2, a antiga 2ª em 3

  Cenário: SKU sobrescreve imagem da galeria
    Dado o produto "Croissant" com imagem principal "croissant-padrao.jpg"
    Quando Cesar define a imagem "croissant-doce.jpg" no SKU "Croissant Doce"
    Então listagens que mostram o SKU "Croissant Doce" exibem "croissant-doce.jpg"
    Mas listagens do produto-pai continuam exibindo "croissant-padrao.jpg"

  Cenário: SKU sem imagem própria herda a galeria do produto
    Dado o produto "Croissant" com imagem principal "croissant-padrao.jpg"
    E o SKU "Croissant Salgado" sem imagem própria
    Quando uma listagem precisa de imagem para "Croissant Salgado"
    Então "croissant-padrao.jpg" é usada como fallback
