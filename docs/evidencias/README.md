# Evidências da validação funcional dos casos de uso

Fichas completas e capturas de tela da rodada de validação funcional do TCC
"Desenvolvimento de uma plataforma de triagem conversacional com inteligência artificial e gestão de atendimento em tempo real" (FHO, 2026).

- Execução manual no navegador: 10/11/2026, cenário Hospital, contas e dados fictícios.
- Suíte automatizada final: 111 testes, 261 asserções, 0 falhas (25/11/2026); cobertura SimpleCov de 67,26% das linhas e 43,21% dos ramos.
- Versão do código: tag `tcc-final-2026-11-25`.

"Aprovado (após correção)" indica que um defeito foi encontrado durante o teste, corrigido e retestado com sucesso; "Aprovado com ressalva" indica fluxo principal concluído com alguma alternativa, evidência ou especificação divergente.

| UC | Caso de uso | Ator | Parecer | Ficha | Capturas |
|---|---|---|---|---|---|
| UC01 | Cadastrar e fazer login (solicitante) | Solicitante | Aprovado | [UC01.md](UC01.md) | 6 |
| UC02 | Login da equipe | Colaborador; Especialista; Administrador | Aprovado | [UC02.md](UC02.md) | 7 |
| UC03 | Atualizar perfil e prioridade legal | Solicitante | Aprovado | [UC03.md](UC03.md) | 7 |
| UC04 | Iniciar triagem | Solicitante | Aprovado | [UC04.md](UC04.md) | 6 |
| UC05 | Conversar com a IA (com ou sem documento) | Solicitante; IA | Aprovado com ressalva | [UC05.md](UC05.md) | 5 |
| UC06 | Encerrar triagem e gerar classificação | Solicitante; IA | Aprovado com ressalva | [UC06.md](UC06.md) | 4 |
| UC07 | Check-in pelo código da TV | Solicitante | Aprovado com ressalva | [UC07.md](UC07.md) | 5 |
| UC08 | Check-in pela recepção | Colaborador | Aprovado | [UC08.md](UC08.md) | 5 |
| UC09 | Validar a classificação da IA | Colaborador | Aprovado (após correção) | [UC09.md](UC09.md) | 7 |
| UC10 | Entrar na fila e receber senha | Sistema | Aprovado | [UC10.md](UC10.md) | 5 |
| UC11 | Acompanhar posição e tempo de espera | Solicitante | Aprovado com ressalva (após correção) | [UC11.md](UC11.md) | 6 |
| UC12 | Ordenar a fila (urgência, prioridade legal e SLA) | Sistema | Aprovado | [UC12.md](UC12.md) | 6 |
| UC13 | Chamar o solicitante | Colaborador | Aprovado com ressalva | [UC13.md](UC13.md) | 6 |
| UC14 | Atender e finalizar | Especialista | Aprovado | [UC14.md](UC14.md) | 6 |
| UC15 | Revisar classificação durante atendimento | Especialista | Aprovado com ressalva | [UC15.md](UC15.md) | 8 |
| UC16 | Cancelar triagem | Solicitante | Aprovado | [UC16.md](UC16.md) | 3 |
| UC17 | Configurar IA, urgências e regras | Administrador | Aprovado com ressalva | [UC17.md](UC17.md) | 6 |
| UC18 | Gerenciar usuários da equipe | Administrador | Aprovado | [UC18.md](UC18.md) | 9 |
| UC19 | Consultar relatórios e exportar CSV | Administrador | Aprovado (após correção) | [UC19.md](UC19.md) | 5 |
