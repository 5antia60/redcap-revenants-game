# Último Sol — redcap-revenants-game

Roguelike de ação 2D com aparência isométrica e ambientação em um apocalipse urbano brasileiro. “Último Sol” é o título criativo provisório; o nome deste repositório não representa mudança automática da direção aprovada.

## Estado
S0/S1 integradas pelo usuário; S1 aceita em sessão assistida com teclado/mouse e controle físico. S2 implementada como candidato local `0.1.0`: cassetete, esquiva, três alvos, vida/morte, zona de treino e pausa/reinício. Fonte e correções receberam revisão por tarefa; exports Debug/Release foram auditados e iniciaram em staging somente EXE/PCK. Revisão integrada final favorável; entrega Git e aceite humano S2 ainda pendentes. Não há inimigos completos, arte final, build publicada ou autorização de S3.

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
Usar Semantic Versioning enquanto o jogo evolui: primeira versão formal planejada `0.1.0` na S2; próximas entregas funcionais `0.2.0`, `0.3.0` e correções compatíveis incrementam PATCH. S0/S1 permanecem baselines históricos sem tags retroativas inventadas. Versão da aplicação não é a versão da engine. Metadado e identificação `0.1.0` estão presentes no candidato e foram observados no HUD/menu das duas builds reais; isso não constitui versão aceita, tag ou release.

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

Importação e testes positivos devem retornar 0. `run.ps1` abre Main S2; feche a janela para encerrar. WASD/setas ou analógico esquerdo movimentam; mouse ou analógico direito miram. LMB/botão oeste golpeia uma vez por pressão, fixando a direção no início; Espaço/botão sul esquiva, usando movimento ou última mira válida quando parado. Escape/Start pausa. A pausa manual conserva a fase; perda de foco/desconexão interrompe a ação e abre pausa. Ao continuar, solte e pressione novamente teclas/botões e neutralize os sticks. Teclado/mouse permitem recuperar após desconexão. Para abrir no editor, use o executável Godot com `--editor --path .`.

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
Saídas em `builds/windows-debug/` e `builds/windows-release/`: `foundation.exe` e `foundation.pck`, com companion console adicional no Debug. Esses nomes e o preset `Windows S0` são legados; a entrada agora é Main S2. Diretório não vazio é recusado: preserve explicitamente artefatos antes de repetir; sem limpeza/sobrescrita automática. Exporta somente Main e dependências, com PCK externo e scripts/cenas em texto. `.gitignore` não controla conteúdo do pack.

Auditoria S2, somente para exportação local de procedência conhecida. Primeiro congele/revise as quatorze fontes (dez scripts e quatro cenas), prepare um manifesto externo novo a partir delas e registre o hash/tamanho do PCK da exportação controlada. Não regenere manifesto para aceitar divergência. Exemplo, da raiz, usando diretório existente e arquivo ainda ausente:
```powershell
$manifest = Join-Path $PWD '.tools/s2/reviewed-source-manifest.json'
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode PrepareManifest -ManifestPath $manifest
# Para cada configuração, use o hash previamente registrado e o PCK congelado:
$pack = Join-Path $PWD 'builds/windows-debug/foundation.pck'
$expectedHash = '<SHA256 confiável registrado, em minúsculas>'
$expectedSize = 0 # Substituir pelo tamanho externo registrado; zero é recusado.
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode Audit -ManifestPath $manifest -PckPath $pack -ExpectedPckSha256 $expectedHash -ExpectedPckSize $expectedSize
```
Repita Audit para Release com seu caminho/tamanho/hash registrados. Não execute os placeholders literalmente. Antes da engine, o driver usa `tests/read_export_pack.ps1`: leitor offline limitado a PCK4/engine4.7.2, sem extração ou execução de conteúdo. Confere as quatorze fontes, cache global exatamente vazio e UID cache inteiramente decodificado com até quatorze referências somente às fontes autorizadas; então produz atestado externo novo. São admitidos apenas `project.binary`, `.godot/global_script_class_cache.cfg` e `.godot/uid_cache.bin` como metadados, totalizando dezessete entradas. Na engine, o auditor exige filesystem `PCK`, manifesto/atestado, inventário exato e identidade das fontes/metadados antes de ResourceLoader. Compilados, remaps opacos, extras ou manifesto divergente são recusados. Manifestos/packs S0/S1 não satisfazem o contrato S2. `project.binary` já é consumido antes do auditor: procedência, configuração e ausência de troca concorrente são pressupostos, não uma sandbox para packs de terceiros. SHA256/atestado local não autenticam origem. O auditor aceita também `0.1.0-dev`; conferir separadamente a versão exata nas builds candidatas.

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
### Próximo roteiro manual S2 — somente após liberar o candidato
O candidato S2 está implementado; a liberação para aceite depende dos gates técnicos registrados no contexto. O roteiro abaixo não afirma teste S2 pelo usuário. S1 já foi aceita em sessão assistida com controle físico e teclado/mouse, sem vídeo conforme autorização explícita.

1. Com teclado/mouse, mover com WASD/setas e atacar com botão esquerdo; no controle, analógico esquerdo move, direito mira e botão oeste (X/Quadrado) ataca. Circular os alvos e mirar em direção diferente do movimento.
2. Pressionar ataque uma vez e depois segurar: uma nova pressão deve iniciar um novo golpe, sem repetição automática. Conferir contato perto da borda do setor e atrás de parede. Cada alvo começa com30 de vida e recebe10 por golpe aceito, nunca múltiplos danos daquele mesmo golpe.
3. Esquivar com Espaço ou botão sul (A/Cruz), parado e em movimento. Verificar direção pela mira quando parado, colisão com parede, recarga e cancelamento somente da recuperação do ataque. Movimento livre nominal da esquiva120unidades; obstáculo pode encurtar.
4. Na zona de treino sinalizada, comparar dano andando com passagem sincronizada à esquiva. Contorno de proteção deve coincidir com invulnerabilidade, não durar todo o rastro. Parar se dano e indicação visual discordarem; não tratar falha como ajuste aprovado.
5. Pausar com Escape/Start durante preparação, ataque e esquiva. Relógios/dano devem parar; Continuar não pode disparar ataque/esquiva por botão retido. Perder foco e desconectar o controle ativo devem interromper ação e abrir pausa, com teclado/mouse acessíveis para recuperar.
6. Verificar morte e reinício, incluindo reiniciar a partir da pausa e três vezes consecutivas. Vida, alvos, zona, custos e entrada devem voltar ao estado inicial, sem personagens/sinais duplicados.
7. Repetir sem som; relatar resposta, impacto, legibilidade e comandos perdidos. Testes automatizados e capturas não aprovam diversão ou substituem hardware. Aceite S2 e tag de versão pronta dependem dos gates registrados no plano.

Verificação recente do coordenador na fonte corrigida S2:1345 verificações sem falhas; negativa1346/1 deliberada exit1; dez casos de coleta/mutação e oito do runner sem divergências. Debug/Release reais auditados com17entradas/0falhas; PCKs62760bytes/SHA256 `d77b1ebd4899d30787341e18cd8ffb8696a2f4a17635943125ff2e275a79eeee`. Ambos EXE iniciaram em staging somente EXE/PCK, OpenGL Compatibility,120frames/exit0; capturas adicionais da própria build mostram0.1.0 e pausa por foco perdido. Evidências detalhadas no plano S2/contexto. Capturas automatizadas720/1080 e revisão visual especializada comprovam somente os estados observados; não são aceite humano, teste de hardware S2, vídeo contínuo ou benchmark.

S1 permanece aceita pelas confirmações humanas registradas no GDD; não repetir por rotina. S2 exige seu próprio roteiro nos dois dispositivos, inclusive resposta/impacto/legibilidade e áudio. Nenhum desses critérios é dispensado por simulação; S3 não está autorizada.

`tests/capture_foundation.gd` salva textura direta de janela real1920×1080, sem desktop/upscale ou alteração do projeto. Tela0/borderless são configurações apenas do harness; ele mede cliente/imagem e preserva escala lógica1280×720/canvas_items. Captura em `.tools/s0/captures/task2-window-1920x1080.png`; recusa sobrescrever. Em outro host pode falhar por janela/renderer indisponível; fallback offscreen não equivale a janela1080. Inspeção desse PNG não é captura visual da build exportada.

CLI local `opencode --version`: `1.18.34`. Especialistas funcionaram pela interface atual, sem comprovar compatibilidade da configuração V2 com aquele CLI. Nenhuma atualização foi feita. Ferramenta/autenticação ausente para PR é bloqueio declarado, não PR fictício ou merge automático.
