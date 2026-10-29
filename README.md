# Último Sol — redcap-revenants-game

Roguelike de ação 2D com aparência isométrica e ambientação em um apocalipse urbano brasileiro. “Último Sol” é o título criativo provisório; o nome deste repositório não representa mudança automática da direção aprovada.

## Estado
S0 integrada pelo usuário. S1 autorizada e em validação: laboratório de movimento, mira independente, câmera, colisão e profundidade com formas provisórias. Não há combate, esquiva, inimigos ou arte final. Revisões, evidências e gates restantes ficam no contexto/plano; nenhuma build foi publicada. Controle físico continua não verificado porque o usuário não dispõe desse hardware.

## Documentação
- [GDD](docs/GDD.md): visão, pilares, escopo e decisões de produto.
- [Arquitetura](docs/ARCHITECTURE.md): contratos técnicos, alternativas e convenções.
- [Roadmap](docs/ROADMAP.md): sprints, testes e critérios de aceite.
- [Art bible](docs/ART_BIBLE.md): direção visual, produção e licenciamento.
- [Agentes](AGENTS.md): delegação, revisão e limites.
- [Contexto](docs/CONTEXTO.md): estado real e próximo passo.
- [Plano S0](docs/superpowers/plans/2026-10-27-s0-fundacao.md): execução autorizada e evidências.
- [Plano S1](docs/superpowers/plans/2026-10-28-s1-movimento.md): laboratório, contratos e evidências por tarefa.

## Ferramentas
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

Importação e testes positivos devem retornar 0. `run.ps1` abre Main S1; feche a janela para encerrar. WASD/setas ou analógico esquerdo movimentam; mouse ou analógico direito orientam o marcador. A mira mantém a última direção válida. Ao voltar à janela, solte e pressione novamente as teclas; neutralize os sticks antes de mover. Desconectar o controle não impede recuperar pelo teclado/mouse. Ataque e esquiva ainda não são implementados, mesmo que seus bindings históricos existam. Para abrir no editor, use o executável Godot com `--editor --path .`.

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
Saídas em `builds/windows-debug/` e `builds/windows-release/`: `foundation.exe` e `foundation.pck`, com companion console adicional no Debug. Esses nomes e o preset `Windows S0` são legados; a entrada agora é Main S1. Diretório não vazio é recusado: preserve explicitamente artefatos antes de repetir; sem limpeza/sobrescrita automática. Exporta somente Main e dependências, com PCK externo e scripts/cenas em texto. `.gitignore` não controla conteúdo do pack.

Auditoria S1, somente para exportação local de procedência conhecida. Primeiro congele/revise as quatro fontes de script e três cenas, prepare um manifesto externo novo a partir delas e registre o hash do PCK da exportação controlada. Não regenere manifesto para aceitar divergência. Exemplo, da raiz, usando diretório existente e arquivo ainda ausente:
```powershell
$manifest = Join-Path $PWD '.tools/s1/reviewed-source-manifest.json'
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode PrepareManifest -ManifestPath $manifest
# Para cada configuração, use o hash previamente registrado e o PCK congelado:
$pack = Join-Path $PWD 'builds/windows-debug/foundation.pck'
$expectedHash = '<SHA256 confiável registrado, em minúsculas>'
$expectedSize = 0 # Substituir pelo tamanho externo registrado; zero é recusado.
powershell -NoProfile -File .\tests\test_export_audit.ps1 -Mode Audit -ManifestPath $manifest -PckPath $pack -ExpectedPckSha256 $expectedHash -ExpectedPckSize $expectedSize
```
Repita Audit para Release com seu caminho/tamanho/hash registrados. Não execute os placeholders literalmente. Antes da engine, o driver usa `tests/read_export_pack.ps1`: leitor offline limitado a PCK4/engine4.7.2, sem extração ou execução de conteúdo. Confere as sete fontes, cache global exatamente vazio e UID cache inteiramente decodificado com referências somente às fontes autorizadas; então produz atestado externo novo. São admitidos apenas `project.binary`, `.godot/global_script_class_cache.cfg` e `.godot/uid_cache.bin` como metadados. Na engine, o auditor exige filesystem `PCK`, manifesto/atestado, inventário exato e identidade das fontes/metadados antes de ResourceLoader. Compilados, remaps opacos, extras ou manifesto divergente são recusados. O contrato não é retrocompatível com packs S0. `project.binary` já é consumido antes do auditor: procedência, configuração e ausência de troca concorrente são pressupostos, não uma sandbox para packs de terceiros.

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
Última suíte de fonte executada pelo coordenador: 502 verificações sem falhas, negativa deliberada com retorno1 e seis mutações de coleta sem divergências. Implementador executou wrappers63/0, oito fixtures do runner,21 de auditoria e seis de atestados; coordenador conferiu37casos do leitor offline. Novos Debug/Release S1 foram auditados com dez arquivos/zero falhas e executados em staging somente EXE/PCK, janela OpenGL Compatibility,120frames e exit0. Evidências e hashes no plano S1. Capturas de janela real720/1080 demonstram blockout/oclusão; entrada e roteiro automatizados não são aceite humano, hardware físico, vídeo contínuo ou benchmark.

Roteiro manual de teclado/mouse: andar lateralmente mirando no sentido oposto; contornar o prop por trás/lado/frente; atravessar a passagem e encostar nos limites; alternar foco com tecla retida, soltar e pressionar novamente. Registrar sensação, falhas e, se possível, vídeo. Quando houver controle físico, repetir movimento/mira, drift, foco e desconexão/reconexão. Nenhum desses critérios é dispensado por simulação. Não iniciar S2 sem aprovação explícita.

`tests/capture_foundation.gd` salva textura direta de janela real1920×1080, sem desktop/upscale ou alteração do projeto. Tela0/borderless são configurações apenas do harness; ele mede cliente/imagem e preserva escala lógica1280×720/canvas_items. Captura em `.tools/s0/captures/task2-window-1920x1080.png`; recusa sobrescrever. Em outro host pode falhar por janela/renderer indisponível; fallback offscreen não equivale a janela1080. Inspeção desse PNG não é captura visual da build exportada.

CLI local `opencode --version`: `1.18.34`. Especialistas funcionaram pela interface atual, sem comprovar compatibilidade da configuração V2 com aquele CLI. Nenhuma atualização foi feita. Ferramenta/autenticação ausente para PR é bloqueio declarado, não PR fictício ou merge automático.
