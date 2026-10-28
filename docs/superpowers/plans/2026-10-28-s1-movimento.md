# Plano de implementação — S1: movimento, mira e prova espacial

> **Para agentes executores:** SUB-SKILL OBRIGATÓRIA `subagent-driven-development`, com adaptações locais. Uma sessão nova de implementação por tarefa, escrita serializada, revisão independente de aderência/qualidade antes da próxima e revisão integrada final. Somente coordenador opera Git.

**Objetivo:** entregar laboratório jogável de movimento/mira, câmera, colisões e profundidade, sem combate.

**Arquitetura:** política pequena de intenção em GDScript testável com dados explícitos, corpo CharacterBody2D no chão e adaptador local de dispositivos. Cenas compostas para jogador/arena; câmera e apresentação separadas da origem física nos pés. Sem ECS, event bus, autoloads ou framework universal de input/habilidades.

**Stack:** Godot4.7.2.stable.official.ed1daf0bf padrão Windows x86_64, GDScript, Compatibility e base1280×720/canvas_items, já disponíveis.

**Especificação:** `docs/GDD.md` seção8 (recorte aprovado), `docs/ROADMAP.md` S1, contratos de coordenadas de `docs/ARCHITECTURE.md`. Este plano detalha a sprint e mantém seu ledger; não há plano concorrente.

## Restrições globais
- S1-movimento, recorte e detalhamento aprovados explicitamente pelo usuário, inclusive execução por agentes com revisão por tarefa. Não repetir descoberta de tema/stack/pilares.
- Sem combate, esquiva, inimigos, progressão, assets finais, downloads, dependências ou atualização da engine/CLI.
- Movimento livre no espaço do chão; câmera segue sem rotação. Mira neutra preserva última válida.
- Valores iniciais reversíveis são de laboratório, não balanceamento ou desempenho medido.
- Documentos/código claros em português, identificadores técnicos consistentes em inglês; arquivos snake_case. Não usar `class_name` para todos os scripts nem registrar classes globais preventivamente.
- Um escritor por arquivo; cenas, UIDs, configuração e testes também têm proprietário. Analistas não executam comandos nem editam/delegam.
- Não sobrescrever builds/capturas existentes ou limpar evidências. Sem Git/branch/commit/push pelos implementadores.
- Simulação de entrada ou gravação automatizada não é evidência de controle físico. Não encerrar S1 com critério manual pertinente ausente.

## Base Git e baseline
- Repositório autorizado: `C:/Users/sdelgado3/OneDrive - Lenovo/Documents/santiago/redcap-revenants-game`.
- Remoto fetch/push identificado: `https://github.com/5antia60/redcap-revenants-game.git`.
- PR1 confirmado pela API como merged, merge/main `0d6b21baf8284a757a1666784bf357f7c604233c`.
- Coordenador, após verificar checkout/índice limpos, operações ausentes e nome sem colisão local/remota, fez fetch somente main sem tags/força e criou `S1-movimento` desse hash. Main é base e destino de PR; só esta branch comprovadamente criada pode receber push permanente. Sem merge/auto-merge/tag ou push à main.
- Baseline real do merge: `scripts/test.ps1`146checks/0falhas e `tests/test_wrappers.ps1`63/0, códigos0, fonte inalterada. Não refazer bootstrap/downloads/exports S0 concluídos.

## Pontos de revisão e falhas a fixar por teste
1. Diagonal, analog parcial e dois dispositivos não aumentam velocidade; NaN/infinito não entram em física.
2. Cursor parado não reivindica mira ao mover câmera; zero nos pés, drift e empate preservam política.
3. Foco perdido ou controle desconectado não deixa movimento preso; retorno/reconexão não reutiliza intenção antiga.
4. Colisão e profundidade usam pés, não topo do sprite; câmera sem rotação/atraso não altera alcance/direção.
5. Novos scripts próprios entram no PCK por allowlist lógica/remaps, sem liberar fonte de testes, scripts extras ou segredos.

## Contratos do laboratório
### Intenção e tempo
- `src/player/input_state.gd`: RefCounted local, sem acesso a Input/DisplayServer/câmera/relógio. Métodos `movement(keyboard: Vector2, keyboard_active: bool, stick: Vector2) -> Vector2` e `aim(mouse_world: Vector2, feet_world: Vector2, mouse_activity: bool, stick: Vector2, stick_activity: bool) -> Vector2`. Estado de saída `aim_direction`, inicialmente Vector2.RIGHT, e `aim_source` (`mouse`/`gamepad`).
- Movimento: teclado ativo prevalece, opostos cancelam mesmo com stick ativo; vetor limitado a módulo1. Stick com deadzone radial0,2 aplicada uma única vez, remapeando intensidade restante até1; valores não finitos viram intenção neutra. Não normalizar todo analógico parcial.
- Mira: última atividade significativa vence; empate no mesmo tick favorece mouse. Mouse reivindica por deslocamento real acumulado≥2 pixels lógicos do viewport, não por transformação mundial da câmera. Stick reivindica ao sair do neutro ou mudar≥0,05 enquanto ativo, não por amostra estável. Stick esquerdo não reivindica mira. Zero/alvo coincidente mantém direção unitária anterior.
- Quando mouse é fonte, converter cursor pela câmera atual e subtrair posição dos pés; atualizar direção sem tratar câmera como atividade. Quando controle é fonte, cursor parado não interfere. Nenhum vetor inválido/zero é normalizado cegamente.
- `src/player/player.gd`: CharacterBody2D com `apply_intent(move: Vector2, aim: Vector2) -> void`. Velocidade inicial ajustável240 unidades/s, modo top-down/flutuante, atualização física e `move_and_slide` nativo sem delta duplicado. Não rotacionar corpo/colisor ao mirar; apenas indicador/apresentação.
- `src/player/player_input.gd`: adaptador Node local que coleta engine, converte mouse e entrega intenção ao corpo antes de seu tick físico. Um controle ativo por intenção deliberada; não agregar todos os IDs. Teclado/mouse sempre recuperáveis.
- Perder foco limpa movimento/velocidade e atividade pendente, preserva mira. Retorno exige soltar/repressionar teclas e neutralizar sticks antes de rearmar; primeiro evento de mouse só restabelece referência. Desconectar ativo limpa eixos/identidade. Reset repetido é idempotente, recriação da cena não duplica sinais. Essas rotinas são comportamento normal, não flags de teste na produção.

### Espaço e apresentação provisória
- Arena1600×1000, início(800,500), colisor do jogador com raio10, limites contínuos, espaço livre inicial400×300, passagem de pelo menos60. Um bloco baixo e um prop alto contornável testam circulação/oclusão. Ajustes de números devem preservar testes e ser explicados.
- Chão separado de atores. Jogador e props ordenáveis compartilham pai com Y-sort, origem no chão e z-index compatível. Arte cresce acima dos pés. Nenhum andar/salto/altura física.
- Câmera segue jogador, zoom1, sem smoothing/drag/rotação inicialmente; limites da arena. Evita atraso e variáveis adicionais antes de validar resposta básica. Suavização é alternativa posterior, não escopo obrigatório.
- Formas simples, chão areia pouco contrastado, faces quentes e sombras azuladas. Anel dos pés/marcador direcional são diagnósticos temporários; se oclusão ocultar posição, permitir pequeno marcador de diagnóstico acima do cenário, sem mascarar a ordenação do corpo. Não usar transparência para fingir Y-sort correto.
- Rótulo “S1 · Blockout temporário — movimento e mira”; instruções dos dois dispositivos, fonte efetiva da mira e estados de foco/desconexão. Sem arma/cone de ataque/HUD de vida que sugira combate implementado.

## Tarefa 1 — intenção e corpo com prova física
**Arquivos criados:** `src/player/input_state.gd`, `src/player/player.gd`, `src/player/player.tscn`, `tests/unit/test_input_state.gd`, `tests/integration/test_player_motion.gd` e UIDs pertinentes.

**Arquivo alterado:** `tests/run_tests.gd`, para chamar os novos módulos de teste no runner existente. Módulos são RefCounted com `run(tree: SceneTree, check: Callable) -> bool`, eventualmente assíncrono; retorno true somente ao concluir, verificado pelo chamador, inclusive subtestes. Não criar outro framework. Helper/wrappers/export/cena principal continuam intactos nesta unidade. A mudança void→bool decorre do achado de revisão registrado abaixo.

**Consome:** InputMap e runner S0, Godot fixado. **Produz:** métodos `movement`, `aim`, `apply_intent` acima e cena do corpo com origem nos pés/indicador, que a Tarefa2 instancia. Sem classe global para forçar dependência no pack S0 antes da migração.

- [ ] Testes RED: cardinal(1,0) e diagonal(1,1) limitam módulo1; stick0,1 zera; stick0,6 produz módulo0,5; teclado ativo/opostos vence stick; NaN/infinito neutros. Mira inicial/right, alvo nos pés, drift, empate e amostra estável preservam contrato.
- [ ] Rodar runner real e registrar falha pertinente antes dos scripts/cena implementados; não contar erro de sintaxe como RED de comportamento.
- [ ] Implementar política e corpo mínimos, com intenção explícita para integração e sem métodos/flags exclusivos de teste na produção.
- [ ] Teste físico em árvore/mundo2D real: registro de colisão, ticks limitados com watchdog, velocidade/espaço livre, bloqueio em parede, deslizamento, saída de canto e parada. Tolerâncias geométricas, sem exigir igualdade float.
- [ ] GREEN e regressão: `powershell -NoProfile -File .\scripts\test.ps1`, negativa `-SelfTestFailure` deve1 e nova positiva0; wrappers atuais devem0. Preservar os testes S0 pertinentes.
- [ ] Handoff/auto-revisão com arquivos, RED/GREEN, comandos/retornos reais e limites; revisão independente de aderência e qualidade antes da Tarefa2. Só coordenador registra commit coeso após gate.

## Tarefa 2 — laboratório jogável e pacote restrito
**Arquivos criados:** `src/player/player_input.gd`, `src/arenas/movement_lab.gd`, `src/arenas/movement_lab.tscn`, `src/game/main.tscn`, `tests/integration/test_movement_lab.gd`, `tests/capture_movement_lab.gd`, `tests/test_export_audit.ps1`, `tests/fixtures/build_pack_cases.gd` e UIDs pertinentes.

**Arquivos alterados:** `project.godot`, `export_presets.cfg`, `tests/run_tests.gd`, `tests/audit_export.gd`. Runner mantém testes da Foundation histórica separadamente e passa a verificar Main/arena/jogador como entrada real. Não apagar `foundation.tscn` ou seus testes de integridade.

**Consome:** política/corpo revisados da Tarefa1. **Produz:** Main instanciando laboratório/jogador/adaptador/câmera e o fluxo manual S1. Nomes legados de preset `Windows S0` e `foundation.exe` permanecem provisórios, para evitar renomeação incidental de wrappers/stubs; README explica que a build agora inicia Main S1.

- [ ] RED: Main/preset devem apontar `res://src/game/main.tscn`; testes reais da integração exigem arena/jogador/câmera/configuração e input antes de implementar.
- [ ] Criar cena/adaptador/HUD provisórios e ligar dependências explicitamente. Nenhum script global, autoload, event bus, combate ou asset externo.
- [ ] Exercitar via eventos/amostras: câmera movendo com cursor parado, mouse nos pés, independência move/mira, troca deliberada de dispositivo, foco/retorno com teclas retidas, desconexão/reconexão e reset/recriação repetidos. Simulados são identificados como tais.
- [ ] Migrar preset e auditor juntos: allowlist lógica EXATA `src/player/{input_state,player_input,player}.gd` e `src/arenas/movement_lab.gd`; cenas `src/game/main.tscn`, `src/player/player.tscn`, `src/arenas/movement_lab.tscn`. Sem wildcard de scripts, scripts embutidos, @tool, addons ou extensões nativas.
- [ ] Reconhecer scripts brutos ou compilados/remaps realmente produzidos pela engine somente quando vinculados à allowlist; exigir destinos no PCK, sem traversal/ciclos/aliases e `.gdc` órfãos. Metadados necessários da engine são listados, não liberar `.godot/**` genericamente. Inventário inválido deve encerrar ANTES de carregar/instanciar recursos.
- [ ] Fixtures isoladas e inertes: script extra, `.gdc` órfão, remap de origem não autorizada/externo, arquivo de teste/ferramenta e `.env` fictício devem retornar1 na fase de inventário, não apenas por cena ausente. Não usar segredo real ou executar payload desconhecido.
- [ ] GREEN/regressão e captura real720/1080 com sequência de oclusão/posição da câmera e marcadores legíveis. Capturas/vídeos dirigidos por automação são evidências sintéticas, não controle físico/manual.
- [ ] Após preparar saídas SEM sobrescrita, exportar Debug/Release, auditar PCK reais e executar em staging só de artefatos. Coordenador deve inspecionar/hashes antes de preservar builds S0 em subpasta ignorada; artefato inesperado exige parar, não apagar/mover trabalho alheio.
- [ ] Revisão independente de aderência/qualidade da tarefa; correções da mesma rodada reunidas/revalidadas. Revisão integrada final examina novos riscos e usa pareceres anteriores ainda válidos.

## Evidências e responsáveis
| Dimensão | Evidência e executor | Bloqueio |
| --- | --- | --- |
| Regras/entrada | Implementador/coordenador executam runner, vetores/zero/NaN/drift/foco/reconexão | Falha real, teste removido para esconder regressão ou código de erro falso |
| Física/coordenadas | Testes reais em mundo2D e captura da câmera/pés/colisão | Atravessar/ficar preso, direção dependente da câmera ou ordenação incorreta |
| Pack/segurança | Implementador/coordenador executam allowlist positiva/negativas, auditorias e staging; revisor analisa | Recurso extra, segredo/teste/ferramenta ou carregamento antes do inventário aprovado |
| Visual | Coordenador observa capturas720/1080 e vídeo; experiencia analisa conforme risco | Marcador/posição/avisos ilegíveis ou capture inferida de headless |
| Manual físico | Usuário/operador humano joga teclado/mouse e controle real, foco/desconexão e vídeo por dispositivo | Hardware/executor não confirmado ou critério não observado permanece não verificado |
| Git/entrega | Coordenador revisa índice/objetos, commit/push só S1-movimento e PR para main, sem merge | Achado crítico/alto, revisão necessária ausente, base/colisão alterada, push/PR sem confirmação |

## Análises recebidas e ameaças tratadas antes de código
- Arquitetura `ses_e7d4415d6ffeQY0cOy9nYCqTvc`, Solhigh pela interdependência input/câmera/física/pack: duas unidades e contratos mínimos acima. Sem shell/escrita/rede.
- Experiência `ses_e7d4415b6ffe3f2128VAJEtaAN`, Solmedium por blockout/estados delimitados com direção aprovada: layout/indicadores/foco/legibilidade e evidências reais, não amostra artística. Impeccable/shape somente referência de análise, sem comandos/arquivos da skill.
- Segurança `ses_e7d3fc922ffe5O8gb003S8q0qe`, Solmedium por fronteira fonte→PCK delimitada, risco médio condicionado à alteração de dependência/artefato. Ativos: integridade e confidencialidade locais; ator: desenvolvedor/exportador ou terceiro que altere pack. Mitigação: allowlist lógica/remaps/inventário antes de ResourceLoader e negativas inertes. Allowlist/versionstring não autentica conteúdo nem cria sandbox para host comprometido. Sem servidor/tenants/saves/rede nova neste recorte.
- Referências solicitadas aprovadas pela política central `vibe-c/docs/SQUAD.md`; catálogo vigente confirmou variantes. Custo desconhecido e identidade efetiva não confirmada por metadados independentes. Uma chamada por análise, sem retry; arquitetura/experiência executadas realmente em paralelo sobre base estável, segurança após handoff.

## Método e ledger
Execução prevista por agentes: implementador novo por tarefa em Solhigh por integração de cenas/física/eventos; revisão de tarefa/final em Solhigh ou perfil menor somente se risco do contrato justificar. Seleção explícita por chamada, sem mudar modelo do coordenador. Uma chamada inicial e até uma retomada delimitada de correção por rodada; disponibilidade inválida bloqueia sem fallback. Analistas sem shell/escrita/Git/delegação.

Um checkout/branch da tarefa, um implementador de cada vez; nenhuma worktree adicional ou instalação de processo. A base limpa e a exclusividade de escrita foram verificadas, não se alega sandbox. Durante revisões, congelar fonte/diff; testes gerados ficam ignorados e não são escrita compartilhada de fonte.

- [x] Usuário aprovou recorte S1 e identificador/base; branch criada pelo coordenador com prova acima.
- [x] Baseline integrada verificada; análises de arquitetura/experiência/segurança recebidas.
- [x] Usuário selecionou “Aprovar e implementar” e informou “Não tenho controle”. Hardware físico indisponível; implementar/testar restante sem declarar aceite de controle físico.
- [ ] Tarefa1 implementada, testada, revisada e commitada como incremento válido.
- [ ] Tarefa2 implementada, testada e revisada.
- [ ] Revisão integrada final, push/PR real e resultados entregues; sem merge automático.
- [ ] Critérios completos/manuais S1 aceitos; só então pedir início S2.

Auto-revisão do plano: requisitos aprovados mapeados nas duas tarefas; contratos usados pela Tarefa2 definidos na Tarefa1; arquivos/testes com escritor serial; negativos cobrem os cinco pontos de revisão. Lacuna deliberada: executor/hardware de controle físico ainda não confirmado, não convertido em simulação aprovada. Este plano não contém código de gameplay implementado.

Atualização do gate: usuário confirmou ausência de controle físico na conferência, não uma dispensa automática do critério. Teclado/mouse poderá receber roteiro manual humano; controle físico permanece bloqueio de aceite completo S1 até haver evidência ou decisão explícita de mudança de requisito. Vídeos/eventos de controle sintéticos serão identificados como simulados. Execução das tarefas autorizada sem aguardar compra/instalação de hardware.

Builder check independente: `qualidade`, sessão `ses_e7d38d115ffe0CZf2wy8ishtrZ`, solicitado `openai/gpt-6.1-sol#medium` por conferência moderada de integração/aceite. Parecer de executabilidade favorável após conferência humana, sem lacuna importante, contradição concreta ou pergunta adicional antes do gate. Hardware/executor físico explicitamente pendente no gate apropriado. Somente leitura/análise estática, sem testes; custo desconhecido e efetivo não confirmado por metadados independentes. Uma chamada, sem retry. Não equivale a aprovação de produto ou código S1 testado.

## Execução — Tarefa1 em revisão
Implementador novo `ses_e7d31a3c9ffeeoZzTLBysfRIEJ`, solicitado `openai/gpt-6.1-sol#high` pela integração de política/precisão numérica/corpo físico/testes, conforme lista/política aprovadas. Uma chamada inicial, sem retomada de revisão até este registro; custo desconhecido e identidade/variante efetiva não confirmadas por metadados independentes. Relatório `.tools/s1/task1-implementation-report.md`.

Criados política RefCounted, corpo/cena CharacterBody2D e dois módulos de teste; runner existente integra os casos sem alterar main/preset/auditor/wrappers. RED real antes de produção:154checks/2falhas por recursos ausentes, exit1. Limite radial exato expôs diferença Vector2float32/float64; diagnóstico reproduziu e correção representou0,2 com a precisão de Vector2, sem mudar regra ou relaxar teste.

Implementador executou import0, suíte224/0, negativa225checks/uma falha deliberada exit1, wrappers completos63/0 e positiva final224/0. Uma tentativa de wrappers excedeu120s sem resumo; só depois de confirmar ausência de processo concorrente, execução com prazo360s passou, sem alterar código para contornar timeout. Coordenador reexecutou224/0, negativa1 e positiva224/0 após handoff. Não foram executados export/captura/foco/dispositivos da Tarefa2 ou controle físico; a arena ainda não está implementada. Próximo gate: congelar fonte e obter revisão independente da Tarefa1 antes de commit/liberar Tarefa2.

### Rodada de revisão/correção Tarefa1
Parecer independente `ses_e7d1f06a0ffeZKwT3Wsfs06PYU`, solicitado Solhigh pela interdependência física/números/testes, política aprovada, custo desconhecido e efetivo não confirmado. Identificou um achado alto de falso verde se subteste GDScript abortar sem registrar check; um médio de contagem de ticks por process_frame; um médio de velocidade finita enorme gerando Vector2 não finito. Coordenador conferiu os trechos atuais e a coerência das causas antes de encaminhar reprodução/correção. Parecer de aderência parcial e qualidade desfavorável nesta base; bloqueia commit/liberação da Tarefa2 até revalidação.

Decisões técnicas da correção, sem mudar gameplay aprovado: protocolo interno de testes retorna bool de conclusão em módulo/subteste e chamador exige true, com guardas de métodos e negativas isoladas de método ausente/erro runtime. Velocidade configurável fica suportada em0–1000 unidades/s (default240 preservado); valores fora dessa faixa ou não finitos são neutros e vetor calculado também é validado antes da física. Esse teto é proteção numérica/contrato do laboratório, não balanceamento final. Teste físico deve observar ticks realmente concluídos ou congelar avanço após orçamento observado, nunca absorver ticks extras por tolerância ampla. Fixtures adicionais exclusivamente sob `tests/fixtures/`/`.tools/s1/` autorizadas para demonstrar falso verde e proteção, sem flags de teste em produção ou alteração dos wrappers/preset/cena principal.

### Revalidação corretiva recebida
Retomada de implementação no mesmo seletor `openai/gpt-6.1-sol#high`, autorizada explicitamente pelo usuário após tentativa bloqueada por `The usage limit has been reached`, concluiu as correções. Sem fallback ou mudança de tarefa/modelo; apêndice do relatório preserva o histórico e os RED/GREEN.

Coordenador verificou driver Corrected8casos/0divergências, suíte309/0, negativa deliberada1 e positiva309/0. Evidências `.tools/s1/review-fixtures/corrected-99ce36db7eeb41cfaf50f16066a9e809/`; não repetir Baseline na fonte corrigida. Pacote `.tools/s1/task1-correction-review.diff`562linhas compara os quatro arquivos corrigidos com cópias cujo SHA256 corresponde ao manifesto originalmente revisado e inclui o driver novo. Hashes da fonte atual em `.tools/s1/task1-correction-sha256.txt`.

Revisor independente original `ses_e7d1f06a0ffeZKwT3Wsfs06PYU`, retomado na mesma tarefa/seletor `openai/gpt-6.1-sol#high`, confirmou os três achados resolvidos, sem novos achados relevantes. Pareceres explícitos de ADERÊNCIA e QUALIDADE favoráveis à Tarefa1 corrigida. Analisou delta completo, apêndice, fontes e oito logs; sem execução própria, shell, escrita, rede ou scan. Modelo solicitado mantido pela interdependência física/retornos/finitude, autorizado pela política central e catálogo reconfirmado; custo desconhecido e efetivo não confirmado independentemente. Uma revalidação, sem retry. Fonte congelada até o parecer; alteração posterior dos registros de coordenação não muda a fonte revisada.

Gate técnico Tarefa1 satisfeito para commit após inspeção do índice. Próximo contrato Tarefa2 deve consumir módulos `run(tree,check)->bool`, preservar TickBudget e incluir `tests/fixtures/test_s1_review.ps1` na atribuição: atualizar sua cópia mínima para Main/arena/adaptador, mantendo as negativas do runner e sem liberar cópia ampla. Ainda não há aceite manual, visual ou de controle físico, export S1, push/PR S1 ou autorização de S2.
