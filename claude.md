# Claude.md — TriagemIA (Projeto TCC)

## Visão Geral do Projeto

**Nome:** TriagemIA — Sistema de Triagem Automatizada com IA
**Framework:** Ruby on Rails 8+ com Ruby 3.3.8
**Banco de Dados:** PostgreSQL
**Objetivo:** Sistema de atendimento inicial automatizado via IA, com triagem, classificação de prioridade, fila de espera e notificações em tempo real. Aplicável a hospitais, clínicas, secretarias e comércios.

---

## Contexto do Projeto (TCC)

Este sistema permite que estabelecimentos (ex: hospital, secretaria, comércio) ofereçam um atendimento inicial ao cliente via IA, com um **prompt personalizado por estabelecimento**. O fluxo principal é:

1. Cliente acessa o app e faz login
2. É atendido por uma IA treinada para aquele contexto específico
3. A IA realiza perguntas de triagem e classifica urgência/prioridade
4. O caso vai para validação humana (atendente/enfermeira)
5. Após validação, o cliente entra na fila e acompanha posição + urgência em tempo real
6. Cliente é notificado quando for chamado

**Exemplo principal:** triagem hospitalar com protocolo Manchester (verde/amarelo/laranja/vermelho).

---

## Perfis de Usuário

Todos os perfis estão na tabela `users`. A distinção é feita por dois campos boolean:

| Campo | Tipo | Regra |
|---|---|---|
| `atendente` | boolean | `false` = cliente; `true` = pode acessar o login de atendente |
| `admin` | boolean | `true` = pode criar/gerenciar contas de atendente |

- Quem tenta entrar pelo login de atendente com `atendente = false` é bloqueado
- Somente usuários com `admin = true` podem criar contas de atendente
- Um `admin` pode também ser `atendente` (ambos `true`)

Login separado por perfil (dois endpoints distintos), mas uma única tabela `users`.

---

## Stack de Tecnologia

- **Backend:** Ruby on Rails 8, Ruby 3.3.8
- **Banco:** PostgreSQL
- **IA:** API de LLM (Claude/OpenAI) — prompt personalizado por estabelecimento
- **Frontend:** ERB + Tailwind CSS + Hotwire (Turbo + Stimulus)
- **Tempo real:** Action Cable (WebSockets) — fila e notificações
- **Autenticação:** Devise (dois fluxos separados)
- **Background Jobs:** Solid Queue (embutido Rails 8)
- **Deploy:** Kamal (já configurado no projeto)

---

## Modelos Esperados

```ruby
# Principais entidades do domínio
Establishment      # hospital, clinic, office, commerce — has system_prompt and urgency_protocol
User               # all users (client, attendant, admin) — fields: attendant:boolean, admin:boolean
TriageSession      # triage chat session, belongs to User + Establishment
ChatMessage        # each message in the triage chat (sender: user or ai)
AiClassification   # AI triage result (urgency_level, summary, identified_symptoms)
TriageValidation   # attendant's decision on the AI classification
QueueEntry         # client's position in the waiting queue (urgency_weight for ordering)
Notification       # alerts to the client (called, position updated, etc.)
```

---

## Services Planejados

```ruby
# app/services/
TriagemService      # orquestra o fluxo de triagem com a IA
IAService           # integração com API de LLM, monta prompt + contexto
FilaService         # gerencia inserção, posição e atualização da fila
NotificacaoService  # dispara notificações ao cliente
```

---

## Estrutura de Rotas (Planejado)

```ruby
# config/routes.rb
devise_for :users    # login cliente
devise_for :atendentes  # login atendente/admin

resources :atendimentos do
  resources :mensagens, only: [:create]
end

resources :fila_espera, only: [:index, :show]
resources :validacoes, only: [:index, :update]  # painel do atendente
```

---

## Convenções deste Projeto

### Models
- Nomes singulares em português (ex: `Atendimento`, `FilaEspera`)
- Validações e associações declaradas no model
- Lógica complexa em services

### Controllers
- Controllers slim — lógica nos services
- `before_action :authenticate_user!` em todos os controllers protegidos
- Separar namespace `admin/` ou `atendente/` do namespace de cliente

### IA / Prompts
- Cada `Estabelecimento` armazena seu próprio `system_prompt`
- O `IAService` monta o contexto com: system_prompt + histórico do chat + nova mensagem
- Respostas da IA devem ser estruturadas (JSON) para extração de classificação

---

## Configuração do Ambiente

### Pré-requisitos
- Ruby 3.3.8 (gerenciado com asdf)
- PostgreSQL 14+
- Bundler

### Setup
```bash
git clone git@github.com:jguido18/projeto_tcc.git
cd projeto_tcc
bundle install
rails db:create db:migrate
bin/dev
```

---

## Comandos Úteis

```bash
rails console                  # Console interativo
rails db:migrate               # Rodar migrations
rails db:rollback              # Desfazer última migration
rails routes                   # Listar rotas
rails generate model NomeModel # Gerar model
rails generate migration Nome  # Gerar migration
bin/dev                        # Servidor local (com Foreman)
```

---

## Notas para o Claude

- O projeto usa **Rails 8** — prefira Solid Queue/Cache/Cable ao invés de Redis/Sidekiq quando possível
- Autenticação tem **dois fluxos separados**: cliente e atendente
- Cada estabelecimento tem **prompt de IA próprio** — não hardcodar prompts
- Fila de espera deve ser **atualizada em tempo real** via ActionCable
- Classificação de urgência deve seguir o padrão do estabelecimento (ex: protocolo Manchester para hospitais)
- Sempre que gerar código de integração com IA, deixar a chave de API em variável de ambiente (`.env` / credentials)

---

**Última atualização:** 2026-04-02
**Autor:** José Torrezan
**Repositório:** git@github.com:jguido18/projeto_tcc.git
