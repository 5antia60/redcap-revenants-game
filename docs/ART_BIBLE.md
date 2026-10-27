# Art bible — direção inicial

Estado: direção temática e planejamento global aprovados; especificações de produção abaixo precisam de amostra, não são arte final aprovada. Não há assets produzidos.

## 1. Identidade
Apocalipse urbano brasileiro visto de cima em perspectiva aparente: feira interrompida, concreto gasto, telhas, grades, ônibus abandonado, vegetação oportunista e vestígios de vida cotidiana. Local reconhecível por arquitetura e materiais, sem depender de bandeiras, caricaturas, marcas comerciais ou miséria como decoração.

Contraste central escolhido: luz quente de fim de tarde e sombras azuladas. Fundo menos contrastado que personagens e perigos. Violência, grau de gore, região/cidade e identidade do protagonista ainda precisam de escolha do usuário.

## 2. Linguagem visual proposta
Arte 2D estilizada com massas de cor e silhuetas fortes, não fotorrealismo. Evitar decidir agora entre pintura de alta resolução, desenho com contorno e pixel art sem uma amostra comparável. Recomendação para amostra: desenho estilizado de resolução moderada e animação por quadros das ações essenciais; custo e habilidade disponível podem justificar recortes articulados. Nenhuma técnica exige contratação ou ferramenta paga automática.

Paleta exploratória, a validar em imagem: concreto areia, terracota, verde ressecado, azul-petróleo nas sombras e acentos reservados para perigo/interação. Cor nunca é o único aviso: combinar forma, animação e som. Não atribuir simultaneamente a mesma cor a cura e ataque hostil.

Primeira aprovação visual exige uma imagem com chão, obstáculo alto, sobrevivente, zumbi e efeito de ataque; depois uma animação curta na arena. Uma imagem bonita isolada não aprova leitura em movimento.

## 3. Regras espaciais e de leitura
- Ponto de apoio nos pés consistente entre todos os quadros; sombra não desloca a colisão.
- Perspectiva e escala compartilhadas entre chão, personagens e props. Ângulo final e densidade de pixels definidos na amostra, não por números arbitrários agora.
- Personagem, ameaça e área ativa legíveis a 1080p; teste adicional em janela menor antes do slice final.
- Props altos permitem oclusão controlada, recorte ou transparência aprovada; nenhum detalhe pode ocultar ataque essencial.
- Antecipação, ação e recuperação têm poses distintas. Zumbis não se distinguem apenas pela roupa ou cor.
- Efeitos ficam abaixo do limite de legibilidade: poeira, sangue e brilho não substituem telegráfico nem cobrem o chão por completo.

## 4. Pipeline de criação e integração
1. **Brief pequeno:** função, escala, perspectiva, estados necessários, dimensões/pivô e responsável; não encomendar pacote inteiro antes da prova.
2. **Blockout:** formas simples validam espaço e combate; identificadas como temporárias.
3. **Amostra:** um personagem, um inimigo, um chão, um prop e um efeito; usuário aprova técnica/estilo antes de produção em volume.
4. **Produção:** arquivos-fonte editáveis e exports separados. PNG com transparência para sprites; formatos de áudio/importação escolhidos segundo licença e suporte da engine.
5. **Importação:** preset documenta filtragem, compressão, escala e atlas quando necessário. Não ativar pixel snapping ou filtragem por hábito; depende da técnica aprovada.
6. **Integração:** implementador liga animações, pivôs e sons sem modificar janelas de dano implicitamente. Verifica import limpo, referências e diferenças no Git.
7. **Aceite:** capturas e vídeo com ambos os dispositivos, teste de oclusão, redução de efeitos e comparação com amostra aprovada.

## 5. Proveniência, ferramentas e orçamento
Fontes possíveis: produção própria, pacote licenciado ou encomenda. Escolha depende de orçamento, disponibilidade e compatibilidade estética, ainda desconhecidos. Não é necessário produzir tudo do zero, mas misturar estilos aumenta custo de adaptação.

Cada pacote precisa de origem, autor, licença, versão/data, permissão para modificar/redistribuir e atribuição exigida em `assets/licenses/` quando importado. Guardar fontes permitidas; não copiar arte de Hades, fotografias privadas, marcas ou material sem licença clara. Confirmar permissões de fontes tipográficas e sons também.

IA generativa é alternativa não autorizada por padrão: exige decidir ferramenta, custo, envio de dados, termos de uso, consistência e possibilidade de edição. Agentes de texto não substituem artista nem garantem spritesheets coerentes. Assets provisórios não viram finais por silêncio.

## 6. Áudio e interface
Paisagem sonora urbana vazia e ruídos próximos ajudam a localizar ameaças. Primeiro validar poucos sons distintos: aviso, ataque, impacto, dano recebido e morte. Mix deve preservar aviso sobre música e efeitos. Evitar volume e flashes excessivos como atalho para impacto.

Interface discreta e funcional, com tipografia legível e símbolos compatíveis com controle/teclado. Não simular sujeira ou desgaste sobre informações essenciais. Música, identidade gráfica final e logotipo ficam fora da primeira prova de combate.

## 7. Riscos de produção
Animações em muitas direções, cenários excessivamente detalhados, gore e variedade de armas multiplicam custo. Validar direções necessárias antes de produzir quadros; espelhamento pode inverter assimetrias e precisa de teste. Manter lista explícita de assets temporários e finais no contexto da sprint. Não prometer qualidade final com placeholders ou dependência de geração automática não validada.
