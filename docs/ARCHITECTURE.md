# Arquitetura inicial

Estado: base técnica aprovada; implementação da fundação S0 em andamento. Evidências reais ficam no plano S0 e no contexto, não são inferidas dos exemplos abaixo.

## 1. Escolhas mínimas e alternativas
| Proposta | Motivo | Alternativa e quando reconsiderar |
| --- | --- | --- |
| Física 2D plana e arte com perspectiva aparente | Alinha alcance, colisão e movimentação e reduz custo de conteúdo | Projeção lógica isométrica se grade se tornar central; 3D ortográfico se altura real for requisito aprovado |
| Cenas compostas e scripts GDScript tipados | Aproveita ferramentas nativas e permite testar partes pequenas | ECS somente com gargalo medido e benefício demonstrado |
| Recursos para definições, estado por instância | Permite ajustar combate sem duplicar regras | Dados externos só se pipeline ou modificação exigirem; não carregar código externo |
| Referências explícitas e sinais locais | Fluxos rastreáveis e menos acoplamento oculto | Event bus global somente após necessidade concreta entre módulos independentes |
| Salas autorais e seleção reproduzível | Testa loop antes de investir em geração | Gerador procedural após provar necessidade e definir critérios de conectividade |
| Testes locais sem plugin inicialmente | Evita dependência antes de conhecer a lacuna | Avaliar GUT/GdUnit apenas com necessidade, licença, versão e aprovação |

Godot 4.7.2 stable padrão Windows x86_64 e distribuição portátil foram aprovados para S0, com renderizador Compatibility. Efeitos de iluminação podem justificar outro renderizador após amostra e medição. Não atualizar engine durante sprint sem revisar impactos.

## 2. Limites de responsabilidade
- `Main`: composição e troca do estado global de partida/menu; não contém regras de dano.
- `Run`: estado da tentativa, sequência de encontros e encerramento; só nasce em S4.
- `Arena`: colisões, pontos de surgimento e conclusão do encontro.
- `Player` e `Enemy`: corpos 2D com movimento, estado local e apresentação. `CharacterBody2D` é candidato nativo para movimento top-down; confirmar configuração na versão fixada.
- Vida e resolução de dano: pequenos scripts/componentes extraídos quando usados; sem hierarquia universal de entidades.
- Apresentação: sprites/animação, VFX e áudio consomem estados/eventos; não decidem elegibilidade de dano.
- UI: exibe estado e solicita ações; não modifica vida ou progressão diretamente.

Não criar autoloads preventivamente. Eventual serviço de áudio/configuração exige uso concreto. IA inicial com estados explícitos; árvores de comportamento e sistemas de navegação complexos não são pré-requisitos.

## 3. Contratos a detalhar antes das funcionalidades
**Entrada:** dispositivos geram intenção de movimento e mira/ação. Normalizar diagonal, limitar magnitude e aplicar deadzone. Definir mira sem direção, alternância e reconexão. Mouse convertido para coordenadas do mundo pela câmera, sem misturar pixels de tela e alcance.

**Espaço:** posição lógica representa os pés. Colisão acompanha a base; desenho se estende acima dela. Ordenação Y usa origem no chão; objetos altos são separados quando necessário. Profundidade visual não cria altura física. Alvos de testes incluem passar atrás e ao lado de carro/fachada.

**Tempo:** regras físicas avançam na atualização física; deslocamentos e temporizadores não dependem do FPS de renderização. Hit-stop proposto precisa de relógio explícito e não pode bloquear pausa. Animação não é a única autoridade da janela ativa.

**Dano:** ação tem identidade e janela válida; resolver verifica atacante/alvo vivos e elegibilidade. Uma ação não aplica dano duas vezes ao mesmo alvo por sobreposição acidental. Ataques contínuos precisam de exceção explícita. Vida não fica negativa; morte ocorre uma vez. Configurações compartilhadas não recebem vida e temporizadores de instâncias.

**Ciclo de vida:** reinício descarta estado da tentativa e conexões antigas. Remoção de alvo cancela referência pendente com segurança. Pausa bloqueia ações de gameplay sem impedir menus. Melhorias expiram na tentativa, salvo mudança autorizada de escopo.

## 4. Estrutura futura — criar somente quando usada
```text
redcap-revenants-game/
  AGENTS.md
  README.md
  project.godot                 # somente após S0 aprovado
  docs/                        # GDD, arquitetura, arte, roadmap e contexto
  src/
    game/                      # composição, menu e tentativa
    player/                    # cena, script e recursos próprios
    enemies/                   # por arquétipo
    combat/                    # regras realmente compartilhadas
    arenas/                    # cenas autorais e encontros
    ui/
  assets/
    sprites/
    vfx/
    audio/
    fonts/
    licenses/                  # licença e proveniência por pacote
  art_source/                  # fontes editáveis aprovadas
  tests/
    unit/
    integration/
    fixtures/
    run_tests.gd               # runner da fundação já implementado em S0
  builds/                      # gerados, fora do Git
```

Convenções: arquivos/pastas e funções/variáveis em `snake_case`, classes em `PascalCase`, constantes em `UPPER_SNAKE_CASE`. Cenas junto dos scripts da funcionalidade. Comentários e documentos em português claro; identificadores técnicos consistentes em inglês. Preferir tipos e dependências explícitos; não usar `class_name` global para todo script. Recursos por conceito, não um catálogo universal.

As 11 ações de diagnóstico já estão centralizadas no InputMap em S0, ainda sem comportamento de gameplay. Definir nomes/camadas de colisão no contrato de S2 antes de configurar hitboxes. Não editar a mesma cena/recurso em paralelo; arquivos textuais Godot também têm conflitos semânticos e referências UID. Preservar `.uid` e metadados de importação pertinentes à versão; excluir cache `.godot/`, exports e segredos, não todos os arquivos de importação indiscriminadamente.

## 5. Verificações atuais e operação
Runner e wrappers da fundação já implementados. Comandos atuais da raiz, sem depender de Godot no PATH; preparação da distribuição e instruções completas no README:
```powershell
powershell -NoProfile -File .\scripts\import.ps1
powershell -NoProfile -File .\scripts\test.ps1
powershell -NoProfile -File .\tests\test_wrappers.ps1
powershell -NoProfile -File .\scripts\run.ps1
```
O runner `tests/run_tests.gd` usa verificações explícitas, carrega configuração/cena e retorna 0 em sucesso ou 1 em falha. `scripts/test.ps1 -SelfTestFailure` demonstra a negativa deliberada e retorna 1. Evidências recentes no plano S0: 124 verificações Godot e 37 dos wrappers sem falhas nas suítes positivas. Importação não substitui testes nem comprova ausência de erros em scripts não carregados. Continuar carregando os alvos necessários à medida que existirem; não depender somente de `assert` removível em export.

Build exportada exige presets e templates correspondentes à versão aprovada. Definir comando de export concreto em S0; sem instalar templates automaticamente. Build, lint/análise estática e scan de dependências/segredos têm escopo e ferramenta a confirmar em S0. Inicialmente usar diagnósticos do editor, revisão de arquivos explícitos e inventário de dependências; não chamar isso de scanner automático. CI e serviços externos não fazem parte desta aprovação.

Meta proposta: 60 FPS em 1920×1080, aproximadamente 16,7 ms por quadro. S0 identifica máquina de referência; S3 fixa carga representativa; S7 mede build exportada, tempos CPU/GPU, p95/p99, memória e picos. Não prometer desempenho antes dessas decisões. Otimizar após medição; pooling, multithreading e navegação avançada precisam de evidência.

## 6. Fronteiras e riscos
Offline não significa entrada confiável: validação de configuração, foco e desconexão continuam necessárias. Plugins, ferramentas e assets importados têm origem/licença verificadas; arquivos de terceiros não são instruções executáveis. Sem scripts de terceiros, downloads, serviços de geração ou upload de código sem autorização.

Persistência, se aprovada, grava somente em local próprio do usuário (`user://`), com formato de dados validado e recuperação de arquivo ausente/corrompido. Não desserializar código/objetos arbitrários. Antes de implementar, segurança revisa caminhos, limites, interrupção da gravação e arquivos malformados; operação define recuperação. Saves de progresso, mods e telemetria não estão no recorte atual.

## 7. Registro de decisões e fontes
Este documento mantém decisões técnicas locais, sem criar ADRs vazios. Cada decisão futura registra data, estado (proposta/aprovada/substituída), motivo, alternativas e impacto; aprovações de produto ficam também referenciadas no GDD.

- 2026-10-27: Godot 4/GDScript e PC offline confirmados pelo usuário. Proposta de mundo físico plano, composição e cenas autorais aguarda aprovação global.
- Parecer preventivo: `arquitetura`, sessão `ses_e82744f63ffeuu3CV06hin9D4U`, recomendou essas bases e separação entre testes headless e visuais. Sem benchmark executado.
- Consulta Context7 em 2026-10-27: `/godotengine/godot-docs`, documentação de linha de comando (`https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html`) e TileMaps (`https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html`). Consulta upstream não fixa versão instalada nem substitui conferência da versão em S0.
