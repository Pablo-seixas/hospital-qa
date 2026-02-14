# README — Hospital App (Expo + React Native + TypeScript)

Este documento explica **como o app está organizado**, **o que cada módulo faz**, **regras de permissão**, **fluxos do sistema**, e **como manter/expandir** no futuro — sem código.

---

## Visão geral

Aplicativo mobile (Expo/React Native/TypeScript) para gestão hospitalar com:

* Cadastro e gestão de **Funcionários** (com cargos, setores, níveis de acesso e auditoria)
* Cadastro de **Pacientes** (validações fortes de documento, telefone e nascimento)
* **Agendamentos** (dia/semana/mês) com médico, serviço e possibilidade de alteração a qualquer momento
* **Prontuário** do paciente (anotações, exames e anexos)
* **Tipos de serviço / tratamento / preços** (área ADM)
* **Leitos** (vago/ocupado e previsão de liberação)
* **Ordens de Procedimento / Pedido Cirúrgico** (tipo ordem de serviço) com equipe multiprofissional
* **Auditoria completa** (histórico do que foi feito, por quem, quando, antes/depois)
* **RH**: desligamento pelo app (bloqueio de login mantendo histórico)
* Relatórios em **PDF** (exportação detalhada)

---

## Stack e dependências principais

* Expo SDK (54.x)
* React Native
* TypeScript
* React Navigation: native-stack + bottom-tabs
* SQLite local (expo-sqlite)
* Auditoria via tabela `audit_logs`
* Anexos via `expo-document-picker` + `expo-file-system`
* Relatórios PDF via `expo-print` + `expo-sharing`

---

## Arquitetura de pastas

### `src/navigation/`

Responsável pela navegação:

* `RootNavigator.tsx`: stack principal (Auth → Main + telas de detalhe/form)
* `MainTabs.tsx`: abas (Dashboard, Funcionários, Pacientes, Agenda, Ordens, Serviços, Histórico)

Manutenção:

* Sempre que criar tela nova, registre a rota no `RootNavigator` e/ou Tab no `MainTabs`.
* Tipos de navegação ficam em `types.ts`.

---

### `src/ui/`

Camada de interface (telas e componentes).

#### `src/ui/screens/`

Telas principais:

* **Dashboard**: indicadores e últimos logins
* **Employees**: lista e busca
* **EmployeeDetail**: detalhe do funcionário, permissões e RH
* **Patients**: lista e busca
* **PatientChart**: prontuário + exames + anexos (com controle de acesso)
* **Appointments**: agenda
* **ProcedureOrders**: ordens/procedimentos
* **ProcedureOrderDetail**: detalhe, equipe, permissões e PDF
* **Audit**: histórico geral

#### `src/ui/screens/forms/`

Formulários separados:

* `EmployeeForm` (criar/editar funcionário)
* `PatientForm` (criar/editar paciente)
* `AppointmentForm` (agendamento com selects)
* `ServiceForm` (tipo de serviço/preço)
* `ProcedureOrderForm` (criar/editar ordem)

#### `src/ui/components/`

Componentes reutilizáveis:

* Input, Button, Screen, Card
* `SelectList`: seletor pesquisável (para paciente/médico/serviço etc.)

Manutenção:

* Componentes devem ser pequenos e específicos.
* Evitar lógica de banco direto dentro de componente simples (deixar na tela/repo/service).

---

### `src/data/`

Camada de dados (SQLite + repositórios).

#### `src/data/db/`

* `sqlite.ts`: helpers de execução SQL
* `migrations.ts`: criação/alteração de tabelas (migrações)

Regra de manutenção:

* Qualquer mudança estrutural (tabela/coluna) entra em `migrations.ts`.
* Sempre criar com `CREATE TABLE IF NOT EXISTS`.
* Para colunas novas, usar `ALTER TABLE` com checagem `PRAGMA table_info`.

#### `src/data/repositories/`

Repositórios por domínio (CRUD e queries):

* `employees.repo.ts` / `employees.admin.repo.ts` (admin: canBuildTeam, terminate)
* `patients.repo.ts`
* `appointments.repo.ts`
* `services.repo.ts`
* `patientFiles.repo.ts` (anexos)
* `patientDoctors.repo.ts` (médicos marcados do paciente)
* `procedureOrders.repo.ts` (ordens)
* `procedureTeam.repo.ts` (equipe da ordem)
* `patientEvents.repo.ts` (eventos como óbito)
* `audit.repo.ts` / `stats.repo.ts`

Regra de manutenção:

* UI chama repos/serviços, não SQL direto.
* Cada repo faz uma responsabilidade clara.

---

### `src/domain/`

Regras do domínio (validações e permissões).

* `validators/`: validações do paciente (CPF/RG/CNH, telefone, nascimento)
* `permissions/`: regras de acesso (quem pode ver/alterar ordem, equipe, anexos)

Regra:

* Se tiver regra “de negócio”, ela deve ir aqui.
* UI só consome a regra, não inventa permissão na tela.

---

### `src/services/`

Serviços que não são “CRUD puro”:

* `auth/`: login/logout (inclui bloqueio RH)
* `audit/`: gravação do audit log
* `reports/`: geração e compartilhamento de PDF

Regra:

* Serviços coordenam múltiplos repositórios quando necessário.

---

## Banco de dados (tabelas principais)

### Funcionários

* `employees`

  * inclui `role`, `jobTitle`, `sector`
  * RH: `status` (`ACTIVE` ou `TERMINATED`)
  * permissão especial: `canBuildTeam` (0/1)
* Auditoria: `audit_logs` registra tudo

**RH Desligamento:**

* Não apaga funcionário: muda status para `TERMINATED`
* Mantém histórico e impede login.

---

### Pacientes

* `patients`

  * `documentType` (CPF/RG/CNH)
  * `documentId`, `phone`, `birthDate` obrigatórios (com validação)
* `patient_files`: anexos
* `patient_doctors`: médicos marcados do paciente (controle de acesso)
* `patient_events`: eventos (óbito etc.)

---

### Agenda / Atendimento

* `appointments`

  * `patientId`, `doctorEmployeeId`, `serviceTypeId`
  * `scheduledAt` (timestamp)
  * `status` (SCHEDULED/DONE/CANCELED)
* Agendamento tem **selects** (paciente, médico e serviço).

**Importante:** ao criar/editar agendamento, o sistema marca automaticamente o médico como “médico do paciente” (em `patient_doctors`).

---

### Serviços / Tratamentos / Preços

* `service_types`

  * nome, tipo de tratamento, preço (centavos)

---

### Ordem de Procedimento / Pedido Cirúrgico

* `procedure_orders`

  * paciente, médico solicitante, status, prioridade, data prevista
* `procedure_team_members`

  * membros da equipe com função
  * `isLead=1` para médico responsável (lead)

---

### Auditoria

* `audit_logs`

  * `actorEmployeeId`, `actorName`
  * `action` (LOGIN/CREATE/UPDATE/DELETE/EXPORT…)
  * `entity` (EMPLOYEE/PATIENT/APPOINTMENT/PROCEDURE_ORDER…)
  * `beforeJson`, `afterJson`, `metaJson`

Essa tabela é a base do “quem fez o quê”.

---

## Regras de validação

### Paciente (obrigatório)

* Documento: CPF ou RG ou CNH
* Telefone: 10 ou 11 dígitos (DDD + número)
* Data nascimento: formato `YYYY-MM-DD`
* Ano de nascimento:

  * **máximo:** ano atual (ex.: 2026)
  * **mínimo:** ano atual - 126

---

## Controle de acesso e permissões

### Níveis (alto nível)

* **ROOT_ADMIN**: acesso total
* **DOCTOR**: acesso parcial (depende de marcações/papéis)
* **Outros (enfermagem/técnico etc.)**: acesso por vínculo (equipe selecionada)

### Prontuário e anexos (PDF/imagem)

* Root Admin: **vê/abre/exclui**
* Médico: **só vê/abre/exclui** se estiver **marcado como médico do paciente** (`patient_doctors`)
* Enfermagem/Técnico/Outros: **não veem anexos** (por regra atual)

### Ordens e “o que será feito”

* Root: sempre vê
* Equipe selecionada na ordem: vê
* Médico: pode ver se for médico marcado do paciente (regra reforçada)
* Outros: só vê se estiver na equipe daquela ordem

### Quem pode montar/alterar equipe (ordem)

* Root: sempre pode
* Coordenação: (previsto no modelo; depende do role que você decidir fixar)
* Médico:

  * só se for **responsável (lead)** **e**
  * só se Root tiver liberado `canBuildTeam=1`

### RH Desligamento

* Root executa desligamento do funcionário:

  * status vira `TERMINATED`
  * login bloqueado
  * histórico permanece
* O sistema não permite desligar o próprio Root para não “matar” o app.

---

## Fluxos principais

### 1) Cadastro de funcionário

* Root cadastra funcionário com:

  * nome, número, email, telefone
  * role + cargo + setor
  * senha
* Auditoria grava CREATE/UPDATE/DELETE (soft)

### 2) Cadastro de paciente

* Obrigatório: documento + telefone + nascimento (validado)
* Auditoria grava mudanças

### 3) Agendamento

* Seleciona paciente, médico, serviço (SelectList)
* Define data/hora e duração
* Ao salvar, marca automaticamente o médico do paciente em `patient_doctors`
* Auditoria grava tudo

### 4) Prontuário + exames

* Médico/Root atualiza resumo/diagnóstico/obs
* Exames: criar, marcar DONE, registrar resultado
* Auditoria grava alterações

### 5) Anexos do paciente

* Root (e médico marcado) pode anexar PDF/imagem
* Arquivo é salvo localmente no storage do app
* Registro vai para `patient_files`
* Abertura do arquivo usa o app do sistema (PDF viewer / galeria)

### 6) Ordem / Procedimento (ordem de serviço do hospital)

* Cria uma ordem com descrição, prioridade e status
* Monta equipe multiprofissional com funções
* Pode ter vários médicos (um lead responsável)

### 7) Óbito

* Registro em `patient_events` e `audit_logs`
* Pode ser exportado no relatório PDF

### 8) Relatório PDF

* Gera PDF com dados do paciente e ordem/equipe
* Compartilha (WhatsApp/Drive/email etc., conforme o aparelho)

---

## Soft delete (exclusão segura)

Quase tudo é “exclusão lógica”:

* `isDeleted = 1`
* `deletedAt` preenchido

Benefícios:

* mantém auditoria e histórico
* evita perda de dados por engano

---

## Como fazer manutenção no futuro

### Regra de ouro

**Não misturar responsabilidade:**

* UI: só exibe e chama ações
* Repo: SQL e consultas
* Services: orquestração entre repos
* Domain: regras/validações/permissões

### Quando criar algo novo

1. Criar tabela/coluna em `migrations.ts`
2. Criar repo correspondente
3. Criar telas (lista + form + detalhe), se necessário
4. Registrar rotas (RootNavigator / Tabs)
5. Adicionar auditoria (CREATE/UPDATE/DELETE/EXPORT)
6. Aplicar permissão no `domain/permissions`

### Como adicionar um novo papel (ex.: Coordenação)

* Criar um `Role` novo (ex.: `COORDINATOR`)
* Ajustar `RoleLabel`
* Ajustar `canManageSurgeryTeam` para aceitar esse role
* Criar UI no funcionário para escolher esse role
* (Opcional) criar tab/tela específica de “Central Cirúrgica”

---

## Observações importantes (limitações atuais)

* Anexos ficam **localmente** no dispositivo por enquanto (não há servidor/cloud).
* PDF é gerado por HTML (rápido e funciona bem no Expo).
* “Coordenação” está prevista no fluxo, mas você precisa definir qual `role` oficial vai ser usado (ex.: `COORDINATOR_ADMIN` ou `SURGERY_COORDINATOR`) para a permissão ficar 100% automática.

---

## Checklist de “produção” (quando for subir isso de verdade)

* Backend (API + banco central) para sincronizar vários celulares
* Autenticação real + tokens
* Controle de acesso “server-side”
* Upload de anexos em storage (S3/GCS)
* Logs e backups
* Criptografia (LGPD)
* Trilhas de auditoria com hash/imutabilidade (se necessário)

---

## Glossário (nomes usados no hospital)

* **Prontuário**: histórico clínico do paciente
* **Pedido cirúrgico / solicitação de procedimento**: o médico solicita a cirurgia/procedimento
* **Mapa cirúrgico / agenda cirúrgica**: programação do centro cirúrgico
* **Equipe multiprofissional**: cirurgião, assistentes, anestesista, enfermagem, técnico etc.
* **Coordenação do Centro Cirúrgico**: pessoa que organiza equipe/agenda (comum ser enfermeiro coordenador)
* **Óbito**: evento crítico registrado com auditoria

---

Se você quiser, eu também escrevo um README “para dev” com:

* padrão de commits,
* como versionar migrações,
* como testar permissões (cenários),
* e como gerar dados fake para testes (seed).
