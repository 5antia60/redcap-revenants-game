# Roadmap e gates de qualidade

Estado em 2026-11-04: S0/S1 integradas e S1 aceita. S2 e correção de dano integradas na main `9ab4e1d9fcb7f6ddaed2c409a1d0c0a4bc9fdb2d`; aceite dirigido em teclado/mouse e validação integrada registrados, controle físico S2 ainda pendente. Usuário adiou explicitamente esse teste e depois aprovou plano e implementação S3 com agentes/revisão por unidade, mantendo controle físico pendente. Somente S3 no recorte abaixo está autorizada; S4–S7 não. Histórico S2 no [plano de combate](superpowers/plans/2026-10-29-s2-combate.md); execução S3 nos artefatos locais `.tools/s3/`, sem plano concorrente.

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

Resultado S1: usuário confirmou todos os cenários assistidos com controle físico e teclado/mouse e autorizou explicitamente substituir o vídeo por suas confirmações dessa sessão. Critério de evidência ajustado por decisão humana, não por inferência do coordenador; nenhum vídeo ou observação física independente foi declarado. S1 aceita; três melhorias baixas de ferramentas/export continuam registradas no plano, sem bloqueador crítico/alto aberto.

### S2 — Núcleo do combate
Progresso técnico: [PR3 da S2 integrado pelo usuário](https://github.com/5antia60/redcap-revenants-game/pull/3), main `df4077015cacb39b453aa3e7c8e62d705c3f0e61` validada1345/0/negativa esperada/positiva1345/0. Aceite humano confirmou comandos e recuperação em teclado/mouse, mas revelou dano recebido pouco claro sem áudio. Correção autorizada `S2-feedback-dano`: ordenação da zona e reação/número locais, fonte1408/0 e código/UX revalidados; novos exports17entradas/0falhas, staging120frames/exit0 e versão0.1.0 observada nas duas builds. Revisão integrada final favorável e [PR4 aberto para main](https://github.com/5antia60/redcap-revenants-game/pull/4); reteste visual sem áudio, integração e controle físico adiado continuam pendentes. Não autoriza S3 ou tag pronta; arte final permanece S5. Evidências e hashes no plano S2/contexto.

Dependências: S1 aceito e autorização S2; arma, ataque, esquiva/cancelamento e regras de dano aprovados.

Entrega: uma ação de ataque, esquiva se aprovada, alvo de treino, vida/morte e feedback mínimo. Sem arsenal ou framework de habilidades.

Aceite: alcance e janela ativa correspondem ao que se vê; mesmo golpe não duplica dano no mesmo alvo; alvo removido não causa erro; morte só ocorre uma vez; morto/pausado não ataca; reinício limpa estado. Testes cobrem esses casos e os positivos. Usuário experimenta ação em ambos os dispositivos e aceita resposta, impacto e legibilidade; desacordo mantém sprint aberta para ajuste delimitado.

### S3 — Primeiro encontro e linguagem inimiga
Dependências: S2 aceito e autorização S3; primeiro arquétipo e carga-alvo de ensaio definidos.

Progresso técnico em2026-11-09: U1 revisada/commitada em6e56ddb; U2 candidata0.2.0 revalidada após duas rodadas corretivas e registrada em8267123. Revisão integrada favorável, entrega enviada somente à branch própria/main inalterada; [PR5 aberto/conferido](https://github.com/5antia60/redcap-revenants-game/pull/5), sem merge automático. Coordenador confirmou1731/0, executou nova carga3/12 por60s da fonte corrigida, exports reais Debug/Release17entradas/0falhas e staging somente EXE/PCK120frames/exit0; versão exata observada nas próprias builds. Evidências em `.tools/s3/unit2-review-findings.md` e contexto. Sem aceite final S3. Controle físico e relato humano de resposta/impacto/leitura em velocidade normal pendentes; baixa de rótulos aberta, legibilidade12 não aprovada e meta S7 não comprovada.

Exceção explícita em 2026-11-04: usuário adiou controle físico S2, avisará quando disponível e autorizou seguir com implementação S3 após aprovar o plano. Não é dispensa de testes físicos, aceite global S2/S3, tag ou publicação. A exceção permite desenvolver o recorte abaixo sem repetir aceites de teclado/mouse já válidos.

Entrega: um inimigo completo e encontro pequeno; depois, até dois arquétipos contrastantes se o escopo do slice for confirmado. Estados, preparação, perseguição, ataque e morte claros.

Aceite: cada inimigo anuncia ataque de modo distinguível; pode ser atingido/evitado conforme regras; não ataca morto, fora da janela ou após encerramento; arena não conclui com inimigos ativos e conclui após último válido. Testes de estados/ciclo passam. Cenário de múltiplos inimigos registra CPU/memória e leitura manual, sem afirmar meta gráfica final. Fixar carga representativa e critério de estresse para S7.

#### Plano S3 aprovado — 2026-11-04
> Execução por `implementacao` em sessão nova por unidade, com `subagent-driven-development`, revisão independente de aderência e qualidade antes da próxima e revisão integrada final. Somente coordenador escreve Git e artefatos de coordenação. Checkboxes indicam resultados comprovados, não intenção.

**Objetivo:** um perseguidor corpo a corpo completo e um encontro com três inimigos, permitindo reconhecer preparação, evitar dano e finalizar/reiniciar com segurança.

**Base:** tarefa/branch `S3-primeiro-encontro`, origem main `9ab4e1d9fcb7f6ddaed2c409a1d0c0a4bc9fdb2d`, destino PR main, origin `https://github.com/5antia60/redcap-revenants-game.git`. Branch criada pelo coordenador após checkout/índice limpos e ausência local/remota; prova `.tools/s3/branch-creation.json`. Checkout exclusivo confirmado pelo usuário; execução serial na branch própria, sem criar worktree adicional, instalar dependências ou copiar ferramentas/evidências.

**Fontes:** GDD seções1–7/9, ART_BIBLE, ARCHITECTURE seções8/9 e especificação S3 imediatamente abaixo. Este detalhamento é a única fonte de tarefas S3; briefs apenas apontam suas seções e delimitam escrita. Evidências e progresso em `.tools/s3/`, estado vigente no contexto.

**Restrições globais:** Godot4.7.2/GDScript/Compatibility e viewport1280×720 preservados. Sem novos arquétipos, arsenal, progressão, Run/S4, navegação complexa, frameworks, rede, persistência, plugins, assets externos ou arte final. Sem mudar cassetete/esquiva/entrada/dano/proteção do jogador S2. Laboratório S2 permanece disponível para regressões. Pausa e foco devem continuar seguros. Fontes, cenas, UIDs e configuração têm um escritor por vez. Nunca sobrescrever artefatos históricos. Sem merge automático, tag antecipada ou publicação de build.

**Especificação aprovada do inimigo:** vida30, velocidade120 unidades/s, dano10; inicia preparação quando distância entre pés for no máximo60. Preparação0,60s, ativo0,10s, recuperação0,80s; setor frontal90graus de alcance60. Para ao preparar e fixa direção até o fim da recuperação. Move somente em perseguição direta com colisão, sem promessa de contornar obstáculos. Dano não letal não interrompe ataque; morte cancela imediatamente. Sem dano por contato ou empurrão. Uma tentativa por jogador por serial, inclusive quando recusada por esquiva. Ataques de inimigos distintos podem acumular dano; não adicionar iframe ao jogador. Preparação, ativo e recuperação são distinguíveis por postura/forma, não apenas cor ou áudio; formas temporárias, sem flash/tremor/gore.

**Escolhas técnicas reversíveis do coordenador:** corpo com origem nos pés/raio10, camada4 (receptor S2), máscara3 (cenário e jogador), sem colisão entre inimigos nesta primeira arena. Cadáver perde colisão e elegibilidade imediatamente. Jogador processa antes dos inimigos; cada inimigo move e resolve depois, preservando amostragem sequencial existente, não simultaneidade final de todos os atores. Consulta contra jogador usa shapes/transforms atuais, evitando broadphase antiga; cenário bloqueia linha entre pés. Empate letal segue essa ordem causal, sem dano retroativo de atacante morto. Não alterar resolver S2 para servir a dois atacantes por generalização preventiva.

**Suspensão e ciclo:** pausa manual congela fase/relógio. Foco perdido/desconexão interrompem preparação/golpe de todos antes da pausa; retorno exige nova preparação completa, sem ataque residual. Morte do jogador marca derrota e bloqueia ataques sincronamente. Registro explícito de inimigos termina antes de avaliar contagem; somente morte válida remove um ID, uma vez. Última morte válida conclui uma vez; remoção inesperada/configuração inválida é falha segura, nunca vitória. Encerramento impede dano/comandos de combate posteriores e mantém menu/reinício. Reinício desabilita arena antiga, desconecta sinais e recria estado, impedindo callbacks antigos.

**Foco de revisão e testes correspondentes:** entrada/saída da área no mesmo passo (U1); janela atravessada e delta inválido (U1); morte/remoção/reentrância no callback (U1/U2); empate derrota/conclusão e evento duplicado (U2); foco com botão retido e três reinícios (U2). Testes devem exercitar produção e retornar conclusão explícita; sem asserts removíveis ou tolerância ampliada para esconder ticks extras.

##### Unidade 1 — Inimigo completo isolado
**Arquivos exclusivos previstos:** criar `src/enemies/melee_chaser.gd`, `melee_chaser.tscn`, `melee_chaser_state.gd` e respectivos UIDs; criar `tests/unit/test_melee_chaser_state.gd`, `tests/integration/test_melee_chaser.gd` e UIDs; integrar módulos em `tests/run_tests.gd`. Harness de prova isolada `tests/capture_melee_chaser.gd` e UID somente se necessário para feedback antecipado. Não alterar Main, jogador, laboratório, export ou docs nesta unidade.

**Interfaces produzidas:** corpo `melee_chaser.gd` expõe `health` por instância, sinal `died` sem argumentos, `set_target(value: CharacterBody2D) -> bool`, `receive_hit(amount: int) -> bool`, `set_encounter_enabled(value: bool) -> void`, `interrupt_actions() -> void`. Inicializa desabilitado até alvo válido e habilitação explícita; retorno inválido não conserva alvo antigo atacável. `interrupt_actions` cancela ação e volta a perseguir quando elegível; desabilitação bloqueia movimento/dano e cancela ação. Política local `melee_chaser_state.gd` não conhece Input/SceneTree; interface interna pode ser decidida pelo implementador, documentada no relatório antes do handoff. Configuração por instância, sem autoload/class_name global preventivo.

**Consome:** `Health` e contrato `Player.receive_hit(amount: int) -> bool`, sem chamar `player.health.apply_damage`. Inimigo recebe cassetete pelo contrato já existente na camada4; não muda dano10/alcance60 fixados no resolver S2.

- [ ] RED de estados/tempos: perseguição, entrada em60, direção fixada, ativo somente após0,60s, recuperação e serial seguinte; zero/negativo/NaN/infinito/valor acima do limite técnico não repetem ataque. Passo grande atravessa janela com no máximo uma tentativa, sem ataques compensatórios em rajada.
- [ ] RED físico: jogador100→90 em acerto; fora do setor/alcance, parede, proteção, pausa, morto, removido ou desabilitado não recebem dano; recusa por proteção consome serial. Entrada/saída usam posição atual; múltiplos ticks não duplicam. Dano não letal não cancela preparação; três golpes de10 matam inimigo30 uma única vez. Callback que mata/desabilita/remove invalida continuidade sem erro.
- [ ] Implementar política/corpo/cena mínimos e apresentação local das três fases. Reusar Health, sem duplicar regras do jogador. Testes físicos usam callbacks nativos e orçamento finito; não chamar `_physics_process` para fingir integração.
- [ ] GREEN, negativa deliberada do runner e positiva final; import/parse pertinentes. Comandos da raiz: `powershell -NoProfile -File .\scripts\test.ps1`, o mesmo com `-SelfTestFailure` (esperado1), positiva novamente, `powershell -NoProfile -File .\scripts\import.ps1` (esperado0). Guardar logs UTF8, retornos, lista/hashes dos arquivos e relatório `.tools/s3/unit1-report.md`.
- [ ] Prova antecipada de um inimigo em720/1080 por harness isolado, sem mudar cena principal. Capturas e roteiro permitem verificar aviso/área/resultado sem som; observação humana não é inferida de testes. Não aguardar novo aceite entre unidades salvo falha ou mudança fundamental.
- [ ] Congelar diff completo incluindo novos arquivos, revisão independente de aderência/qualidade e revisão visual proporcional. Coordenador confirma resultados recentes e registra commit da unidade antes de U2.

##### Unidade 2 — Encontro jogável, ciclo e entrega
**Arquivos previstos:** criar `src/arenas/first_encounter.gd/.tscn` e UIDs; modificar `src/game/main.gd/.tscn`, testes de integração/runner necessários, `project.godot`, `export_presets.cfg`, auditor/driver/leitor/fixtures somente no delta explícito de fontes/metadados S3; criar teste de encontro e harness visual próprios; atualizar documentação pertinente pelo coordenador. Não modificar arquivos fechados U1 sem registrar motivo e invalidar/revalidar parecer afetado.

**Consome:** cena e seis interfaces públicas U1 descritas acima; referências explícitas a jogador/adaptador, sem interface universal de arenas. **Produz:** arena com estados em curso/concluído/derrota/falha; sinal de resultado único e ligação explícita à Main. Métodos e caminhos exatos serão fixados no brief U2 após handoff U1; é decisão interna, não mudança do produto aprovado.

- [ ] RED do encontro: três IDs ativos impedem conclusão; mortes válidas3→2→1→0 concluem uma vez. Morte duplicada, nó inesperadamente removido, callbacks de arena velha, derrota ou registro incompleto não concluem. Três reinícios restauram jogador100/inimigos30/contagem3/relógios/entrada, sem sinais duplicados.
- [ ] Implementar arena própria de combate com área livre de nascimento, inimigos visíveis e sem zona de dano/alvos S2 contando como inimigos. Reaproveitar composição espacial e pausa existentes, preservar laboratório S2 para regressão. HUD compacto exibe restante/resultado sem encobrir avisos; menu mantém foco e reinício seguro.
- [ ] Testar pausa/foco/desconexão em todas as fases, retomada sem botão retido, zero dano após resultado e cancelamento de reinício. Adaptar testes dependentes da Main sem apagar cenários S2 ou substituir suas asserções por checks triviais.
- [ ] Revisar antes do código da fronteira de export o conjunto canônico exato de fontes/UIDs e metadados, com segurança. Atualizar inventário explicitamente, manifesto de fontes revisadas antes do export, leitura offline/atestado/auditoria antes de ResourceLoader. Negativos: fonte ausente, extra/alterada, UID desconhecido, metadado inválido; nunca aceitar inventário recebido como autorização. Riscos baixos herdados de atomicidade/reparse/watchdog permanecem registrados, não resolvidos por pressuposto.
- [ ] Versão de desenvolvimento0.2.0-dev; candidato0.2.0 somente na preparação validada. Sem tag pronta até aceite pertinente, integração real e validação da main. Preservar candidato/export S2 e evidências existentes.
- [ ] GREEN e regressões pertinentes: suíte fonte/negativa/positiva, import, wrappers63checks, fixtures de coleta/empacotamento afetadas. Wrappers têm histórico de transporte incompleto: uma execução com resumo e exit persistidos; falha de transporte não equivale a falha de produto nem sucesso. Sem retry sem hipótese e mudança verificáveis.
- [ ] Medir carga normal3 e ensaio12 por60s em1080p, com ferramentas locais existentes; registrar máquina/build/configuração, CPU/tempo de frame e memória disponíveis, picos e limitações. Carga12 é ensaio, não promessa de encounter final ou meta60FPS comprovada. Critério: processo/ciclo íntegros e medidas completas, sem crash/softlock; suspeita de crescimento persistente exige investigação. Sem criar coletor/dashboard de tokens ou instalar profiler.
- [ ] Capturas720/1080 e revisão UX de avisos sem áudio, oclusão, pausa, vitória/derrota/reinício; execução humana com teclado/mouse e controle quando disponível. Pendência física não se converte em aceite. Export Debug/Release em destinos novos, auditoria e staging somente EXE/PCK com versão exata observada nas próprias builds.
- [ ] Revisão independente da unidade e integrada final na base congelada, reutilizando pareceres válidos e revalidando deltas/contratos afetados. Verificações recentes obrigatórias, controles Git de índice/objetos/segredos e commit pelo coordenador; push somente da branch comprovadamente própria e PR para main, sem merge/tag/publicação de build.

**Execução, limites e evidências:** um implementador por unidade, solicitado Solhigh por física/ciclo/integridade multiarquivo; revisor por risco, seleção registrada em cada chamada, final high ou max justificado. Custos/tokens não disponibilizados ficam desconhecidos; registrar coordenador e filhos, fonte da medição, correções, bloqueios e aceite em `.tools/s3/progress.md` e contexto por marcos. Até duas rodadas corretivas agrupadas por unidade inicialmente; persistindo bloqueio, parar para diagnóstico/decisão, sem aceitar risco alto ou trocar modelo silenciosamente. Falha de transporte permite nova tentativa somente com hipótese, mudança e saída verificáveis, sem duplicar processo ativo. Sem nova infraestrutura de métricas ou alegação de economia sem comparação.

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
