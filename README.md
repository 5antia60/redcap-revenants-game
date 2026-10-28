# Último Sol — redcap-revenants-game

Roguelike de ação 2D com aparência isométrica e ambientação em um apocalipse urbano brasileiro. “Último Sol” é o título criativo provisório; o nome deste repositório não representa mudança automática da direção aprovada.

## Estado
Planejamento global aprovado. S0 tem cena de diagnóstico, configuração, testes, exports locais Debug/Release e captura real1920×1080 verificados. Revisão/entrega da continuação e aceite da sprint são registrados no contexto/plano; não há gameplay, S1 autorizada ou publicação de builds.

## Documentação
- [GDD](docs/GDD.md): visão, pilares, escopo e decisões de produto.
- [Arquitetura](docs/ARCHITECTURE.md): contratos técnicos, alternativas e convenções.
- [Roadmap](docs/ROADMAP.md): sprints, testes e critérios de aceite.
- [Art bible](docs/ART_BIBLE.md): direção visual, produção e licenciamento.
- [Agentes](AGENTS.md): delegação, revisão e limites.
- [Contexto](docs/CONTEXTO.md): estado real e próximo passo.
- [Plano S0](docs/superpowers/plans/2026-10-27-s0-fundacao.md): execução autorizada e evidências.

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

Importação e testes positivos devem retornar 0. `run.ps1` abre somente a tela “Último Sol — Fundação S0 / Sem gameplay implementado”; feche a janela para encerrar. Os bindings de entrada estão declarados, mas não movimentam personagens ou executam ações. Para abrir no editor, use o executável Godot com `--editor --path .`.

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
Saídas em `builds/windows-debug/` e `builds/windows-release/`: `foundation.exe` e `foundation.pck`, com companion console adicional no Debug. Diretório não vazio é recusado: preserve ou mova explicitamente artefatos antes de repetir; sem limpeza/sobrescrita automática. Preset `Windows S0` exporta somente a cena e dependências, com PCK externo. `.gitignore` não controla conteúdo do pack.

Auditoria real, da raiz:
```powershell
$godot = Join-Path $PWD '.tools/godot/Godot_v4.7.2-stable_win64_console.exe'
$audit = (Resolve-Path '.\tests\audit_export.gd').Path
& $godot --headless --main-pack '.\builds\windows-debug\foundation.pck' --script $audit
& $godot --headless --main-pack '.\builds\windows-release\foundation.pck' --script $audit
```
Ambos devem retornar0. Auditor específico da S0 exige filesystem virtual `PCK`, configuração/cena carregável e ausência de desenvolvimento. Ele fica fora do pack; seu contrato deve evoluir quando scripts de gameplay forem aprovados, não ser removido para aceitar recursos inesperados.

Para iniciar fora do editor, copie apenas EXE/PCK (e companion se desejado) para diretório novo e execute `foundation.exe` de lá, sem `--path`/`--editor`. Mantenha EXE e PCK juntos. Builds locais não assinadas podem gerar avisos; não desabilitar proteções do Windows.

## Evidências e limites
Suítes atuais: 146 verificações Godot e 63 dos wrappers, sem falhas; negativa deliberada retorna1. Debug/Release iniciaram em staging somente com artefatos, sem fonte/cache, encerrando0 e carregando a cena empacotada. Não é teste de gameplay, áudio, controle físico ou outra máquina.

`tests/capture_foundation.gd` salva textura direta de janela real1920×1080, sem desktop/upscale ou alteração do projeto. Tela0/borderless são configurações apenas do harness; ele mede cliente/imagem e preserva escala lógica1280×720/canvas_items. Captura em `.tools/s0/captures/task2-window-1920x1080.png`; recusa sobrescrever. Em outro host pode falhar por janela/renderer indisponível; fallback offscreen não equivale a janela1080. Inspeção desse PNG não é captura visual da build exportada.

CLI local `opencode --version`: `1.18.34`. Especialistas funcionaram pela interface atual, sem comprovar compatibilidade da configuração V2 com aquele CLI. Nenhuma atualização foi feita. Ferramenta/autenticação ausente para PR é bloqueio declarado, não PR fictício ou merge automático.
