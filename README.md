# Último Sol — redcap-revenants-game

Roguelike de ação 2D com aparência isométrica e ambientação em um apocalipse urbano brasileiro. “Último Sol” é o título criativo provisório; o nome deste repositório não representa mudança automática da direção aprovada.

## Estado
Planejamento global aprovado. S0 (fundação sem gameplay) autorizada e implementada parcialmente: cena de diagnóstico, configuração e testes disponíveis. S1–S7 ainda dependem de aprovação própria. Não há gameplay ou build exportada entregue neste estágio. Exportação e aceite completo de S0 continuam pendentes.

## Documentação
- [GDD](docs/GDD.md): visão, pilares, escopo e decisões de produto.
- [Arquitetura](docs/ARCHITECTURE.md): contratos técnicos, alternativas e convenções.
- [Roadmap](docs/ROADMAP.md): sprints, testes e critérios de aceite.
- [Art bible](docs/ART_BIBLE.md): direção visual, produção e licenciamento.
- [Agentes](AGENTS.md): delegação, revisão e limites.
- [Contexto](docs/CONTEXTO.md): estado real e próximo passo.
- [Plano S0](docs/superpowers/plans/2026-10-27-s0-fundacao.md): execução autorizada e evidências.

## Ferramentas
Godot **4.7.2.stable.official.ed1daf0bf**, edição padrão Windows x86_64, GDScript e Compatibility. Distribuição portátil autorizada em `.tools/godot/`, fora do Git; não há alteração de PATH. Não baixar templates de exportação, plugins ou atualizar OpenCode sem autorização pertinente.

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
