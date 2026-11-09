# GDD — Último Sol

Estado vigente em 2026-11-04: S0/S1 integradas e S1 aceita; S2 e correção de dano integradas, aceite dirigido em teclado/mouse registrado e controle físico explicitamente adiado. S3 aprovada para implementação por agentes com revisão por unidade, somente no recorte abaixo. Nome criativo provisório. Repositório de trabalho: `redcap-revenants-game`.

## 1. Visão e decisões confirmadas
Roguelike de ação 2D com aparência isométrica e combate frenético, ambientado em um apocalipse urbano brasileiro com zumbis. Desenvolvido em Godot 4 e GDScript, coordenado com agentes especializados no OpenCode. Alvo inicial: PC, single-player offline, teclado/mouse e controle.

O usuário escolheu a direção “Último Sol”: cidade evacuada, feiras, mercados, viadutos, vegetação invadindo concreto, arte estilizada e contraste entre luz quente e sombras azuladas. Hades é referência de qualidade de resposta, ritmo e impacto; não de personagens, narrativa, composição visual ou conteúdo a copiar.

O projeto também deve ensinar desenvolvimento de jogos, arquitetura e orquestração de agentes. Explicar decisões relevantes, suas alternativas e consequências faz parte de cada entrega.

## 2. Pilares e como avaliar
1. **Resposta imediata:** intenção de movimento e ataque reconhecível, sem travamentos involuntários. Avaliar em arena de teste com ambos os dispositivos.
2. **Caos legível:** antecipação, área de perigo e resultado dos golpes compreensíveis mesmo com vários inimigos. Avaliar vídeo em velocidade normal, sem depender de câmera lenta.
3. **Impacto expressivo:** animação, áudio, reação e efeitos concordam com o dano real. Testar também com tremor e flashes reduzidos.
4. **Brasil como lugar, não adereço:** arquitetura, materiais, sinalização e objetos sustentam a ambientação, sem caricatura ou uso de marcas reais.
5. **Aprendizado por tentativa:** morrer deve permitir entender o erro e recomeçar rapidamente; escolhas mudam a forma de enfrentar o próximo encontro.

Os pilares são critérios de direção propostos, não prova de qualidade já alcançada.

## 3. Recorte recomendado para o vertical slice — pendente
Uma incursão de aproximadamente 8–12 minutos, com início, três encontros curtos, escolhas entre encontros, confronto final e tela de resultado. Um sobrevivente jogável, uma arma corpo a corpo improvisada, esquiva, três arquétipos comuns e um inimigo de confronto final. Três melhorias locais à tentativa, sem árvore permanente.

É uma hipótese de escopo, não uma promessa de conteúdo nem mecânica aprovada. Antes da sprint afetada, o usuário confirma arma, ações, duração e quantidade de conteúdo. A qualidade de uma arena precede a multiplicação de arenas.

Loop proposto: entrar no trecho urbano, ler ameaças, lutar e reposicionar, escolher melhoria, enfrentar novo encontro, vencer ou morrer, consultar resultado e reiniciar. Salas inicialmente autorais; variar combinações e escolhas é suficiente para experimentar estrutura roguelike sem gerador procedural.

## 4. Hipóteses de combate a experimentar
- Movimento livre no chão, mira por mouse ou analógico; regra de mira neutra explicitada antes do código.
- Ataque com preparação, janela ativa e recuperação; cancelamento e eventual invulnerabilidade exigem aprovação, não são pressupostos.
- Esquiva como ferramenta de posicionamento; duração, cargas e custo serão parâmetros de experimento.
- Inimigos contrastantes: perseguidor, atacante com preparação longa e ameaça de distância/área. Não produzir os três antes de validar o primeiro.
- Impacto visual e sonoro não pode alterar regra de dano por acidente. Assistência de mira é alternativa a testar, não decisão fechada.

Sem multiplayer, mundo aberto, crafting, inventário complexo, classes, geração procedural irrestrita, metaprogressão extensa ou história ramificada no slice. Não há salto/andares sobrepostos no recorte técnico recomendado.

## 5. Experiência, interface e acessibilidade
HUD mínimo: vida, disponibilidade das ações e estado do encontro quando necessário. Pausa, reinício e menus operáveis por teclado e controle, com foco visível. Instruções acompanham dispositivo ativo, sem alternância por ruído do analógico.

Propostas: remapeamento antes do slice final, ajuste de volume, redução de tremor e flashes, perigos distinguíveis por forma além de cor e texto legível em 1080p. Desconexão de controle não pode prender o jogador sem acesso à pausa. Recursos precisam de teste manual, não só de existência no menu.

## 6. Participação e decisões abertas
Antes de S0: aprovar este pacote, nome de trabalho/diretório, sistema operacional de teste e hardware disponível. Definir ou adiar explicitamente orçamento/fonte de assets, permitindo blockout com placeholders; aquisição ou produção dependente desses recursos exige aprovação antes de começar. Recomenda-se começar em Windows; “PC” não significa suporte já aprovado a todos os sistemas.

Antes de S1/S2: aprovar câmera experimental, arma inicial, ações e sensação desejada de combate. Antes da amostra artística: aprovar tratamento de violência, proporções e técnica de animação. Antes de S4: confirmar duração e loop da tentativa. Decisões fundamentais continuam com o usuário; propostas técnicas reversíveis não autorizam mudar gameplay ou arte.

## 7. Aprendizado em cada sprint
Entrega inclui breve explicação de um conceito aplicado, uma alternativa descartada e um exercício manual reproduzível. Exemplos: coordenadas e vetores em S1, estados e composição em S2, comportamento e telegráficos em S3, ciclo de vida em S4 e perfil de desempenho em S7. Não criar um framework apenas para ensinar um padrão.

## 8. S1 — recorte aprovado em 2026-10-28
Após integrar o PR1, o usuário aprovou a tarefa/branch `S1-movimento` a partir da main atualizada: personagem provisório em arena com obstáculos, movimento por WASD/setas e analógico esquerdo, mira por mouse/analógico direito preservando última direção válida, câmera seguindo sem rotação, colisões, origem nos pés e leitura de profundidade. Sem combate, esquiva, inimigos, assets finais ou novas dependências.

### Experiência do laboratório
Arena temporária com área livre, limites, bloco baixo, prop alto contornável e uma passagem. Personagem e objetos usam formas simples e perspectiva aparente, não arte final. Um anel/ponto nos pés e marcador direcional distinguem posição física, orientação e deslocamento. Rótulo visível: “S1 · Blockout temporário — movimento e mira”. HUD informa controles, fonte efetiva da mira, perda de foco e desconexão, sem sugerir ataques disponíveis.

Mira e movimento independentes: poder andar numa direção e mirar em outra. Cursor parado não toma a mira do controle quando a câmera se move; ruído dos analógicos não troca instruções. Mouse nos pés ou analógico neutro não apaga a última direção válida. Perda de foco para o movimento e exige nova intenção após retorno; desconectar controle não impede recuperação por teclado/mouse.

### Escolhas técnicas iniciais reversíveis, não balanceamento final
Escolhas iniciais do Tech Lead conferidas pelo usuário no plano S1 para validação no laboratório: velocidade240 unidades/s, direção inicial à direita, deadzone radial0,2 aplicada uma vez, câmera com zoom1 e sem suavização/drag/rotação. Arena1600×1000, início(800,500), colisor de raio10 e passagem mínima60. Valores existem para testes/ajuste, não são métricas de desempenho ou decisão sobre combate. Implementação do detalhamento autorizada; alterações fundamentais continuam sujeitas à aprovação humana.

Teclado com tecla de movimento pressionada prevalece sobre analógico esquerdo, inclusive quando opostos se cancelam. Mira troca pela última atividade significativa; mouse vence empate no mesmo tick. Deslocamento acumulado de mouse de2 pixels lógicos e mudança de analógico de0,05 são limiares iniciais, ajustáveis sem mudar os pilares. Controle ativo é um dispositivo por vez, selecionado por intenção, não soma de todos os controles conectados.

### Aceite e participação
Testes automatizados cobrem intenção, coordenadas, física, foco/desconexão e empacotamento; capturas/vídeos assistidos demonstram o laboratório. Vídeo simulado não substitui teste manual com controle físico. Usuário executa o roteiro de teclado/mouse e controle quando disponível e relata sensação de movimento; indisponibilidade de controle físico mantém esse critério não verificado, sem impedir implementar/testar o restante. S1 só é aceita com critérios pertinentes atendidos e sem início automático da S2.

Aceite em 2026-10-29: usuário conectou controle físico e confirmou todos os blocos assistidos de movimento/mira, colisões/profundidade e foco/desconexão/teclado/reconexão. Autorizou explicitamente usar suas confirmações dessa sessão no lugar do vídeo originalmente previsto. Evidência é relato humano, não filmagem nem observação física pelo agente; S1 aceita sobre a entrega integrada no PR2. Essa exceção não afirma existência de vídeo e não autoriza alterar critérios de outras sprints silenciosamente.

## 9. S2 — cassetete e esquiva: recorte e detalhamento
**Confirmado pelo usuário:** referência de resposta, ritmo e impacto de Hades, com identidade própria; cassetete policial no lugar do facão e esquiva antes de fuzil. Fuzil é incremento posterior, não entrega S2. Não foi decidido que o sobrevivente seja policial ou use uniforme. Arte final continua na S5; S2 utiliza silhueta, animação, efeitos e som provisórios necessários para validar legibilidade e resposta.

**Gate concluído:** usuário conferiu o plano completo e respondeu “sim, aprovado”, autorizando a implementação por agentes com revisão por tarefa. Valores e regras abaixo são o detalhamento conferido, com parâmetros iniciais reversíveis para validação no laboratório; mudanças fundamentais continuam exigindo aprovação. O plano detalha esta especificação, não é outro GDD.

### Golpe e sensação proposta
Um golpe por nova pressão: botão esquerdo do mouse ou botão oeste do controle (X/Quadrado). Sem repetição automática ao segurar, combo, ataque especial, projétil ou buffer de comando nesta primeira versão. Movimento conserva intensidade e velocidade S1 durante o golpe, sem avanço automático. Mira continua independente, mas a direção do golpe é fixada quando ele começa.

Preparação de 0,05 s, janela ativa de 0,08 s e recuperação de 0,14 s: total inicial de 0,27 s, hipótese reversível, não diversão medida. Alcance máximo de contato de 60 unidades desde os pés e setor frontal de 90 graus. Desenho e detecção compartilham o mesmo polígono convexo aproximando o setor; alvo pode ser atingido por contato de sua base com esse setor, não por posição da cabeça. Linha física contra cenário impede contato através de parede. Um golpe pode atingir mais de um alvo, mas nunca causar dano duas vezes ao mesmo receptor, mesmo com várias shapes ou múltiplos ticks. Tentativa rejeitada por invulnerabilidade também consome o contato daquele golpe; o próximo golpe usa outra identidade.

### Esquiva proposta
Espaço ou botão sul do controle (A/Cruz): 0,15 s a 800 unidades/s, distância livre nominal de 120 unidades; paredes/obstáculos podem reduzir essa distância. Direção de movimento atual; em repouso, última mira válida. Uma carga, recarga de 0,60 s depois do fim. Invulnerabilidade nos primeiros 0,10 s, indicada por contorno duplo que termina junto da proteção; rastro curto não significa proteção.

Esquiva permitida em repouso ou recuperação, cancelando somente a recuperação; não cancela preparação/janela ativa. Entre solicitações simultâneas em estado elegível, esquiva tem precedência; ataque durante esquiva é descartado, sem ficar enfileirado. Não há sequência de esquivas, stamina ou upgrade. Tempos e alcance são parâmetros iniciais; elegibilidade e cancelamento são regras a conferir antes do código.

### Vida e laboratório
Jogador com 100 de vida, três alvos estacionários com 30 cada, cassetete causa 10 por golpe aceito. Vida nunca fica negativa; morte emite um evento uma única vez. Morto ou gameplay suspenso não recebe novos comandos/danos. Não há empurrão, IA, inimigos perseguidores ou conclusão de encontro S3.

Uma zona retangular de treino de 120×80 unidades, fora do nascimento, permite experimentar dano e invulnerabilidade sem IA: ciclo de 1 s, com aviso de 0,35 s, ativo por 0,10 s e repouso de 0,55 s; dano 25, no máximo uma tentativa por jogador por pulso. Forma e texto distinguem aviso/ativo, não apenas cor; sobreposição física usa a mesma área desenhada no chão. Entrar andando demonstra dano; atravessar sincronizando esquiva demonstra proteção. Reinício restaura jogador, alvos, zona, custos e estados recriando o laboratório.

Amostragem técnica proposta: corpo se move primeiro; contato, proteção e contorno usam o instante final do passo físico. Não é detecção contínua de todo trajeto. Se um passo atravessar a janela ativa inteira, ela ainda produz uma consulta; se atravessar vários pulsos, somente o mais recente é considerado, sem rajada de dano atrasado. Tempos de proteção não se estendem por um tick extra de arredondamento. Interromper uma esquiva não devolve seu período total de indisponibilidade de0,75s já assumido.

### Pausa, foco e recuperação
Escape ou Start abre pausa; controle/teclado/mouse operam Continuar e Reiniciar com foco visível. Pausa manual congela relógios e fase corrente; não aceita ataques novos nem acumula comandos. Retomar exige soltura/nova pressão e neutralização de analógicos. Reiniciar descarta a tentativa atual; durante tentativa viva há confirmação, após morte o botão reinicia diretamente.

Perda de foco ou desconexão do controle ativo interrompe golpe/esquiva, limpa solicitações e abre pausa com motivo. Proteção interrompida termina imediatamente; recarga já assumida não é devolvida. Teclado/mouse continuam acessíveis para continuar/reiniciar. Relógio da zona também para durante a pausa, evitando dano em segundo plano. Inicialização sem foco mantém entrada bloqueada; testes devem preparar foco/pausa explicitamente e restaurar SceneTree ao terminar.

### Feedback e aceite
Cassetete recua, setor ativo aparece somente durante dano e retorno comunica recuperação. Acerto combina reação breve do alvo, redução de vida e som seco; erro usa som leve. Sons sintetizados localmente, sem assets externos, e volume conservador. Sem hit-stop global, tremor de câmera, flashes de tela ou gore nesta proposta. Sem som, acerto/dano/esquiva continuam compreensíveis.

HUD compacto mostra vida, esquiva pronta/recarga e instruções, sem cobrir a prova espacial S1. Capturas nativas 1280×720 e 1920×1080 mostram preparação/ativo/recuperação, alvo atingido/morto, esquiva/proteção, pausa e reinício. Testes de regra e física precedem ajuste de sensação. Usuário executa roteiro real em teclado/mouse e controle, relata resposta/impacto/legibilidade e aprova ou pede ajuste delimitado; simulação ou captura automatizada não substitui esse aceite. S3 só começa com autorização explícita.

## 10. S3 — primeiro encontro aprovado em 2026-11-04
Usuário aprovou um perseguidor corpo a corpo e um encontro com três inimigos, sem expandir arquétipos, arsenal, progressão ou arte final. A intenção é reconhecer preparação, evitar o golpe e finalizar/reiniciar com segurança. Regras, parâmetros aprovados, carga de ensaio e tarefas estão no detalhamento S3 de `ROADMAP.md`, fonte única desses valores. Combate e laboratório S2 são preservados. A aprovação autoriza implementação com agentes/revisão por unidade; controle físico S2/S3 continua pendente para quando o usuário tiver o dispositivo, sem aceite final, tag ou merge automático implícitos.
