# Coordenação de Último Sol

## Estado e fontes
Este alvo contém o projeto independente `redcap-revenants-game`, título criativo provisório Último Sol. S0 foi autorizada; gameplay e S1 ainda não. Leia `docs/CONTEXTO.md` e o próximo gate em `docs/ROADMAP.md`; GDD é fonte de produto, ART_BIBLE de direção artística e ARCHITECTURE de contratos técnicos. Não transforme hipótese em decisão aprovada.

O ambiente coordenador atual é `C:/Users/sdelgado3/OneDrive - Lenovo/Documents/aiProjects/vibe-c`. Nele, consulte por necessidade `docs/SKILLS.md`, `docs/SQUAD.md`, `docs/QUALIDADE.md`, adaptações em `docs/SUPERPOWERS.md` e a política completa `docs/VERSIONAMENTO.md` antes de editar existente ou operar Git/entregas. Este repositório não está dentro de `vibe-c/apps`; caminhos `../../docs` não se aplicam. Fonte normativa indisponível bloqueia a ação afetada; em outro computador, pedir localização, não instalar outra configuração automaticamente. Esta página não substitui essas políticas.

## Autoridade e fluxo
- Usuário decide gameplay fundamental, direção artística, escopo e início de cada sprint. O coordenador não aceita risco alto em seu nome.
- Antes da sprint revisar dependências, critérios, arquivos e decisões pendentes; detalhar somente a sprint autorizada.
- Não iniciar outra sprint sem aprovação explícita. Atualizar progresso somente com evidência verificável.
- Não instalar engine, plugins, pacotes, atualizar CLI, usar serviços pagos, enviar dados, publicar ou fazer deploy por conveniência de uma tarefa.
- Explicar brevemente decisões arquiteturais: problema, escolha, motivo, alternativa e consequência. Registrar em ARCHITECTURE e contexto quando pertinente.

## Especializações no squad existente
Não criar novos agentes/configurações por este documento. Usar os papéis existentes com recortes do domínio:
- **coordenador / Tech Lead:** planejamento, contratos, decisões registradas, evidências, continuidade e único escritor Git.
- **produto / game design:** loop, combate, progressão e critérios observáveis; recomenda, não aprova pelo usuário.
- **arquitetura / engenharia Godot:** cenas, coordenadas, contratos, estado e desempenho.
- **experiencia / direção de arte e UX:** silhueta, telegráficos, animação, HUD e acessibilidade; analisa, não gera assets finais por pressuposto.
- **implementacao / engenharia gameplay:** cenas, scripts, integração de assets e testes nos caminhos atribuídos.
- **qualidade / QA:** cenários positivos/negativos, regressões e análise das evidências executadas.
- **revisao:** parecer independente de aderência, legibilidade, defeitos e regressões.
- **operacao:** engine/CLI, importação, export, recuperação e builds reproduzíveis.
- **seguranca:** plugins, arquivos externos, saves, ferramentas e exposição de dados quando essas fronteiras aparecerem.

## Contrato de delegação e revisão
Cada chamada define objetivo verificável, fatos versus hipóteses, fonte/base, dependências, saída, critérios, comandos autorizados, arquivos exclusivos, responsável e parada. Seguir `templates/TAREFA-AGENTE.md` do ambiente coordenador; tarefa pequena pode usar contrato no próprio prompt.

Selecionar modelo/variante explicitamente por complexidade conforme a política central, não por papel. Registrar justificativa, referência solicitada, aprovação, custo desconhecido quando não medido e identidade efetiva apenas se houver metadados. Referência indisponível bloqueia dependência, sem fallback silencioso. O modelo da sessão principal permanece inalterado.

Um implementador por vez, uma sessão nova por tarefa coesa; cenas, recursos, UIDs, imports e configuração também contam como arquivos com escritor único. Coordenador escreve artefatos de coordenação, sem concorrer nos arquivos atribuídos. Só paralelizar análises independentes de base estável; sem polling. Analistas não editam, não executam shell, não delegam e não operam Git.

Antes da próxima tarefa no modo subagent-driven, exigir revisão independente de aderência e qualidade da tarefa concluída. Congelar base durante revisão. A revisão integrada final pode reutilizar pareceres identificáveis ainda válidos, mas mudanças de contrato/dependência invalidam os afetados. Reunir correções da rodada, verificar achados e revalidar. Falha de ferramenta ou falta de revisor é limitação, não aprovação.

## Disciplina de implementação e entrega
Composição, funções pequenas, GDScript tipado quando útil e dependências explícitas. Sem ECS, event bus, geradores ou frameworks preventivos. Seguir convenções de ARCHITECTURE. Toda funcionalidade deve ter forma segura de teste manual na arena/fluxo e testes automatizados pertinentes executados após implementação.

Registrar comando real, base, resultado e limitações. Headless não valida arte, áudio, controle físico ou diversão. Revisores avaliam evidências, não inventam execução. Gate de sprint exige critérios atendidos, nenhuma falha crítica/alta aberta, revisão e aceite humano pertinente. Atualizar contexto com próximo passo, não cada conversa.

Git somente pelo coordenador segundo a política central. Repositório já existente e remoto sem branches foram inspecionados. Usuário autorizou explicitamente bootstrap e primeiro push em `origin/main` após revisão/validações. Não reinicializar nem alterar remoto. Essa exceção não autoriza outros pushes para principal: tarefas futuras usam branch de tarefa/PR para base `main`, com controles normativos. Sem tags de versão funcional nesta fundação, force push ou publicação de build. Configuração de agentes do ambiente não é presumida herdada ao abrir este repositório em sessão independente; verificar disponibilidade antes de delegar.
