# Último Sol — redcap-revenants-game

Roguelike de ação 2D com aparência isométrica e ambientação em um apocalipse urbano brasileiro. “Último Sol” é o título criativo provisório; o nome deste repositório não representa mudança automática da direção aprovada.

## Estado
S0/S1 integradas pelo usuário; S1 aceita em sessão assistida com teclado/mouse e controle físico. S2 e sua correção de dano foram integradas pelos [PR3](https://github.com/5antia60/redcap-revenants-game/pull/3) e [PR4](https://github.com/5antia60/redcap-revenants-game/pull/4), main-base `9ab4e1d9fcb7f6ddaed2c409a1d0c0a4bc9fdb2d`. Aceite dirigido do dano sem áudio em teclado/mouse registrado; controle físico S2 explicitamente adiado, não dispensado.

S3 foi autorizada na branch `S3-primeiro-encontro`: um perseguidor corpo a corpo e um encontro com três inimigos. Fonte candidata `0.2.0` implementada/revalidada, revisão integrada favorável e entrega técnica enviada somente à branch própria; PR para main aguarda autenticação atual conforme [contexto](docs/CONTEXTO.md). Debug/Release locais auditados e iniciados em staging somente EXE/PCK. Não é aceite S3, integração em main, tag ou build pública. Sem arsenal adicional, progressão ou arte final. Controle físico e avaliação humana de resposta/legibilidade permanecem pendentes.

### Primeiro encontro S3
Main agora abre uma arena própria, com três perseguidores: aproximação direta, preparação com direção fixada, golpe e recuperação. Cassetete/esquiva do jogador preservam regras S2. Aviso vazio, setor ativo hachurado e postura de recuperação são provisórios; setor hostil fica no chão abaixo dos corpos. Vida30 e três golpes de10 por inimigo; ataque hostil causa10, sem dano por encostar. Última morte válida conclui o encontro; morte do jogador encerra em derrota. Menu permite reinício e confirmação durante tentativa viva; pausa manual congela fases, enquanto perda de foco/desconexão interrompe ações antes da pausa. Reinício descarta estado/sinais antigos. O laboratório S2 permanece na fonte e nas regressões, fora do pack S3.

Baixa visual aberta: rótulos de vida/dano podem disputar espaço. Ensaio12 não é encontro prometido nem legibilidade aprovada. Capturas nativas e headless não substituem teste humano em velocidade normal; métricas identificam a fonte medida e não certificam a meta final S7.

### Correção de leitura do dano
A zona passa a ser chão abaixo dos atores. Dano recebido não letal aceito gera marcas angulares breves no tronco e número da perda efetiva acima do personagem, sem depender do HUD ou áudio. Marcas duram0,20s; números estáticos duram0,60s em até dois espaços, sem soma ou fila atrasada. Recusas por proteção, pausa, morte ou entrada inválida não criam efeito; morte e reinício limpam a apresentação. Não há novo intervalo de proteção, mudança de dano/colisão ou tremor/flash de tela. Esses valores visuais são escolhas técnicas reversíveis, não arte final S5.

Exports corretivos S2 históricos preservados em `.tools/s2/feedback-dano-final-e56708f07a7d4c04aaf6167e25f6913b/windows-debug/` e `windows-release/`, separados dos anteriores. Passaram auditoria/staging e reteste dirigido em teclado/mouse registrado. **Essas builds e `builds/windows-release/` não são S3 e não podem comprovar o encontro0.2.0.**

Exports reais S3 atuais: `.tools/s3/unit2-export-6f95a8a546de4775b621c764f6a73af2/windows-debug/` e `windows-release/`. Ambos PCK77828bytes/SHA256 `0cf596ca4d92da5d9ef56c36c32d00101024f4755f72a6bb68d51e4ac07054d8`,17entradas/0falhas. Staging `.tools/s3/unit2-staging-314ab583fecf41429a24a78022aadff6/`: cada EXE iniciou com PCK apenas,120frames/exit0; captura separada3frames/exit0. Versão0.2.0 observada nas próprias builds, pausadas por falta de foco. Isso prova inicialização/identidade/versão, não interação humana, controle físico ou diversão.

## Documentação
- [GDD](docs/GDD.md): visão, pilares, escopo e decisões de produto.
- [Arquitetura](docs/ARCHITECTURE.md): contratos técnicos, alternativas e convenções.
- [Roadmap](docs/ROADMAP.md): sprints, testes e critérios de aceite.
- [Art bible](docs/ART_BIBLE.md): direção visual, produção e licenciamento.
- [Agentes](AGENTS.md): delegação, revisão e limites.
- [Contexto](docs/CONTEXTO.md): estado real e próximo passo.
- [Plano S0](docs/superpowers/plans/2026-10-27-s0-fundacao.md): execução autorizada e evidências.
- [Plano S1](docs/superpowers/plans/2026-10-28-s1-movimento.md): laboratório, contratos e evidências por tarefa.
- [Plano S2](docs/superpowers/plans/2026-10-29-s2-combate.md): combate, evidências e gates do candidato.

## Ferramentas
### Versões do jogo
Usar Semantic Versioning enquanto o jogo evolui: S2 foi candidato `0.1.0`; S3 é candidato `0.2.0`, próxima entrega funcional normalmente incrementa MINOR, correção compatível incrementa PATCH. S0/S1 permanecem baselines históricos sem tags retroativas inventadas. Versão da aplicação não é a versão da engine. Metadado e capturas da fonte S3 identificam0.2.0; versão exata das futuras builds será conferida separadamente, sem inferir export, tag ou release.

Cada versão aceita e integrada recebe tag anotada `vMAJOR.MINOR.PATCH` após validação do hash na main, nunca antecipadamente na branch. Não mover tags existentes, enviar tags em lote ou publicar release/build automaticamente. Prévia `-dev` identifica desenvolvimento; `1.0.0` exige aprovação de uma versão estável, não apenas encerramento de sprint.

Godot **4.7.2.stable.official.ed1daf0bf**, edição padrão Windows x86_64, GDScript e Compatibility. Engine e templates portáteis locais autorizados, fora do Git; sem alteração de PATH/AppData. Não instalar plugins, atualizar OpenCode ou publicar builds sem autorização pertinente.

Para preparar outro checkout: obter o asset `Godot_v4.7.2-stable_win64.exe.zip` da [release oficial](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), conferir 86.013.866 bytes e SHA-256 `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`, e colocar os dois executáveis oficiais em `.tools/godot/`. Não executar download divergente ou material de origem não confirmada. O plano S0 registra os controles usados na preparação local.

## Executar e testar no Windows PowerShell
Da raiz deste repositório:
```powershell
powershell -NoProfile -File .\scripts\import.ps1
powershell -NoProfile -File .\scripts\test.ps1
powershell -NoProfile -File .\tests\test_wrappers.ps1
powershell -NoProfile -File .\scripts\run.ps1
```

Importação e testes positivos devem retornar 0. `run.ps1` abre Main S3 nesta branch; feche a janela para encerrar. WASD/setas ou analógico esquerdo movimentam; mouse ou analógico direito miram. LMB/botão oeste golpeia uma vez por pressão, fixando a direção no início; Espaço/botão sul esquiva, usando movimento ou última mira válida quando parado. Escape/Start pausa. A pausa manual conserva a fase; perda de foco/desconexão interrompe a ação e abre pausa. Ao continuar, solte e pressione novamente teclas/botões e neutralize os sticks. Teclado/mouse permitem recuperar após desconexão. Para abrir no editor, use o executável Godot com `--editor --path .`.

Prova negativa do runner:
```powershell
powershell -NoProfile -File .\scripts\test.ps1 -SelfTestFailure
```
Esse comando deve falhar deliberadamente com código 1; depois reexecute o teste normal. O runner usa verificações explícitas, não `assert` removível. `tests/test_wrappers.ps1` compila apenas uma fixture controlada com o compilador .NET Framework já disponível no Windows; não instala .NET e mantém os executáveis em `tests/.generated/`, ignorados pelo Git. Sem esse compilador, essa suíte fica bloqueada, não silenciosamente aprovada.

Os wrappers aceitam `-GodotPath <caminho literal local de exe confiável>` e não dependem do diretório de chamada. Esse parâmetro executa o arquivo escolhido inclusive para consultar versão: não é sandbox ou autenticação de binário. Não apontar para executáveis não confiáveis. Sem scanner externo ou CI instalado nesta fundação.

O repositório é independente do ambiente `vibe-c`. Os documentos foram transferidos para cá por pedido do usuário; referências antigas devem apontar para este alvo, sem evolução concorrente.

## Exportação local Windows
Obter da mesma release oficial o pacote padrão, não mono, `Godot_v4.7.2-stable_export_templates.tpz`: 1.281.349.702 bytes (~1,19 GiB), SHA-256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`. Conferir integridade antes da extração/execução. Somente cinco arquivos de `templates/` são necessários em `.tools/templates/4.7.2.stable/`: `version.txt` (conteúdo `4.7.2.stable`), `windows_debug_x86_64.exe`, `windows_debug_x86_64_console.exe`, `windows_release_x86_64.exe` e `windows_release_x86_64_console.exe`.

Manter companions oficiais ao lado dos executáveis: consulta de versão usa o console wrapper porque executável GUI não oferece stdout/espera confiáveis no PowerShell. Sem instalação global de templates; o wrapper não baixa arquivos.

```powershell
powershell -NoProfile -File .\scripts\export.ps1 -Configuration Debug
powershell -NoProfile -File .\scripts\export.ps1 -Configuration Release
```
Esses wrappers têm saídas fixas em `builds/windows-debug/` e `builds/windows-release/`: `foundation.exe` e `foundation.pck`, com companion console adicional no Debug. Nomes e preset `Windows S0` são legados; entrada da fonte atual é Main S3. Diretório não vazio é recusado: preserve artefatos, sem limpeza/sobrescrita automática. Não há parâmetro de destino nesses wrappers. Para S3, o coordenador usa a engine diretamente, com preset inspecionado e destino novo sob `.tools/s3/unit2-export-<id>/`, somente após gate da fonte. Exporta somente Main e dependências, PCK externo e scripts/cenas em texto. `.gitignore` não controla conteúdo do pack.

Auditoria S3, somente para exportação local de procedência conhecida. Primeiro congele/revise as quatorze fontes (dez scripts e quatro cenas), prepare um manifesto externo novo a partir delas e registre hash/tamanho do PCK da exportação controlada. Contagem14 coincide com S2, mas cinco fontes são outras; manifesto S2 deve ser recusado. Não regenere manifesto para aceitar divergência. Exemplo, da raiz, usando diretório existente e arquivo ainda ausente:
```powershell
$manifest = Join-Path $PWD '.tools/s3/unit2-export-<id>/source-manifest.json'
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode PrepareManifest -ManifestPath $manifest
# Para cada configuração, use o hash previamente registrado e o PCK congelado:
$pack = Join-Path $PWD '.tools/s3/unit2-export-<id>/windows-debug/foundation.pck'
$expectedHash = '<SHA256 confiável registrado, em minúsculas>'
$expectedSize = 0 # Substituir pelo tamanho externo registrado; zero é recusado.
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode Audit -ManifestPath $manifest -PckPath $pack -ExpectedPckSha256 $expectedHash -ExpectedPckSize $expectedSize
```
Repita Audit para Release com seu caminho/tamanho/hash registrados. Não execute os placeholders literalmente. Antes da engine, o driver usa `tests/read_export_pack.ps1`: leitor offline limitado a PCK4/engine4.7.2, sem extração ou execução de conteúdo. Confere as quatorze fontes, cache global exatamente vazio e UID cache inteiramente decodificado com até quatorze referências somente às fontes autorizadas; então produz atestado externo novo. São admitidos apenas `project.binary`, `.godot/global_script_class_cache.cfg` e `.godot/uid_cache.bin` como metadados, totalizando dezessete entradas. Na engine, o auditor exige filesystem `PCK`, manifesto/atestado, inventário exato e identidade das fontes/metadados antes de ResourceLoader. Compilados, remaps opacos, extras ou manifesto divergente são recusados. Manifestos/packs S0/S1/S2 não satisfazem o contrato S3. `project.binary` já é consumido antes do auditor: procedência, configuração e ausência de troca concorrente são pressupostos, não uma sandbox para packs de terceiros. SHA256/atestado local não autenticam origem. O auditor aceita também `0.2.0-dev`; conferir separadamente a versão exata nas builds candidatas.

Regressões locais adicionais, em cópias novas e isoladas:
```powershell
powershell -NoProfile -File .\tests\fixtures\test_s1_review.ps1 -Stage Corrected
powershell -NoProfile -File .\tests\fixtures\test_input_collection.ps1
powershell -NoProfile -File .\tests\test_export_audit.ps1
powershell -NoProfile -File .\tests\fixtures\test_export_pack_reader.ps1
```
Não execute `-Stage Baseline` na fonte corrigida; esse modo documenta retornos defeituosos históricos. Timers internos do auditor/gerador não interrompem trabalho síncrono bloqueado; supervisão externa dedicada permanece uma melhoria operacional registrada.

Para iniciar fora do editor, copie apenas EXE/PCK (e companion se desejado) para diretório novo e execute `foundation.exe` de lá, sem `--path`/`--editor`. Mantenha EXE e PCK juntos. Builds locais não assinadas podem gerar avisos; não desabilitar proteções do Windows.

## Evidências e limites
### Roteiro manual S3 — somente na build candidata liberada
1. Reconhecer os três inimigos e seus avisos, golpe hachurado e recuperação; comparar alcance aparente com acerto real. Mover e mirar independentemente, golpear com nova pressão e esquivar de direção já anunciada.
2. Repetir sem áudio e sem usar o HUD como única indicação de dano. Corpo/pés, proteção e reação devem continuar reconhecíveis no encontro3 em720/1080. Disputa de rótulos está documentada; se impedir compreender ação, manter aceite aberto.
3. Pausar em preparação/golpe/recuperação e retomar sem comando preso. Perder foco e desconectar o controle ativo devem interromper ações e abrir pausa, mantendo recuperação por teclado/mouse. Controle físico será validado quando o usuário avisar disponibilidade; simulação não o substitui.
4. Matar os três inimigos, verificando contagem e conclusão somente após o último válido; depois provocar derrota. Conferir que não há dano/ação nova depois do resultado. Não existe sequência de encontros/progressão S4.
5. Reiniciar após resultado e pela pausa, confirmar/cancelar descarte e repetir três vezes: vida100, três inimigos30, relógios/entrada restabelecidos, sem duplicação de corpos/sinais. Relatar resposta, impacto, legibilidade e comandos perdidos; capturas e testes não aprovam diversão.

### Roteiro S2 preservado — controle físico ainda pendente
S2 e correção já foram integradas; teclado/mouse e reteste dirigido do dano sem som têm confirmações humanas registradas. Preserva-se o roteiro para completar controle físico quando disponível, sem repetir automaticamente os aceites válidos. S1 foi aceita em sessão com controle físico/teclado/mouse, sem vídeo conforme autorização explícita.

1. Com teclado/mouse, mover com WASD/setas e atacar com botão esquerdo; no controle, analógico esquerdo move, direito mira e botão oeste (X/Quadrado) ataca. Circular os alvos e mirar em direção diferente do movimento.
2. Pressionar ataque uma vez e depois segurar: uma nova pressão deve iniciar um novo golpe, sem repetição automática. Conferir contato perto da borda do setor e atrás de parede. Cada alvo começa com30 de vida e recebe10 por golpe aceito, nunca múltiplos danos daquele mesmo golpe.
3. Esquivar com Espaço ou botão sul (A/Cruz), parado e em movimento. Verificar direção pela mira quando parado, colisão com parede, recarga e cancelamento somente da recuperação do ataque. Movimento livre nominal da esquiva120unidades; obstáculo pode encurtar.
4. Na zona de treino sinalizada, comparar dano andando com passagem sincronizada à esquiva. Contorno de proteção deve coincidir com invulnerabilidade, não durar todo o rastro. Parar se dano e indicação visual discordarem; não tratar falha como ajuste aprovado.
5. Pausar com Escape/Start durante preparação, ataque e esquiva. Relógios/dano devem parar; Continuar não pode disparar ataque/esquiva por botão retido. Perder foco e desconectar o controle ativo devem interromper ação e abrir pausa, com teclado/mouse acessíveis para recuperar.
6. Verificar morte e reinício, incluindo reiniciar a partir da pausa e três vezes consecutivas. Vida, alvos, zona, custos e entrada devem voltar ao estado inicial, sem personagens/sinais duplicados.
7. Repetir sem som; relatar resposta, impacto, legibilidade e comandos perdidos. Testes automatizados e capturas não aprovam diversão ou substituem hardware. Aceite S2 e tag de versão pronta dependem dos gates registrados no plano.

Na correção atual, coordenador confirmou fonte1408/0, negativa1409/1 exclusivamente deliberada/exit1 e parse do harness0. Revisões independentes de produção/UX favoráveis; seis casos isolados do harness comprovam recusa de colisões e preservação de sentinelas, sem garantia de atomicidade/TOCTOU. Novos Debug/Release auditados com17entradas/0falhas/exit0; PCKs65912bytes/SHA256 `a7f6585ccdfa60f9cc8b95a42aa342b349ec3f9ab2a8f4cb9d256a69b94a4a54`. Wrappers63/0 exit0 foram executados pelo usuário na base integrada, não repetidos nesta unidade. Resultados anteriores de coleta/mutações10/0, Corrected8/0, leitor56/0, auditorfixtures21/0 e atestados8/0 permanecem evidências dos caminhos inalterados, não novas execuções. Os cinco artefatos anteriores foram preservados no lugar e conferidos por tamanho/SHA256; não reexportar ou apagar históricos por rotina. Capturas720/1080 e revisões comprovam somente estados observados, não percepção humana contínua, hardware S2, áudio/feeling ou benchmark.

S1 permanece aceita pelas confirmações humanas registradas no GDD; não repetir por rotina. S2/S3 exigem seus critérios pertinentes nos dois dispositivos, inclusive resposta/impacto/legibilidade e áudio; controle físico está adiado, não dispensado. S3 tem implementação autorizada, não aceite final nem autorização S4.

`tests/capture_foundation.gd` salva textura direta de janela real1920×1080, sem desktop/upscale ou alteração do projeto. Tela0/borderless são configurações apenas do harness; ele mede cliente/imagem e preserva escala lógica1280×720/canvas_items. Captura em `.tools/s0/captures/task2-window-1920x1080.png`; recusa sobrescrever. Em outro host pode falhar por janela/renderer indisponível; fallback offscreen não equivale a janela1080. Inspeção desse PNG não é captura visual da build exportada.

CLI local `opencode --version`: `1.18.34`. Especialistas funcionaram pela interface atual, sem comprovar compatibilidade da configuração V2 com aquele CLI. Nenhuma atualização foi feita. Ferramenta/autenticação ausente para PR é bloqueio declarado, não PR fictício ou merge automático.
