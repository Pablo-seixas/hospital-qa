Hospital App (Expo + React Native + TypeScript)

Este documento explica como o app está organizado, o que cada módulo faz, regras de permissão, fluxos do sistema e como manter ou expandir no futuro, sem código.

Visão geral

Aplicativo mobile (Expo, React Native e TypeScript) para gestão hospitalar com cadastro e gestão de funcionários com cargos, setores, níveis de acesso e auditoria. Cadastro de pacientes com validações fortes de documento, telefone e nascimento. Agendamentos por dia, semana e mês com médico, serviço e possibilidade de alteração a qualquer momento. Prontuário do paciente com anotações, exames e anexos. Tipos de serviço, tratamento e preços na área administrativa. Controle de leitos com status vago ou ocupado e previsão de liberação. Ordens de procedimento ou pedido cirúrgico com equipe multiprofissional. Auditoria completa com histórico do que foi feito, por quem, quando e estados antes e depois. Recursos de RH com desligamento pelo app, bloqueando login e mantendo histórico. Relatórios em PDF com exportação detalhada.

Stack e dependências principais

Expo SDK versão 54.
React Native.
TypeScript.
React Navigation com native stack e bottom tabs.
SQLite local via expo-sqlite.
Auditoria via tabela audit_logs.
Anexos via expo-document-picker e expo-file-system.
Relatórios PDF via expo-print e expo-sharing.

Arquitetura de pastas

src/navigation

Responsável pela navegação do aplicativo.
RootNavigator.tsx define o stack principal, incluindo autenticação, área principal e telas de detalhe e formulário.
MainTabs.tsx define as abas como Dashboard, Funcionários, Pacientes, Agenda, Ordens, Serviços e Histórico.

Manutenção da navegação exige que qualquer tela nova seja registrada no RootNavigator ou nas abas do MainTabs. Os tipos de navegação ficam centralizados em types.ts.

src/ui

Camada de interface, contendo telas e componentes.

src/ui/screens

Inclui telas principais como Dashboard com indicadores e últimos logins, Employees para lista e busca de funcionários, EmployeeDetail com detalhes e permissões, Patients para lista e busca de pacientes, PatientChart com prontuário, exames e anexos com controle de acesso, Appointments para agenda, ProcedureOrders para ordens e procedimentos, ProcedureOrderDetail com detalhe da ordem, equipe, permissões e geração de PDF, e Audit com histórico geral.

src/ui/screens/forms

Formulários isolados para criação e edição. Inclui EmployeeForm, PatientForm, AppointmentForm com seletores, ServiceForm para tipo de serviço e preço, e ProcedureOrderForm para ordens.

src/ui/components

Componentes reutilizáveis como Input, Button, Screen e Card. Inclui SelectList, um seletor pesquisável para paciente, médico, serviço e outros. Componentes devem ser pequenos e específicos, evitando lógica direta de banco dentro de componentes simples.

src/data

Camada de dados usando SQLite e repositórios.

src/data/db

Arquivo sqlite.ts com helpers para execução de SQL.
Arquivo migrations.ts responsável por criação e alteração de tabelas.

Toda mudança estrutural deve entrar em migrations.ts. Tabelas devem ser criadas com CREATE TABLE IF NOT EXISTS. Novas colunas devem ser adicionadas via ALTER TABLE após checagem com PRAGMA table_info.

src/data/repositories

Repositórios por domínio, responsáveis por CRUD e consultas. Incluem repositórios de funcionários, pacientes, agendamentos, serviços, anexos do paciente, médicos vinculados ao paciente, ordens de procedimento, equipe da ordem, eventos do paciente como óbito, auditoria e estatísticas.

A interface nunca chama SQL diretamente. Cada repositório tem responsabilidade clara e isolada.

src/domain

Camada de regras de negócio.
Inclui validadores de paciente como CPF, RG, CNH, telefone e nascimento.
Inclui regras de permissão definindo quem pode ver ou alterar ordens, equipes e anexos.

Toda regra de negócio deve estar aqui. A interface apenas consome essas regras.

src/services

Serviços que não são CRUD puro.
Inclui autenticação com login, logout e bloqueio de RH.
Inclui serviço de auditoria para gravação de logs.
Inclui geração e compartilhamento de relatórios PDF.

Serviços coordenam múltiplos repositórios quando necessário.

Banco de dados

Funcionários

Tabela employees inclui role, jobTitle e sector.
RH controla status ACTIVE ou TERMINATED.
Permissão especial canBuildTeam define se o funcionário pode montar equipe.
Tudo é auditado na tabela audit_logs.

Desligamento de RH não apaga o funcionário. Apenas muda o status para TERMINATED, bloqueia login e mantém todo o histórico.

Pacientes

Tabela patients com documentType, documentId, phone e birthDate obrigatórios e validados.
patient_files armazena anexos.
patient_doctors controla médicos vinculados ao paciente.
patient_events registra eventos como óbito.

Agenda e atendimento

Tabela appointments com patientId, doctorEmployeeId, serviceTypeId, scheduledAt e status.
O agendamento sempre usa seletores para paciente, médico e serviço.
Ao criar ou editar um agendamento, o médico é automaticamente marcado como médico do paciente na tabela patient_doctors.

Serviços e tratamentos

Tabela service_types com nome, tipo de tratamento e preço em centavos.

Ordens de procedimento

Tabela procedure_orders com paciente, médico solicitante, status, prioridade e data prevista.
Tabela procedure_team_members com membros da equipe e função.
O médico responsável é marcado como líder.

Auditoria

Tabela audit_logs registra ator, ação, entidade, identificador, estados antes e depois e metadados. Essa tabela é a base de rastreabilidade do sistema.

Regras de validação

Paciente deve possuir documento válido, telefone com 10 ou 11 dígitos, data de nascimento no formato YYYY-MM-DD. O ano de nascimento não pode ser maior que o ano atual nem menor que o ano atual menos 126.

Controle de acesso

Root Admin tem acesso total.
Médico tem acesso parcial conforme vínculo.
Outros profissionais acessam apenas por vínculo com equipe.

Prontuário e anexos

Root Admin pode ver, abrir e excluir.
Médico só pode acessar se estiver marcado como médico do paciente.
Outros perfis não acessam anexos.

Ordens e procedimentos

Root sempre vê.
Equipe da ordem vê.
Médico pode ver se estiver vinculado ao paciente.
Outros só veem se fizerem parte da equipe.

Montagem de equipe

Root sempre pode.
Coordenação é prevista no modelo.
Médico só pode montar equipe se for líder e se Root tiver liberado canBuildTeam.

Fluxos principais

Cadastro de funcionário é feito pelo Root, com auditoria completa.
Cadastro de paciente exige validação obrigatória.
Agendamento seleciona paciente, médico e serviço e marca vínculo automaticamente.
Prontuário permite atualização de informações clínicas e exames.
Anexos são salvos localmente e registrados em banco.
Ordens de procedimento organizam equipes e responsabilidades.
Óbito é registrado como evento com auditoria.
Relatórios PDF podem ser gerados e compartilhados.

Soft delete

A exclusão é lógica, usando isDeleted e deletedAt, mantendo histórico e auditoria.

Manutenção futura

Não misturar responsabilidades entre UI, repositório, serviços e domínio.
Novas funcionalidades exigem migração, repositório, telas, rotas, auditoria e permissões.
Novos papéis exigem ajuste de roles, permissões e interface.

Observações

Anexos são locais por enquanto.
PDF é gerado por HTML.
Coordenação precisa ter role definido para permissões automáticas.

Checklist de produção

Backend centralizado, autenticação real, controle de acesso server-side, upload em storage, logs, backups, criptografia e trilhas de auditoria imutáveis.

Glossário

Prontuário é o histórico clínico.
Pedido cirúrgico é a solicitação médica.
Mapa cirúrgico é a agenda do centro cirúrgico.
Equipe multiprofissional envolve vários profissionais.
Coordenação do centro cirúrgico organiza equipe e agenda.
Óbito é evento crítico registrado com auditoria.
