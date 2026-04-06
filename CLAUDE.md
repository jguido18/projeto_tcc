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
GET  /api/queue              ← lista anonimizada da fila (Pagy::Offset não usado aqui)

# Validação (colaborador)
/validation      → validation/panel#index
/validation/triage_validations/new
/validation/queue_entries/:id/call
/validation/queue_entries/:id/finish
/validation/reports

# Atendimento (especialista)
/attendance      → attendance/panel#index
/attendance/attendances/:id
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
```

### TriageSession
```ruby
# status enum: in_triage, awaiting_validation, validated, in_queue, in_attendance, completed, cancelled
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
# queue_position: calculado via SQL (não armazenado)
def queue_position
  QueueEntry.where(status: :waiting)
             .where("urgency_weight < ? OR (urgency_weight = ? AND queued_at <= ?)", ...)
             .count + 1
end
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
- `TriageService.new(session).finalize_triage` → classifica, cria AiClassification, muda status para `awaiting_validation`

### QueueEntryService
- `QueueEntryService.new(validation).call` → gera ticket, cria QueueEntry, broadcast via QueueChannel e ValidationPanelChannel

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
- Paginação: **sempre** usar `Pagy::Offset.new(count:, page:, limit:, request:)` + `@pagy.records(collection)` — **nunca** `include Pagy::Backend` ou `pagy()` helper

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
