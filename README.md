# TriagemAI — Sistema de Triagem Automatizada com Inteligência Artificial

> Projeto de TCC — Sistema de triagem universal com IA para hospitais, clínicas, secretarias e comércios. Desenvolvido com Ruby on Rails 8, Vue 3 e integração com modelos de linguagem (LLM).

---

## Sobre o Projeto

O **TriagemAI** é uma plataforma web que digitaliza e automatiza o processo de triagem de atendimentos. Um assistente de IA conduz o solicitante por uma conversa estruturada, coleta informações relevantes e classifica o nível de urgência com base no Protocolo Manchester. Um colaborador humano valida a classificação antes de inserir o solicitante na fila de espera. O especialista então realiza o atendimento e finaliza o chamado.

O sistema é totalmente configurável: o administrador define o prompt da IA, os níveis de urgência, pesos e cores diretamente pelo painel.

---

## Fluxo Completo do Sistema

```
[Solicitante]
     │
     ▼
  Login → /login
     │
     ▼
  Informa demanda inicial (/app)
     │
     ▼
  Chat com IA de triagem (/app/chat)
  └── IA faz perguntas baseadas no protocolo configurado
  └── Coleta sintomas, duração, intensidade, etc.
     │
     ▼
  IA classifica urgência e finaliza triagem
     │
     ▼
  Status: "Aguardando validação"
     │
[Colaborador] recebe no painel de validação (/validation)
     │
     ▼
  Revisa análise da IA → Confirma ou ajusta classificação
     │
     ▼
  Solicitante entra na fila com senha e urgência confirmada (/app/queue)
     │
[Especialista] vê fila de chamados (/attendance)
     │
     ▼
  Chama solicitante → Solicitante recebe alerta em tempo real
     │
     ▼
  Especialista realiza atendimento e finaliza
```

---

## Perfis de Usuário

| Perfil | Rota de Login | Acesso |
|---|---|---|
| **Solicitante** | `/login` | Chat com IA, acompanhamento de fila, senha de atendimento |
| **Colaborador** | `/staff/login` | Painel de validação, gestão de fila, relatórios, histórico |
| **Especialista** | `/staff/login` | Painel de atendimento, detalhes de triagem, finalização |
| **Admin** | `/staff/login` | Configuração da IA, cadastro de equipe, painel geral |

---

## Funcionalidades Implementadas

### Autenticação
- [x] Login separado para solicitantes (`/login`) e equipe (`/staff/login`)
- [x] Cadastro de solicitantes com nome, CPF, data de nascimento, telefone e condições de prioridade
- [x] Dois perfis de equipe na mesma tabela (`colaborador`, `specialist`, boolean flags)
- [x] Redirecionamento automático pós-login de acordo com o perfil

### Fluxo do Solicitante (Vue 3 SPA — `/app`)
- [x] Tela de início de triagem com campo de demanda inicial
- [x] Chat em tempo real com IA via ActionCable (WebSocket)
- [x] Indicador de digitação ("...") enquanto a IA responde
- [x] Botão "Finalizar Triagem" para encerrar o chat e enviar para validação
- [x] Tela de fila com senha, urgência, posição e tempo estimado (calculado pela média real dos últimos atendimentos)
- [x] Painel de fila geral com todos os solicitantes aguardando, nome completo e selo de prioridade (★)
- [x] Notificação em tempo real quando chamado ("Dirija-se ao ponto de atendimento")
- [x] Possibilidade de iniciar outra triagem (cancela a atual)
- [x] Guard de rotas: redireciona para a etapa correta conforme status da sessão
- [x] Tela de perfil (`/app/profile`) com dados pessoais, troca de senha e condições de prioridade na fila

### Inteligência Artificial
- [x] Integração com OpenAI (`gpt-4o-mini`) e Anthropic (`claude-opus-4-6`)
- [x] Seleção automática de provedor por variável de ambiente (`AI_PROVIDER`)
- [x] Prompt do sistema configurável pelo administrador
- [x] Classificação de urgência por nível (vermelho, laranja, amarelo, verde, azul)
- [x] Resumo clínico, raciocínio da classificação e sugestão de encaminhamento
- [x] Identificação de sintomas e referência ao protocolo de urgência

### Painel do Colaborador — Validação (`/validation`)
- [x] Coluna "Aguardando Validação" com cartões das triagens pendentes
- [x] Coluna "Fila Prioritária" com solicitantes validados ordenados por urgência clínica e prioridade legal (idosos, PCD, gestantes...)
- [x] Modal de validação: revisa análise da IA e confirma ou ajusta prioridade
- [x] Botão "Chamar Atendimento" que notifica o solicitante em tempo real
- [x] Atualização automática do painel via ActionCable
- [x] Relatórios do dia (triagens, atendimentos, precisão da IA)
- [x] Histórico com filtros por gravidade e busca por nome

### Fila Prioritária (Lei 10.048/2000 + Estatuto do Idoso)
- [x] Ordenação em duas camadas: **urgência clínica sempre em primeiro lugar** (Protocolo Manchester); a prioridade legal só decide quem passa na frente **dentro do mesmo nível de urgência**
- [x] Idosos (60+) identificados automaticamente pela data de nascimento — sem precisar marcar nada
- [x] Superprioridade automática para idosos 80+ (Estatuto da Pessoa Idosa), acima da prioridade "comum"
- [x] Condições permanentes autodeclaráveis no cadastro/perfil: PCD (inclui TEA), obesidade, mobilidade reduzida
- [x] Condições temporárias com data de validade informada pelo próprio paciente — gestante, lactante e criança de colo deixam de contar automaticamente após a data informada, sem precisar desmarcar
- [x] Validação de data: o campo "válido até" não pode ficar em branco nem ser uma data passada
- [x] Nome completo do paciente exibido na fila, na TV pública e no painel do colaborador (sem censura)
- [x] Painel do colaborador mostra o motivo da prioridade em cada solicitante (ex: "★ Idoso (80+)", "★ PCD, Gestante")
- [x] Tempo estimado de espera calculado pela média real dos atendimentos concluídos, não mais um valor fixo
- [x] **Envelhecimento dinâmico de prioridade** — cada nível de urgência tem um SLA configurável (minutos até a chamada); se estourado, o peso de ordenação sobe automaticamente até empatar com o nível mais urgente, evitando que alguém de baixa urgência espere indefinidamente enquanto casos mais graves continuam chegando
- [x] Alerta visual de "SLA estourado" no painel do colaborador, atualizado a cada minuto (job recorrente via Solid Queue) sem precisar recarregar a página

### Confiança e Segurança da Classificação da IA
- [x] Limite de confiança configurável pelo admin — quando a IA classifica abaixo dele (ou não informa confiança), a validação é sinalizada para revisão com atenção redobrada
- [x] Aviso destacado na tela de validação e badge no painel quando a confiança está baixa
- [x] Relatório de precisão da IA detalha a **direção** dos erros: subtriagem (IA subestimou a urgência — erro perigoso) vs. sobretriagem (IA superestimou — erro do lado seguro)

### Notificação por SMS
- [x] Paciente pode optar, no cadastro ou no perfil, por receber um aviso por SMS quando for chamado (além da notificação em tempo real já existente no app) — telefone passa a ser obrigatório enquanto essa opção estiver ativa
- [x] Envio assíncrono via textbee — celular Android como gateway de SMS (job em background, nunca bloqueia a ação do colaborador)
- [x] Sem a API key do textbee configurada, o envio é simulado em log, sem quebrar o fluxo

### Painel do Especialista — Atendimento (`/attendance`)
- [x] Lista de solicitantes chamados aguardando atendimento
- [x] Tela de detalhes: demanda inicial, sugestão da IA, resumo, raciocínio
- [x] Transcrição completa do chat de triagem
- [x] Botão "Finalizar Atendimento" com confirmação
- [x] Cabeçalho com identificação visual por nível de urgência (cor + borda)

### Painel Administrativo (`/admin`)
- [x] Configuração do sistema de triagem (prompt da IA, nome, níveis de urgência)
- [x] Cadastro, edição e remoção de membros da equipe (colaboradores e especialistas)
- [x] Paginação da listagem de equipe via Pagy

### TV Pública de Fila (`/tv`)
- [x] Tela de chamada sem autenticação
- [x] Lista de solicitantes sendo chamados com urgência e horário
- [x] Destaque animado para a chamada mais recente
- [x] Atualização em tempo real via ActionCable

### Tempo Real (ActionCable / WebSocket)
- [x] `TriageChannel` — mensagens e mudanças de status do chat
- [x] `QueueChannel` — posição na fila, chamada, entrada na fila
- [x] `ValidationPanelChannel` — atualização do painel do colaborador
- [x] `TvChannel` — chamadas na TV pública

### API JSON (para o SPA Vue)
- [x] `GET /api/session` — dados da sessão autenticada
- [x] `POST /api/triage/start` — inicia nova triagem
- [x] `GET /api/triage/status` — status e dados da triagem ativa
- [x] `GET /api/triage/messages` — histórico de mensagens
- [x] `POST /api/triage/message` — envia mensagem e recebe resposta da IA
- [x] `POST /api/triage/finish` — finaliza triagem manualmente
- [x] `POST /api/triage/restart` — cancela triagem ativa
- [x] `GET /api/queue` — fila atual ordenada por urgência e prioridade (para o painel Vue)
- [x] `GET/PATCH /api/profile` — dados do perfil, incluindo as condições de prioridade na fila

---

## Stack de Tecnologia

| Camada | Tecnologia |
|---|---|
| Backend | Ruby on Rails 8.1 + Ruby 3.3.8 |
| Banco de dados | PostgreSQL |
| Autenticação | Devise (único modelo `User` com flags booleanas de perfil) |
| Frontend do solicitante | Vue 3 + Vuetify 3 + Pinia + Vue Router (SPA via Vite) |
| Frontend da equipe | ERB + Stimulus.js + CSS customizado |
| Assets | Vite Rails (frontend Vue) + Propshaft (assets Rails) |
| Tempo real | ActionCable (WebSocket) + Solid Cable |
| Background jobs | Solid Queue |
| Cache | Solid Cache |
| IA | Anthropic Claude (`claude-opus-4-6`) / OpenAI (`gpt-4o-mini`) |
| Paginação | Pagy 43.x (API `Pagy::Offset`) |
| Internacionalização | rails-i18n + locale customizado `pt-BR.yml` |
| Deploy | Kamal + Thruster + Puma |

---

## Configuração do Ambiente

### Pré-requisitos

- Ruby 3.3.8 (via asdf ou rbenv)
- PostgreSQL 14+
- Node.js 20+
- npm 10+

### Instalação

```bash
# Clonar o repositório
git clone git@github.com:jguido18/projeto_tcc.git
cd projeto_tcc

# Instalar dependências Ruby e Node
bundle install
npm install

# Configurar banco de dados
rails db:create db:migrate

# Popular dados iniciais (usuário admin, configuração padrão de triagem)
rails db:seed

# Subir o servidor (Rails + Vite em paralelo)
bin/dev
```

### Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto:

```env
# Provedor de IA (anthropic ou openai)
AI_PROVIDER=anthropic

# Chave da API Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Chave da API OpenAI (alternativa)
OPENAI_API_KEY=sk-...

# Opcional — envio de SMS quando o paciente é chamado (textbee)
TEXTBEE_API_KEY=...
TEXTBEE_DEVICE_ID=...  # opcional, só se tiver mais de um dispositivo vinculado
```

Sem `TEXTBEE_API_KEY`, o sistema funciona normalmente — o envio de SMS só é
simulado (registrado no log) em vez de disparado de verdade.

> **Por que textbee e não uma operadora tipo Twilio/Zenvia?** Testamos as duas
> — contas trial do Twilio (WhatsApp e SMS) só aceitam mensagens de templates
> pré-aprovados, não texto livre customizado, e liberar isso exige conta paga.
> O [textbee](https://textbee.dev) ([open source](https://github.com/textbee/textbee))
> usa um celular Android real como gateway — o SMS sai como se você tivesse
> mandado manualmente, sem essa restrição, e é gratuito (até 300 SMS/mês). A
> arquitetura (`SmsNotifierService`, `NotificationDeliveryJob`, opt-in no
> perfil) é a mesma que serviria pra qualquer provedor — só troca a
> implementação interna do service.

### Configurar o SMS de demonstração (textbee)

1. Instale o app do textbee num celular **Android** (não funciona em iPhone —
   o iOS não permite apps terceiros mandarem SMS sem confirmação manual).
2. Crie uma conta em [textbee.dev](https://textbee.dev), gere uma API key no
   painel e coloque em `TEXTBEE_API_KEY`.
3. No app, escaneia o QR code do painel pra vincular o celular à sua conta —
   ele precisa ficar ligado, com internet e o app aberto (ou rodando em
   segundo plano) na hora de cada teste/demonstração.
4. No perfil do paciente de teste (`/app/profile`), cadastre o telefone dele
   e ative "Avisar por SMS quando eu for chamado".
5. Chame o paciente pelo painel de validação (`/validation`) — o SMS chega
   pelo chip do celular vinculado.

### Criar usuário de teste via console

```ruby
# Admin
User.create!(name: "Admin", email: "admin@teste.com", password: "123456",
             password_confirmation: "123456", admin: true, active: true)

# Colaborador
User.create!(name: "Colaborador", email: "colab@teste.com", password: "123456",
             password_confirmation: "123456", colaborador: true, job_title: "Recepcionista", active: true)

# Especialista
User.create!(name: "Especialista", email: "esp@teste.com", password: "123456",
             password_confirmation: "123456", specialist: true, job_title: "Analista", active: true)

# Solicitante
User.create!(name: "João Silva", email: "joao@teste.com", password: "123456",
             password_confirmation: "123456")
```

---

## Deploy (Render + Supabase)

O app roda como um único web service Docker no Render, com Solid Queue rodando dentro do
mesmo processo Puma (`SOLID_QUEUE_IN_PUMA=true`) — não precisa de worker separado. O Postgres
e o Active Storage (upload de arquivos) usam o Supabase, já que o Render free tier tem
sistema de arquivos efêmero.

### 1. Criar o projeto no Supabase

1. Crie um projeto em [supabase.com](https://supabase.com) (free tier).
2. Em **Project Settings → Database → Connection string**, copie a **Direct connection**
   (porta `5432`, não a "Transaction pooler" — o Rails usa prepared statements e locks de
   migração que não funcionam bem em modo transaction pooling).
3. Em **Storage**, crie um bucket (ex.: `projeto-tcc-production`) para os anexos do chat.
4. Em **Project Settings → Storage → S3 Connection**, gere um par de chaves de acesso S3 e
   anote o **endpoint** — isso alimenta `config/storage.yml`.

### 2. Criar o web service no Render

1. Crie um novo **Blueprint** em [render.com](https://render.com) apontando para o
   repositório — ele lê o `render.yaml` na raiz e cria o serviço automaticamente.
   (Alternativa manual: New → Web Service → Docker, usando o `Dockerfile` da raiz.)
2. Preencha as variáveis de ambiente marcadas como secretas no `render.yaml`:

   | Variável | De onde vem |
   |---|---|
   | `RAILS_MASTER_KEY` | conteúdo de `config/master.key` (local, nunca commitado) |
   | `DATABASE_URL` | connection string direta do Supabase (passo 1.2) |
   | `APP_HOST` | domínio do Render, ex. `triagem-ai.onrender.com` |
   | `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` | conforme `AI_PROVIDER` |
   | `SUPABASE_S3_ACCESS_KEY_ID` / `SUPABASE_S3_SECRET_ACCESS_KEY` | passo 1.4 |
   | `SUPABASE_S3_ENDPOINT` | passo 1.4 |
   | `SUPABASE_S3_BUCKET` | nome do bucket criado no passo 1.3 |

3. Deploy. O `bin/docker-entrypoint` roda `rails db:prepare` automaticamente no boot,
   criando/migrando os schemas de `primary`, `cache`, `queue` e `cable` no banco do Supabase.

### Limitações do plano free

- O serviço "dorme" após ~15 min sem tráfego; a próxima requisição demora 30-60s para
  acordar, e conexões WebSocket (ActionCable) precisam reconectar nesse momento.
- Supabase free pausa o projeto após 1 semana sem atividade (basta reabrir no dashboard
  para reativar).

---

## Estrutura de Diretórios

```
projeto_tcc/
├── app/
│   ├── channels/              # ActionCable: TriageChannel, QueueChannel, TvChannel, ValidationPanelChannel
│   ├── controllers/
│   │   ├── admin/             # triage_settings, users
│   │   ├── api/               # triage (JSON para Vue SPA), queue, session
│   │   ├── attendance/        # panel, attendances
│   │   ├── validation/        # panel, triage_validations, queue_entries, reports
│   │   ├── staff/             # sessions (login da equipe)
│   │   └── application_controller.rb
│   ├── helpers/
│   │   └── application_helper.rb  # urgency_label, urgency_color, urgency_badge_style
│   ├── javascript/
│   │   └── patient/           # SPA Vue 3 do solicitante
│   │       ├── App.vue        # Layout principal, navbar, logout
│   │       ├── router/        # Rotas Vue com guards de navegação
│   │       ├── stores/        # Pinia: triage store
│   │       ├── composables/   # useCable (ActionCable), useApi (fetch)
│   │       └── views/
│   │           ├── TriageStart.vue   # Demanda inicial
│   │           ├── TriageChat.vue    # Chat com IA
│   │           ├── TriageQueue.vue   # Fila e tela de chamada
│   │           └── profile/ProfileEdit.vue # Perfil e condições de prioridade
│   ├── models/
│   │   ├── user.rb            # Devise + flags de perfil + condições de prioridade na fila
│   │   ├── triage_session.rb  # 7 status: in_triage → completed
│   │   ├── ai_classification.rb
│   │   ├── triage_validation.rb
│   │   ├── queue_entry.rb     # ticket_number, urgency_level, priority_tier, queue_position (SQL)
│   │   ├── chat_message.rb
│   │   └── triage_setting.rb  # TriageSetting.current — config dinâmica da IA
│   ├── services/
│   │   ├── ai_service.rb          # Abstração OpenAI / Anthropic
│   │   ├── triage_service.rb      # Orquestra chat + classificação
│   │   └── queue_entry_service.rb # Gera ticket e insere na fila
│   └── views/
│       ├── admin/             # triage_settings, users (CRUD)
│       ├── attendance/        # panel, show (detalhes do atendimento)
│       ├── validation/        # panel, triage_validations, reports
│       ├── layouts/           # application, attendance, validation
│       └── tv/                # Tela pública de chamada
├── config/
│   ├── routes.rb
│   └── locales/
│       ├── pt-BR.yml          # Traduções da aplicação
│       └── devise.pt-BR.yml   # Traduções do Devise
└── db/
    └── migrate/               # migrações do schema completo
```

---

## Protocolo de Urgência (Manchester)

| Cor | Nível | Descrição |
|---|---|---|
| 🔴 Vermelho | Emergência | Risco imediato de vida |
| 🟠 Laranja | Muito Urgente | Situação grave, atendimento rápido |
| 🟡 Amarelo | Urgente | Condição importante, pode aguardar |
| 🟢 Verde | Pouco Urgente | Condição não urgente |
| 🔵 Azul | Não Urgente | Situação de rotina |

---

## Autor

**José Torrezan RA:115385**
**lucas Vieria RA:114602**
**Gustavo Adorno RA:115871**
**Enzo Gaino RA:115619**
TCC — 2026
