# TriagemIA — Sistema de Triagem Automatizada com IA

> Projeto de TCC — Sistema de atendimento e triagem automatizada utilizando Inteligência Artificial, aplicável a hospitais, clínicas, secretarias e comércios em geral.

---

## Descrição do Projeto

O **TriagemIA** é uma plataforma web/mobile que permite a empresas e instituições oferecerem um atendimento inicial automatizado via IA, com classificação de prioridade, gestão de fila de espera e notificações em tempo real.

Cada organização (hospital, clínica, secretaria, comércio) possui um ambiente próprio com um **prompt personalizado** treinado para o seu contexto de atendimento. A IA conduz o cliente por um roteiro de perguntas estruturadas, classifica o caso e o insere em uma fila monitorada por um responsável humano.

---

## Fluxo do Sistema

```
Cliente acessa o app
        │
        ▼
   Seleciona perfil
  ┌─────┴──────┐
  │            │
Atendente   Cliente
  │            │
  │            ▼
  │     Login na conta
  │            │
  │            ▼
  │     Chat com IA de atendimento
  │     (prompt personalizado por estabelecimento)
  │            │
  │            ▼
  │     IA coleta sintomas / informações
  │     e realiza perguntas de triagem padrão
  │            │
  │            ▼
  │     IA classifica urgência/prioridade
  │     e insere o cliente na fila
  │            │
  ▼            ▼
Enfermeiro/Responsável valida a classificação da IA
        │
        ▼
   Cliente confirmado na fila
        │
        ▼
App do cliente exibe:
 - Número de posição na fila
 - Nível de urgência
 - Notificação quando for chamado
```

---

## Exemplo de Uso — Triagem Hospitalar

1. Paciente acessa o app e faz login
2. É recebido pelo atendente virtual do hospital
3. Informa seus sintomas ao chat
4. A IA faz perguntas de triagem padrão (protocolo Manchester ou similar)
5. Com base nas respostas, a IA classifica a urgência (ex: verde, amarelo, laranja, vermelho)
6. O caso é enviado para validação de uma enfermeira responsável
7. Após validação, o paciente entra na fila de espera
8. O app exibe a posição na fila e o nível de urgência
9. Quando for chamado, o paciente recebe uma notificação

---

## Tipos de Estabelecimento Suportados

- Hospitais e UPAs
- Clínicas e consultórios
- Secretarias municipais
- Comércios com atendimento ao cliente

Cada estabelecimento possui seu próprio **prompt de IA personalizado** e base de conhecimento adaptada ao seu contexto.

---

## Perfis de Usuário

| Perfil | Acesso |
|---|---|
| **Cliente/Paciente** | Chat com IA, acompanhamento de fila, notificações |
| **Atendente/Responsável** | Validação de classificações, gestão da fila, painel de atendimento |
| **Administrador** | Configuração do prompt de IA, cadastro de usuários, relatórios |

---

## Stack de Tecnologia

- **Backend:** Ruby on Rails 8+ com Ruby 3.3.8
- **Banco de Dados:** PostgreSQL
- **IA:** Integração com API de LLM (ex: Claude / OpenAI) via prompts personalizados por estabelecimento
- **Frontend:** ERB + Tailwind CSS / Hotwire (Turbo + Stimulus)
- **Tempo real:** Action Cable (WebSockets) para atualização de fila e notificações
- **Autenticação:** Devise (dois fluxos: cliente e atendente)
- **Background Jobs:** Solid Queue (embutido no Rails 8)

---

## Configuração do Ambiente

### Pré-requisitos

- Ruby 3.3.8
- PostgreSQL 14+
- Bundler
- Node.js 20.19+ (recomendado 20.20.1)
- npm 10+

### Instalação

```bash
# Clonar o repositório
git clone git@github.com:jguido18/projeto_tcc.git
cd projeto_tcc

# Instalar dependências
bundle install
npm install

# Criar e migrar banco de dados
rails db:create
rails db:migrate

# (Opcional) Dados iniciais
rails db:seed

# Build de assets frontend (Vite)
bin/vite build --clear --mode=development

# Iniciar servidor
bin/dev
```

---

## Estrutura Principal

```
projeto_tcc/
├── app/
│   ├── models/           # User, Estabelecimento, Atendimento, FilaEspera
│   ├── controllers/      # Autenticação, Chat, Fila, Validação
│   ├── views/            # Interface cliente e atendente
│   ├── services/         # TriagemService, IAService, FilaService
│   ├── channels/         # ActionCable para fila em tempo real
│   └── jobs/             # NotificacaoJob, AtualizacaoFilaJob
├── config/
│   ├── routes.rb
│   └── database.yml
├── db/
│   └── migrate/
├── test/
└── README.md
```

---

## Funcionalidades Planejadas

- [x] Estrutura base do projeto Rails
- [ ] Autenticação com dois perfis (cliente e atendente)
- [ ] Cadastro de estabelecimentos com prompt de IA personalizado
- [ ] Chat de triagem com IA
- [ ] Classificação automática de urgência
- [ ] Painel de validação para atendentes
- [ ] Fila de espera em tempo real (WebSocket)
- [ ] Notificação ao paciente quando chamado
- [ ] Painel administrativo

---

## Autor

**José Torrezan**
TCC — 2026
