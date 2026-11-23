# Claude Code — project context

## Visão Geral

**TriagemAI** é um sistema de triagem automatizada com IA desenvolvido como TCC. Permite que solicitantes passem por uma triagem via chat com LLM, tenham sua urgência classificada automaticamente, aguardem validação de um colaborador e entrem em uma fila de espera gerenciada por especialistas.

## Stack

- **Backend:** Ruby on Rails 8.1, Ruby 3.3.8, PostgreSQL
- **Frontend do solicitante:** Vue 3 + Vuetify 3 + Pinia (SPA via Vite Rails), rota `/app`
- **Frontend da equipe:** ERB + Stimulus.js + CSS customizado
- **Assets:** Vite Rails (Vue) + Propshaft (ERB)
- **Tempo real:** ActionCable (WebSocket) + Solid Cable (sem Redis)
- **IA:** `AiService` suporta OpenAI (`gpt-4o-mini`) e Anthropic (`claude-opus-4-6`), seleção por `ENV["AI_PROVIDER"]`
- **Auth:** Devise — único modelo `User` com flags booleanas: `colaborador`, `specialist`, `admin`
- **Paginação:** Pagy 43.x — usar `Pagy::Offset.new(count:, page:, limit:, request:)` e `@pagy.records(collection)`. **Não usar** `include Pagy::Backend` nem `pagy()` helper (removidos na v9+)
- **i18n:** rails-i18n + `config/locales/pt-BR.yml` + `config/locales/devise.pt-BR.yml`. Locale forçado para `pt-BR` no `set_locale` do ApplicationController

## Autenticação e Perfis

- **Solicitante:** login em `/login`, rota Devise padrão. `user.patient?` → `!staff?`
- **Equipe:** login em `/staff/login` → `Staff::SessionsController` bloqueia não-staff
- **Perfis:** `user.colaborador?`, `user.specialist?`, `user.admin?`, `user.staff?`
- **Falhas de login na área da equipe** (`/staff`, `/validation`, `/attendance`, `/admin` — ex.: conta inativa)
  voltam para `/staff/login` via `StaffAwareFailureApp` (`lib/`, registrado no `config.warden` do Devise)
- **Exclusão de equipe:** quem participou de qualquer etapa de atendimento (`User#participated_in_attendance?`:
  validou, fez check-in pela recepção, chamou ou finalizou) não pode ser excluído — só desativado.
  Registrado em `queue_entries.called_by_id/finished_by_id`, `triage_sessions.checked_in_by_id` e `triage_validations.user_id`
- **Redirecionamento pós-login:** `after_sign_in_path_for` em `ApplicationController`
  - `patient?` → `/app`
  - `admin?` → `edit_admin_triage_setting_path`
  - `colaborador?` → `validation_root_path`
  - `specialist?` → `attendance_root_path`

## Rotas Principais

```ruby
# Solicitante (Devise)
/login           → new_user_session
/register        → new_user_registration

# Equipe (Devise customizado)
/staff/login     → staff/sessions#new / create
/staff/logout    → staff/sessions#destroy

# SPA Vue do solicitante
GET /app         → patient_app#index  (serve o SPA)
GET /app/*path   → patient_app#index

# API JSON para Vue
GET  /api/session
POST /api/triage/start
GET  /api/triage/status
GET  /api/triage/messages
POST /api/triage/message
POST /api/triage/finish
POST /api/triage/restart
GET  /api/queue              ← fila atual, já ordenada por urgência + prioridade (Pagy::Offset não usado aqui)
GET  /api/profile            ← dados do perfil do paciente (inclui campos de prioridade)
PATCH /api/profile           ← atualiza perfil do paciente (nome, contato, prioridade, senha)

# Validação (colaborador)
/validation      → validation/panel#index
/validation/triage_validations/new
/validation/queue_entries/:id/call
/validation/queue_entries/:id/finish
/validation/reports  ← filtros: period (today/week/month) ou date_from/date_to (só date_from = dia específico), staff_id

# Atendimento (especialista)
/attendance      → attendance/panel#index
/attendance/attendances/:id   ← inclui "Histórico do atendimento" (AttendanceTimeline: quem fez cada etapa)
/attendance/attendances/:id/finish

# Admin
/admin/triage_setting/edit
/admin/users     → CRUD de equipe

# TV pública
/tv              → tv#show (sem autenticação)
```

## Models Principais

### User
```ruby
devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :trackable
# Flags: colaborador (boolean), specialist (boolean), admin (boolean), active (boolean)
# staff? = colaborador? || specialist? || admin?
# patient? = !staff?

# Prioridade legal na fila (Lei 10.048/2000 + Estatuto do Idoso — ver seção "Fila Prioritária"):
# age / elderly? (60+) / super_elderly? (80+)  → calculados a partir de birth_date, não é campo
# pcd, obeso, mobilidade_reduzida              → condições permanentes, boolean simples
# gestante/lactante/crianca_de_colo            → boolean + *_valid_until (data de validade obrigatória
#                                                 quando a flag está true; valida "não pode ser passado")
# priority_reasons → array de símbolos ativos agora (ex: [:pcd, :gestante])
# priority_tier    → 0 (nenhuma) | 1 (prioridade legal) | 2 (superprioridade, só idoso 80+)
```

### TriageSession
```ruby
# status enum: in_triage, awaiting_checkin, awaiting_validation, validated, in_queue, in_attendance,
#              completed, cancelled, expired (triagem sem check-in no prazo)
# checked_in_at / #checkin_deadline — check-in presencial (TriageSetting#require_checkin)
belongs_to :user
has_one :ai_classification
has_one :queue_entry
has_many :chat_messages
```

### QueueEntry
```ruby
# ticket_number: string único (ex: "SYZ99G5JC")
# urgency_level: enum (red, orange, yellow, green, blue)
# status: waiting, called, in_attendance, left, completed
# priority_tier / priority_reasons: SNAPSHOT do User#priority_tier/priority_reasons no momento do
#   enqueue (QueueEntryService) — não recalcula depois, então mudanças no perfil do paciente não
#   afetam quem já está esperando na fila
# scope ordered_for_queue: order(:urgency_weight).order(priority_tier: :desc).order(:queued_at)
#   → urgência clínica sempre manda primeiro; prioridade só desempata dentro do mesmo nível
# queue_position: calculado via SQL usando a mesma regra de ordered_for_queue (não armazenado)
# self.average_service_minutes: média real dos últimos 50 atendimentos concluídos
#   (called_at → service_finished_at); cai em DEFAULT_SERVICE_MINUTES (15) sem histórico
```

### TriageSetting
```ruby
# Singleton — TriageSetting.current
# urgency_label_for(level), urgency_color_for(level), urgency_weight_for(level)
# system_prompt configurável pelo admin
```

## Services

### AiService
- `AiService.new(session).call(messages)` → resposta do LLM
- `AiService.new(session).classify(transcript)` → hash com urgency_level, summary, etc.
- Suporta OpenAI e Anthropic, selecionado por `ENV["AI_PROVIDER"]`

### TriageService
- `TriageService.new(session).process_message(content)` → processa mensagem do usuário, salva chat, retorna resposta IA
- `TriageService.new(session).finalize_triage` → classifica, cria AiClassification e avança conforme `TriageSetting#require_staff_validation`:
  `true` (padrão) → status `awaiting_validation`, espera o colaborador validar; `false` → já chama `QueueEntryService#enqueue`
  com a urgência da IA (status `in_queue`). Com `TriageSetting#require_checkin`, para antes em `awaiting_checkin`
  e só avança em `TriageService#check_in!` (código de `CheckinCode` digitado no app via `POST /api/triage/checkin`,
  ou recepção via `Validation::CheckinsController`). O código rotativo só aparece na `/tv` de um navegador
  autorizado pela equipe (`POST /tv/activate`, cookie assinado `tv_device`). `TriageSetting#specialist_review_enabled` permite ao especialista criar a
  `TriageValidation` depois, na tela de atendimento (`Attendance::AttendancesController#review_classification`)

### QueueEntryService
- `QueueEntryService.new(triage_session).enqueue` → gera ticket, tira snapshot de `priority_tier`/`priority_reasons` do paciente, cria QueueEntry, broadcast via QueueChannel. Urgência = `validation.final_urgency_level` se houver validação, senão a da `AiClassification`

## Fila Prioritária (Lei 10.048/2000 + Estatuto do Idoso)

A fila combina **urgência clínica** (Protocolo Manchester) com **prioridade legal de atendimento**.
Urgência sempre manda primeiro; prioridade só desempata dentro do mesmo nível de urgência.

- **Onde o paciente declara:** cadastro (`/register`) e perfil (`/app/profile` → `ProfileEdit.vue`).
  Nunca mais no início da triagem (checkbox removido).
- **Condições permanentes** (checkbox simples): `pcd` (inclui TEA), `obeso`, `mobilidade_reduzida`.
- **Idoso:** automático via `birth_date` — `User#elderly?` (60+) e `User#super_elderly?` (80+,
  subprioridade do Estatuto da Pessoa Idosa). Sem campo/checkbox próprio.
- **Condições temporárias** (`gestante`, `lactante`, `crianca_de_colo`): checkbox + campo
  "válido até" que o próprio paciente preenche. Passado esse prazo a condição para de contar
  sozinha — não existe expiração automática por tempo fixo, é a data informada pelo paciente.
  Validado em `User#validate_temporary_priority_dates` (obrigatório e não pode ser passado)
  e no client-side (Vuetify rules / atributo `min` no `date_field` do ERB).
- **UI do checkbox → data:** `toggle_field_controller.js` (Stimulus, usado no ERB de cadastro)
  e `v-if`/`v-expand-transition` (Vue, no `ProfileEdit.vue`) revelam o campo de data só quando
  a condição é marcada, e limpam o valor ao desmarcar.
- **`User#priority_tier`**: 0 (nenhuma) · 1 (qualquer condição acima ativa) · 2 (só idoso 80+).
- **Snapshot no enqueue:** `QueueEntryService#enqueue` grava `priority_tier`/`priority_reasons`
  na `QueueEntry` no momento em que o paciente entra na fila — mudanças posteriores no perfil não
  reordenam quem já está esperando.
- **Ordenação:** `QueueEntry.waiting_ordered_with_aging` (usado também por `QueueEntry#queue_position`)
  ordena em Ruby por `effective_urgency_weight ASC, urgency_weight ASC, priority_tier DESC, queued_at ASC`.
  O peso efetivo sobe um nível a cada janela de SLA estourada (até o nível mais urgente); a urgência
  original no desempate garante que um caso envelhecido nunca passe na frente de quem é daquele nível de verdade.
- **Tempo estimado:** `QueueEntry.average_service_minutes` — média real dos atendimentos recentes
  (`called_at` → `service_finished_at`), não mais um valor fixo.
- **Exibição:** `Api::QueueController#index` (fila do paciente) e `Validation::PanelController`
  (painel do colaborador, com badge tipo "★ Idoso (80+)" ou "★ PCD, Gestante") usam a mesma
  ordenação. Nome do paciente aparece completo em todos os lugares (TV, painel, fila do app) —
  a máscara de nome (`mask_name`) foi removida.

## ActionCable Channels

| Channel | Stream | Quem usa |
|---|---|---|
| `TriageChannel` | `triage_session_{id}` | Vue SPA (chat em tempo real) |
| `QueueChannel` | `queue_session_{id}` | Vue SPA (posição na fila, chamada) |
| `ValidationPanelChannel` | `validation_panel` | Painel do colaborador (Stimulus) |
| `TvChannel` | `tv_global` | TV pública (sem autenticação) |

Broadcasts:
- `QueueChannel.broadcast_queued(session, entry)` → evento `queued`
- `QueueChannel.broadcast_position_update(session, entry)` → evento `position_update`
- `QueueChannel.broadcast_called(session, entry)` → evento `called`
- `ValidationPanelChannel.broadcast_update` → evento `panel_update`
- `TvChannel.broadcast_update` → lista de chamados
- `TvChannel.broadcast_call(entry)` → novo chamado em destaque

## Frontend Vue (SPA)

Localização: `app/javascript/patient/`

```
App.vue              → Layout, navbar, logout, dialog "outra triagem"
router/index.js      → Guards: redireciona para etapa correta por status
stores/triage.js     → Pinia store: session, messages, sending, fetchStatus, sendMessage...
composables/
  useApi.js          → apiFetch() com CSRF token automático
  useCable.js        → useTriageChannel(id), useQueueChannel(id, { onQueueUpdate })
views/
  TriageStart.vue    → Formulário de demanda inicial
  TriageChat.vue     → Chat com scroll, indicador de digitação, botão finalizar
  TriageQueue.vue    → Senha, urgência, posição, fila geral, tela de chamada
  profile/ProfileEdit.vue → Dados pessoais, senha, e condições de prioridade da fila
```

**Importante sobre `useQueueChannel`:** aceita `{ onQueueUpdate }` callback — chamado nos eventos `queued`, `position_update` e `called` para recarregar a lista da fila via `/api/queue`.

## Helpers (ApplicationHelper)

```ruby
urgency_label(level)          # "Emergência", "Muito Urgente", etc.
urgency_color(level)          # "#c53030", "#dd6b20", etc.
urgency_badge_style(level)    # "background: #c53030; color: #fff;"
urgency_soft_style(level)     # versão com alpha para fundos suaves
```

Todos delegam para `TriageSetting.current`.

## i18n

- Locale sempre `pt-BR` (forçado em `ApplicationController#set_locale`)
- Chaves da aplicação em `config/locales/pt-BR.yml` sob `app.*`
- Enums traduzidos em `enums.*` no mesmo arquivo
- Devise em `config/locales/devise.pt-BR.yml`

## Padrões de Código

- Controllers de equipe herdam de `Admin::BaseController`, `Validation::BaseController` ou `Attendance::BaseController` — cada um chama o `require_*!` correspondente
- `Api::BaseController` autentica via sessão Devise (`before_action :authenticate_user!`)
- Urgência nunca é hardcoded — sempre via `TriageSetting.current`
- Cobertura de testes: `COVERAGE=1 bin/rails test` (SimpleCov, relatório em `coverage/index.html`, ignorado pelo git)
- O indicador do relatório chama-se "Concordância IA × equipe" (não "precisão"): mede concordância, não acurácia clínica.
  O `confidence_score` da IA é autoavaliação do modelo — não pôr valor numérico de exemplo no prompt de classificação (o modelo copia)
- Paginação: **sempre** usar `Pagy::Offset.new(count:, page:, limit:, request:)` + `@pagy.records(collection)` — **nunca** `include Pagy::Backend` ou `pagy()` helper
- Prioridade da fila é *snapshot* na `QueueEntry` no momento do enqueue (`QueueEntryService`), nunca recalculada a partir do `User` depois — se for tocar em ordenação de fila, mexer em `QueueEntry.ordered_for_queue`/`queue_position`, não recalcular `priority_tier` do usuário em tempo real

---

<!-- cloude-code-toolbox:mcp-skills-awareness-begin -->

### MCP & Skills awareness (Cloude Code ToolBox)

_Last synced: 2026-04-06T00:58:53.256Z._

- **Full report:** `.claude/cloude-code-toolbox-mcp-skills-awareness.md` in this workspace (auto-overwritten on each scan). Use it as ground truth for configured servers and skill folders.
- **MCP:** For **live tools** in Claude Code, enable the matching server via `/mcp` (and VS Code `mcp.json` where applicable).
- **When the user's task matches a server** (e.g. Confluence work and a **Confluence** / **Atlassian** MCP is listed), **prefer that server id** and plan on tool use—not only file search.
- **Skills:** Folders below contain `SKILL.md`; attach or cite paths in chat when relevant.

#### Workspace MCP

- `/home/luvieira/projects/projeto_tcc/.vscode/mcp.json` _(workspace: projeto_tcc)_ — _file missing_

_No active workspace servers in mcp.json._

#### User MCP

- `/home/luvieira/.config/Code/User/mcp.json` — _file missing_

_No active user-scoped servers in mcp.json._

#### Project skills

_None found (or no workspace open)._

#### User skills

_None found._

<!-- cloude-code-toolbox:mcp-skills-awareness-end -->
