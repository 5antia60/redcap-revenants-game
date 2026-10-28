# Roadmap e gates de qualidade

Estado: S0 integrada pelo usuário no PR1 e aceita como base para avançar; resultado integrado verificado no merge `0d6b21baf8284a757a1666784bf357f7c604233c` com Godot146/0 e wrappers63/0. S1-movimento autorizada em planejamento; S2–S7 não autorizadas. Evidências S0 em [plano da fundação](superpowers/plans/2026-10-27-s0-fundacao.md); detalhamento S1 em [plano de movimento](superpowers/plans/2026-10-28-s1-movimento.md).

Continuação S0 entregue: exports locais Debug/Release, auditoria dos PCK, execução sem editor/fonte em staging e captura de janela1920×1080 verificados. PR1 criado/conferido após login e depois integrado pelo usuário; bloqueios de autenticação documentados anteriormente são históricos resolvidos. Não atualizar engine/templates nem repetir exports S0 por rotina.

## 1. Regras de condução
Antes de cada sprint: conferir última evidência, dependências, versão da engine, decisões humanas e disponibilidade de assets; detalhar tarefas coesas, arquivos exclusivos, executor, cenários positivos/negativos e comandos. Registrar o detalhamento nesta fonte, sem plano paralelo concorrente. Estimativa em tempo só após conhecer disponibilidade do usuário e velocidade observada.

Uma sprint termina somente com todos os critérios pertinentes atendidos, testes recentes, demonstração manual e revisão independente sobre base congelada. Se faltar evidência ou houver defeito crítico/alto, continua pendente/bloqueada. Não mudar um critério para converter falha em sucesso. Roadmap recebe progresso somente por evidência identificável. Depois do aceite, aguardar aprovação humana da próxima sprint.

## 2. Sprints incrementais
### S0 — Fundação verificável
Dependências: aprovação explícita de S0; nome de trabalho, Windows ou outro SO inicial, hardware e fonte/orçamento de assets definidos ou explicitamente adiados sem bloquear blockout.

Entrega: projeto Godot mínimo, versão exata fixada, diretório/ignore corretos, cena de teste vazia, ações de entrada declaradas, runner mínimo e instruções reproduzíveis. Sem gameplay. Verificar qual OpenCode realmente atende a sessão: o CLI local relatado como V1 não comprova suporte à configuração V2; não atualizar automaticamente. Git só pelo coordenador, após inspeção de ancestral, identidade e escopo.

Aceite: projeto abre na versão registrada; importação e runner retornam sucesso; teste propositalmente falho retorna erro e depois é removido/corrigido com nova execução; cena abre manualmente sem erros; comandos documentados funcionam em checkout limpo quando disponível. Registrar templates/export disponíveis e comando exato de build, ou bloqueio explícito. Identificar máquina, renderizador candidato e ferramentas de diagnóstico. Nenhuma dependência instalada sem aprovação pertinente.

### S1 — Movimento, mira e prova espacial
Dependências: S0 aceito e autorização S1; regras de mira e câmera experimental acordadas.

Entrega: personagem placeholder em uma arena, movimento, colisões, câmera e leitura de profundidade. Arena é laboratório manual reutilizável.

Aceite: movimento e mira funcionam nos dois dispositivos; diagonal não aumenta velocidade; vetor zero não gera direção inválida; foco/desconexão permitem recuperar controle; obstáculos não aprisionam jogador; origem nos pés e ordenação atrás/à frente de um prop alto demonstradas. Testes automatizados de entrada/transformações e integração pertinente passam; vídeo manual por dispositivo mostra o fluxo.

### S2 — Núcleo do combate
Dependências: S1 aceito e autorização S2; arma, ataque, esquiva/cancelamento e regras de dano aprovados.

Entrega: uma ação de ataque, esquiva se aprovada, alvo de treino, vida/morte e feedback mínimo. Sem arsenal ou framework de habilidades.

Aceite: alcance e janela ativa correspondem ao que se vê; mesmo golpe não duplica dano no mesmo alvo; alvo removido não causa erro; morte só ocorre uma vez; morto/pausado não ataca; reinício limpa estado. Testes cobrem esses casos e os positivos. Usuário experimenta ação em ambos os dispositivos e aceita resposta, impacto e legibilidade; desacordo mantém sprint aberta para ajuste delimitado.

### S3 — Primeiro encontro e linguagem inimiga
Dependências: S2 aceito e autorização S3; primeiro arquétipo e carga-alvo de ensaio definidos.

Entrega: um inimigo completo e encontro pequeno; depois, até dois arquétipos contrastantes se o escopo do slice for confirmado. Estados, preparação, perseguição, ataque e morte claros.

Aceite: cada inimigo anuncia ataque de modo distinguível; pode ser atingido/evitado conforme regras; não ataca morto, fora da janela ou após encerramento; arena não conclui com inimigos ativos e conclui após último válido. Testes de estados/ciclo passam. Cenário de múltiplos inimigos registra CPU/memória e leitura manual, sem afirmar meta gráfica final. Fixar carga representativa e critério de estresse para S7.

### S4 — Tentativa curta completa
Dependências: S3 aceito e autorização S4; duração, quantidade de encontros e melhorias aprovadas.

Entrega proposta: sequência autoral, escolhas locais, vitória/morte, resultado e reinício. Variação reproduzível por semente de seleção quando houver aleatoriedade; não determinismo completo de física.

Aceite: início até resultado jogável; escolhas têm efeitos verificáveis e não vazam para nova tentativa; melhoria indisponível/configuração inválida falha de modo seguro; três reinícios consecutivos não duplicam entidades/sinais; semente registra seleção reproduzível. Testes do loop passam, usuário completa uma vitória e uma derrota. Sem obrigação de save de progresso.

### S5 — Amostra artística integrada
Dependências: S4 aceito e autorização S5; técnica visual, gore, licença e lote mínimo aprovados. Estudo conceitual pode ocorrer antes, mas produção/integração não pula gates.

Entrega: uma arena representativa com sobrevivente, zumbi, obstáculo, chão, VFX e áudio coerentes; lista de substituições de placeholders.

Aceite: amostra aprovada pelo usuário; origem/licenças rastreáveis; import limpo; pivôs e colisões preservados; ameaças legíveis com efeitos e em modo reduzido; jogador não some atrás de cenário; vídeo e capturas 1080p e janela menor fornecidos. Regressões automatizadas de combate/loop passam. Sem aprovação artística, não expandir a produção.

### S6 — Conteúdo do vertical slice
Dependências: S5 aceito e autorização S6; quantidade final e desenho do confronto final confirmados.

Entrega proposta: três encontros e confronto final, melhorias locais acordadas, HUD, pausa e opções essenciais. Aplicar padrão da amostra, não uma direção nova.

Aceite: percurso completo com teclado/mouse e controle, vitória e derrota, transições sem softlock; confronto anuncia padrões e permite resposta; menus com foco/remapeamento e retorno seguros; redução de efeitos funciona; nenhum asset temporário essencial não declarado. Testes de regras e integração passam; duração observada registrada sem forçar 8–12 minutos se hipótese for rejeitada.

### S7 — Estabilização e aceite do slice
Dependências: S6 aceito e autorização S7; máquina, carga e critérios de sessão de teste fixados antes da medição.

Entrega: build local reproduzível, otimização justificada por profiler, correções e revisão integrada final. Distribuição pública permanece fora do escopo.

Aceite: todos os testes passam na base final; build abre fora do editor na máquina identificada; três percursos/reinícios consecutivos sem crash, softlock ou crescimento persistente inexplicado de memória; carga de S3 medida em 1080p com p95 ≤16,7 ms como meta proposta, p99/picos e CPU/GPU registrados. Resultado abaixo da meta bloqueia o aceite de desempenho até corrigir ou renegociar explicitamente com usuário, não esconder média.

Usuário aprova visual, resposta e leitura; revisão independente final sem bloqueadores críticos/altos. Defeitos restantes, evidências, limitações e instruções são entregues. Isso conclui um slice local, não o jogo comercial.

## 3. Estratégia de testes
| Camada | Cenários | Executor e evidência | Bloqueio |
| --- | --- | --- | --- |
| Unitária | Vetores, dano, elegibilidade, estados e melhorias; zeros e valores inválidos | Implementador/coordenador, comando, versão, saída e código de retorno | Falha de regra ou runner que aceita falha |
| Integração headless | Cenas, sinais, física pertinente, encontro e reinício | Implementador/coordenador, logs e testes sobre base identificada | Crash, referências inválidas, regressão |
| Manual no jogo | Mira, impacto, oclusão, UI, foco, pausa, ambos os dispositivos | Coordenador/usuário, roteiro e vídeo/capturas | Comportamento essencial quebrado ou aceite de gameplay ausente |
| Visual/acessibilidade | Silhuetas, contraste, janela menor, efeitos reduzidos e foco | Experiência analisa evidência; usuário aprova direção | Perigo ilegível, ação inacessível ou arte não aprovada |
| Desempenho/export | Build, carga fixa, frame times e memória | Coordenador/implementador executa; operação/qualidade analisam | Meta acordada não atingida ou build indisponível |

Após cada funcionalidade executar testes pertinentes e regressão existente. TDD para regras testáveis; para sensação/arte, hipótese, experimento jogável e aceite observável, sem fingir teste automatizado de diversão. Sessões curtas: observar sem instruir a solução, registrar onde o jogador erra, o que entendeu e um ajuste por hipótese. Outros participantes e compartilhamento de builds precisam de autorização.

## 4. Riscos prioritários e resposta
| Risco | Sinal precoce | Resposta e responsável |
| --- | --- | --- |
| Escopo crescer até um “Hades completo” | Mais sistemas antes de um combate aprovado | Coordenador mantém recorte; usuário aprova qualquer expansão |
| Combate funcional mas sem qualidade | Jogador não entende impacto/erro | Experiência + usuário avaliam S2; iterar antes de conteúdo |
| Perspectiva engana colisão/alcance | Golpes parecem acertar mas erram | Arquitetura/implementação validam pés e espaço em S1/S2 |
| Animação e arte excedem capacidade | Muitos estados/direções sem fonte viável | Amostra e orçamento antes de lote; usuário decide redução |
| Excesso de zumbis/VFX degrada frame | Picos crescem com carga | Profiler em S3/S7; otimizar gargalo medido |
| Input ou menus ruins no controle | Mira neutra e foco inconsistentes | Testar dispositivo desde S1, não ao fim |
| Ferramentas incompatíveis | CLI V1/config V2 ou engine divergentes | S0 verifica caminho/versão; operação orienta sem atualização automática |
| Licença ou fornecedor inviável | Asset sem proveniência/edição | Não importar; pedir alternativa e autorização |
| Falsa confiança em agentes | Revisão sem evidência ou mesmo erro compartilhado | Testes executáveis, revisão independente e validação humana |

## 5. Registro desta preparação
- Documentação autoral pelo coordenador, sem código ou execução de Godot; nenhuma sprint marcada como concluída.
- Consulta preventiva `arquitetura`: sessão `ses_e82744f63ffeuu3CV06hin9D4U`, solicitado `openai/gpt-6.1-sol#high` por dependências entre espaço, combate e arte. Referência aprovada em `vibe-c/docs/SQUAD.md`; catálogo confirmou variante. Custo desconhecido; identidade efetiva não confirmada por metadados independentes. Uma chamada, sem retry.
- Revisão independente documental e builder check: `revisao`, sessão `ses_e826d7ae5ffe6gxNUhi9eNWl2X`, solicitado `openai/gpt-6.1-sol#high` por integração entre produto, gates, arquitetura e arte, conforme política central aprovada. Custo desconhecido; efetivo não confirmado por metadados independentes. Parecer favorável de aderência e qualidade, sem achados críticos/altos/médios; um achado baixo sobre orçamento de assets antes de S0 foi confirmado pelo coordenador e corrigido no GDD. Uma chamada inicial e uma retomada da mesma tarefa/modelo para revalidação, sem retry cego. Na retomada, o revisor confirmou achado resolvido e manteve os pareceres, sem novos achados nos trechos afetados. Revisão não aprova escopo em nome do usuário.
