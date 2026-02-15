/data/db/migrations.ts '
import { execAsync, getAllAsync, getFirstAsync, runAsync } from "./sqlite";
import { simpleHash } from "@/utils/hash";

async function ensurePatientsColumns() {
  const cols = await getAllAsync<{ name: string }>("PRAGMA table_info(patients)");
  const hasDocType = cols.some((c) => c.name === "documentType");
  if (!hasDocType) await execAsync(`ALTER TABLE patients ADD COLUMN documentType TEXT;`);
}

async function ensureEmployeesColumns() {
  const cols = await getAllAsync<{ name: string }>("PRAGMA table_info(employees)");
  const hasStatus = cols.some((c) => c.name === "status");
  const hasTerminatedAt = cols.some((c) => c.name === "terminatedAt");
  const hasTerminatedBy = cols.some((c) => c.name === "terminatedByEmployeeId");
  const hasCanBuildTeam = cols.some((c) => c.name === "canBuildTeam");

  if (!hasStatus) await execAsync(`ALTER TABLE employees ADD COLUMN status TEXT;`);
  if (!hasTerminatedAt) await execAsync(`ALTER TABLE employees ADD COLUMN terminatedAt INTEGER;`);
  if (!hasTerminatedBy) await execAsync(`ALTER TABLE employees ADD COLUMN terminatedByEmployeeId TEXT;`);
  if (!hasCanBuildTeam) await execAsync(`ALTER TABLE employees ADD COLUMN canBuildTeam INTEGER;`);

  // default
  await execAsync(`UPDATE employees SET status='ACTIVE' WHERE status IS NULL;`);
  await execAsync(`UPDATE employees SET canBuildTeam=0 WHERE canBuildTeam IS NULL;`);
}

export async function migrate() {
  await execAsync(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);

    CREATE TABLE IF NOT EXISTS employees (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      employeeNumber TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL,
      jobTitle TEXT NOT NULL,
      sector TEXT NOT NULL,
      passwordHash TEXT NOT NULL,
      mfaEnabled INTEGER NOT NULL,
      mfaPhoneVerified INTEGER NOT NULL,
      mfaEmailVerified INTEGER NOT NULL,
      mfaImageToken TEXT
      -- status/canBuildTeam/terminated* via ALTER
    );

    CREATE TABLE IF NOT EXISTS patients (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      name TEXT NOT NULL,
      documentId TEXT NOT NULL,
      phone TEXT NOT NULL,
      email TEXT,
      birthDate TEXT,
      notes TEXT
      -- documentType via ALTER
    );

    CREATE TABLE IF NOT EXISTS service_types (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      name TEXT NOT NULL,
      treatment TEXT NOT NULL,
      priceCents INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS appointments (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      patientId TEXT NOT NULL,
      doctorEmployeeId TEXT NOT NULL,
      serviceTypeId TEXT NOT NULL,
      scheduledAt INTEGER NOT NULL,
      durationMin INTEGER NOT NULL,
      status TEXT NOT NULL,
      notes TEXT
    );

    CREATE TABLE IF NOT EXISTS audit_logs (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      actorEmployeeId TEXT NOT NULL,
      actorName TEXT NOT NULL,
      action TEXT NOT NULL,
      entity TEXT NOT NULL,
      entityId TEXT NOT NULL,
      beforeJson TEXT,
      afterJson TEXT,
      metaJson TEXT
    );

    CREATE TABLE IF NOT EXISTS patient_files (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      patientId TEXT NOT NULL,
      name TEXT NOT NULL,
      mimeType TEXT,
      size INTEGER,
      localUri TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS patient_doctors (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      patientId TEXT NOT NULL,
      doctorEmployeeId TEXT NOT NULL,
      assignedByEmployeeId TEXT NOT NULL
    );

    -- NOVO: ORDEM CIRÚRGICA / ORDEM DE PROCEDIMENTO (pedido)
    CREATE TABLE IF NOT EXISTS procedure_orders (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,

      patientId TEXT NOT NULL,
      requestedByDoctorId TEXT NOT NULL, -- médico solicitante
      coordinatorEmployeeId TEXT,        -- quem organizou (coordenação)

      title TEXT NOT NULL,               -- ex: "Cirurgia de apendicite"
      description TEXT,                  -- detalhes
      priority TEXT NOT NULL,            -- LOW/MEDIUM/HIGH/URGENT
      plannedAt INTEGER,                 -- data prevista (opcional)
      status TEXT NOT NULL               -- REQUESTED/APPROVED/SCHEDULED/DONE/CANCELED
    );

    -- NOVO: EQUIPE DA ORDEM (múltiplos médicos e funções)
    CREATE TABLE IF NOT EXISTS procedure_team_members (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,

      orderId TEXT NOT NULL,
      employeeId TEXT NOT NULL,
      teamRole TEXT NOT NULL,            -- ex: LEAD_SURGEON/ASSISTANT/ANESTHETIST/NURSE/TECH/OTHER
      isLead INTEGER NOT NULL            -- 1 = responsável principal
    );

    -- NOVO: EVENTOS DO PACIENTE (ex.: óbito)
    CREATE TABLE IF NOT EXISTS patient_events (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,

      patientId TEXT NOT NULL,
      type TEXT NOT NULL,                -- DEATH
      eventAt INTEGER NOT NULL,
      declaredByEmployeeId TEXT NOT NULL,
      notes TEXT
    );
  `);

  await ensurePatientsColumns();
  await ensureEmployeesColumns();

  const seeded = await getFirstAsync<{ value: string }>("SELECT value FROM meta WHERE key='seeded'");
  if (!seeded?.value) {
    const now = Date.now();
    await runAsync("INSERT OR REPLACE INTO meta(key,value) VALUES('seeded','1')");

    const hash = simpleHash("1234");
    await runAsync(
      `INSERT INTO employees (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        employeeNumber, name, phone, email, role, jobTitle, sector,
        passwordHash, mfaEnabled, mfaPhoneVerified, mfaEmailVerified, mfaImageToken,
        status, terminatedAt, terminatedByEmployeeId, canBuildTeam
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, NULL, 'ACTIVE', NULL, NULL, 1)`,
      ["root-1", now, now, "0001", "Root Admin", "000000000", "root@hospital.com", "ROOT_ADMIN", "Root", "Administração", hash]
    );
  }
}


# ---------------------------
# 2) REPOS: Procedure Orders + Team + Patient Events + RH (employees)
cat > src/data/repositories/procedureOrders.repo.ts 
import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type ProcedureOrder = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;

  patientId: string;
  requestedByDoctorId: string;
  coordinatorEmployeeId?: string|null;

  title: string;
  description?: string|null;
  priority: "LOW"|"MEDIUM"|"HIGH"|"URGENT";
  plannedAt?: number|null;
  status: "REQUESTED"|"APPROVED"|"SCHEDULED"|"DONE"|"CANCELED";
};

export const ProcedureOrdersRepo = {
  list(): Promise<ProcedureOrder[]> {
    return getAllAsync<ProcedureOrder>("SELECT * FROM procedure_orders WHERE isDeleted=0 ORDER BY createdAt DESC");
  },

  listByPatient(patientId: string): Promise<ProcedureOrder[]> {
    return getAllAsync<ProcedureOrder>(
      "SELECT * FROM procedure_orders WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
      [patientId]
    );
  },

  getById(orderId: string): Promise<ProcedureOrder | null> {
    return getFirstAsync<ProcedureOrder>("SELECT * FROM procedure_orders WHERE isDeleted=0 AND id=?", [orderId]);
  },

  async create(o: Omit<ProcedureOrder,"id"|"createdAt"|"updatedAt"|"isDeleted">) {
    const now = Date.now();
    const row: ProcedureOrder = { ...o, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO procedure_orders (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, requestedByDoctorId, coordinatorEmployeeId,
        title, description, priority, plannedAt, status
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        row.id, row.createdAt, row.updatedAt,
        row.patientId, row.requestedByDoctorId, row.coordinatorEmployeeId ?? null,
        row.title, row.description ?? null, row.priority, row.plannedAt ?? null, row.status
      ]
    );
    return row;
  },

  async update(orderId: string, patch: Partial<ProcedureOrder>) {
    const cur = await this.getById(orderId);
    if (!cur) return null;
    const next: ProcedureOrder = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE procedure_orders SET
        updatedAt=?,
        patientId=?, requestedByDoctorId=?, coordinatorEmployeeId=?,
        title=?, description=?, priority=?, plannedAt=?, status=?
      WHERE id=?`,
      [
        next.updatedAt,
        next.patientId, next.requestedByDoctorId, next.coordinatorEmployeeId ?? null,
        next.title, next.description ?? null, next.priority, next.plannedAt ?? null, next.status,
        orderId
      ]
    );
    return next;
  },

  softDelete(orderId: string) {
    const now = Date.now();
    return runAsync("UPDATE procedure_orders SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, orderId]);
  },
};


 src/data/repositories/procedureTeam.repo.ts 
import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type TeamMember = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;
  orderId: string;
  employeeId: string;
  teamRole: string;
  isLead: 0|1;
};

export const ProcedureTeamRepo = {
  list(orderId: string): Promise<TeamMember[]> {
    return getAllAsync<TeamMember>(
      "SELECT * FROM procedure_team_members WHERE isDeleted=0 AND orderId=? ORDER BY isLead DESC, createdAt ASC",
      [orderId]
    );
  },

  async add(orderId: string, employeeId: string, teamRole: string, isLead: boolean) {
    const now = Date.now();
    await runAsync(
      `INSERT INTO procedure_team_members (id, createdAt, updatedAt, isDeleted, deletedAt, orderId, employeeId, teamRole, isLead)
       VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?)`,
      [id(), now, now, orderId, employeeId, teamRole, isLead ? 1 : 0]
    );
  },

  async clear(orderId: string) {
    const now = Date.now();
    await runAsync(
      "UPDATE procedure_team_members SET isDeleted=1, deletedAt=?, updatedAt=? WHERE orderId=? AND isDeleted=0",
      [now, now, orderId]
    );
  },
};


cat > src/data/repositories/patientEvents.repo.ts 
import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type PatientEvent = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;

  patientId: string;
  type: "DEATH";
  eventAt: number;
  declaredByEmployeeId: string;
  notes?: string|null;
};

export const PatientEventsRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<PatientEvent>(
      "SELECT * FROM patient_events WHERE isDeleted=0 AND patientId=? ORDER BY eventAt DESC",
      [patientId]
    );
  },

  async declareDeath(patientId: string, declaredByEmployeeId: string, notes: string | null) {
    const now = Date.now();
    const row: PatientEvent = {
      id: id(),
      createdAt: now,
      updatedAt: now,
      isDeleted: 0,
      patientId,
      type: "DEATH",
      eventAt: now,
      declaredByEmployeeId,
      notes,
    };
    await runAsync(
      `INSERT INTO patient_events (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, type, eventAt, declaredByEmployeeId, notes
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?)`,
      [row.id, row.createdAt, row.updatedAt, row.patientId, row.type, row.eventAt, row.declaredByEmployeeId, row.notes ?? null]
    );
    return row;
  },
};


cat > src/data/repositories/employees.admin.repo.ts 
import { getFirstAsync, runAsync } from "@/data/db/sqlite";

export const EmployeesAdminRepo = {
  getById(id: string) {
    return getFirstAsync<any>("SELECT * FROM employees WHERE isDeleted=0 AND id=?", [id]);
  },

  async setCanBuildTeam(employeeId: string, can: boolean) {
    const now = Date.now();
    await runAsync("UPDATE employees SET canBuildTeam=?, updatedAt=? WHERE id=?", [can ? 1 : 0, now, employeeId]);
  },

  async terminate(employeeId: string, terminatedByEmployeeId: string) {
    const now = Date.now();
    // bloqueia login e mantém histórico
    await runAsync(
      "UPDATE employees SET status='TERMINATED', terminatedAt=?, terminatedByEmployeeId=?, updatedAt=? WHERE id=?",
      [now, terminatedByEmployeeId, terminatedByEmployeeId, now, employeeId]
    );
  },
};



 Permission helpers
domain/permissions/permissions.ts 

import { Role } from "@/domain/enums/roles";

export function canManageSurgeryTeam(args: {
  role: Role;
  isRoot: boolean;
  isDoctorLead: boolean;
  doctorHasPermissionFlag: boolean;
  isCoordinator: boolean;
}) {
  // Regra do usuário:
  // - Root tem tudo
  // - Médico parcial: só se Root liberou (flag canBuildTeam) E ele for o responsável (lead)
  // - Coordenação (papel/role) pode organizar equipe
  if (args.isRoot) return true;
  if (args.isCoordinator) return true;
  if (args.role === Role.DOCTOR && args.isDoctorLead && args.doctorHasPermissionFlag) return true;
  return false;
}

export function canSeeOrder(args: { isRoot: boolean; isTeamMember: boolean; isDoctorOfPatient: boolean; role: Role }) {
  // Equipe selecionada vê o que será feito
  // Médico só vê se marcado no paciente (você já pediu essa regra)
  if (args.isRoot) return true;
  if (args.isTeamMember) return true;
  if (args.role === Role.DOCTOR && args.isDoctorOfPatient) return true;
  return false;
}


# ---------------------------
# 4) PDF report generator (HTML -> PDF)
cat > src/services/reports/patientReport.service.ts 
import * as Print from "expo-print";
import * as Sharing from "expo-sharing";

export async function generateAndSharePdf(args: {
  title: string;
  html: string;
}) {
  const { uri } = await Print.printToFileAsync({
    html: `
      <html>
        <head>
          <meta charset="utf-8"/>
          <style>
            body { font-family: Arial, sans-serif; padding: 18px; }
            h1 { margin: 0 0 10px 0; }
            .block { border: 1px solid #ddd; padding: 12px; border-radius: 10px; margin: 10px 0; }
            .muted { color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <h1>${args.title}</h1>
          ${args.html}
        </body>
      </html>
    `,
  });

  if (await Sharing.isAvailableAsync()) {
    await Sharing.shareAsync(uri, { mimeType: "application/pdf" });
  }
  return uri;
}


# ---------------------------
# 5) RH / Auth: impedir login se status != ACTIVE
# (ajuste simples no auth service - compatível com seu padrão)
cat > src/services/auth/auth.service.ts 
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { simpleHash } from "@/utils/hash";
import { auditLog } from "@/services/audit/audit.service";

export async function login(email: string, password: string) {
  const emp: any = await EmployeesRepo.getByEmail(email);
  if (!emp) throw new Error("Usuário não encontrado");

  if (emp.status && emp.status !== "ACTIVE") {
    throw new Error("Usuário bloqueado/desligado (RH)");
  }

  const hash = simpleHash(password);
  if (emp.passwordHash !== hash) throw new Error("Senha inválida");

  await auditLog({
    actorEmployeeId: emp.id,
    actorName: emp.name,
    action: "LOGIN",
    entity: "EMPLOYEE",
    entityId: emp.id,
    meta: { email },
  });

  return emp;
}

export async function logout() {
  return true;
}



# 6) UI: nova tela "Ordens" e detalhe (com equipe)
# Adiciona ao Tabs: Procedures
cat > src/navigation/MainTabs.tsx
import React from "react";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";

import { DashboardScreen } from "@/ui/screens/DashboardScreen";
import { EmployeesScreen } from "@/ui/screens/EmployeesScreen";
import { PatientsScreen } from "@/ui/screens/PatientsScreen";
import { AppointmentsScreen } from "@/ui/screens/AppointmentsScreen";
import { ServicesScreen } from "@/ui/screens/ServicesScreen";
import { AuditScreen } from "@/ui/screens/AuditScreen";
import { ProcedureOrdersScreen } from "@/ui/screens/ProcedureOrdersScreen";

type TabParamList = {
  Dashboard: undefined;
  Employees: undefined;
  Patients: undefined;
  Appointments: undefined;
  Procedures: undefined;
  Services: undefined;
  Audit: undefined;
};

const Tab = createBottomTabNavigator<TabParamList>();

export function MainTabs() {
  return (
    <Tab.Navigator screenOptions={{ headerShown: true }}>
      <Tab.Screen name="Dashboard" component={DashboardScreen} options={{ title: "Início" }} />
      <Tab.Screen name="Employees" component={EmployeesScreen} options={{ title: "Funcionários" }} />
      <Tab.Screen name="Patients" component={PatientsScreen} options={{ title: "Pacientes" }} />
      <Tab.Screen name="Appointments" component={AppointmentsScreen} options={{ title: "Agenda" }} />
      <Tab.Screen name="Procedures" component={ProcedureOrdersScreen} options={{ title: "Ordens" }} />
      <Tab.Screen name="Services" component={ServicesScreen} options={{ title: "Serviços" }} />
      <Tab.Screen name="Audit" component={AuditScreen} options={{ title: "Histórico" }} />
    </Tab.Navigator>
  );
}
EOF

# Navigation routes (OrderForm + OrderDetail)
cat > src/navigation/types.ts 
export type RootStackParamList = {
  Auth: undefined;
  Mfa: undefined;
  Main: undefined;

  EmployeeForm: { id?: string } | undefined;
  EmployeeDetail: { id: string };

  PatientForm: { id?: string } | undefined;
  ServiceForm: { id?: string } | undefined;
  AppointmentForm: { id?: string } | undefined;

  PatientChart: { patientId: string };

  ProcedureOrderForm: { id?: string } | undefined;
  ProcedureOrderDetail: { id: string };

  Audit: undefined;
};


cat > src/navigation/RootNavigator.tsx 
import React from "react";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { RootStackParamList } from "./types";
import { AuthScreen } from "@/ui/screens/AuthScreen";
import { MfaScreen } from "@/ui/screens/MfaScreen";
import { MainTabs } from "./MainTabs";

import { EmployeeFormScreen } from "@/ui/screens/forms/EmployeeFormScreen";
import { EmployeeDetailScreen } from "@/ui/screens/EmployeeDetailScreen";
import { PatientFormScreen } from "@/ui/screens/forms/PatientFormScreen";
import { ServiceFormScreen } from "@/ui/screens/forms/ServiceFormScreen";
import { AppointmentFormScreen } from "@/ui/screens/forms/AppointmentFormScreen";
import { PatientChartScreen } from "@/ui/screens/PatientChartScreen";

import { ProcedureOrderFormScreen } from "@/ui/screens/forms/ProcedureOrderFormScreen";
import { ProcedureOrderDetailScreen } from "@/ui/screens/ProcedureOrderDetailScreen";

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator(props: { initialRoute: keyof RootStackParamList }) {
  return (
    <Stack.Navigator initialRouteName={props.initialRoute}>
      <Stack.Screen name="Auth" component={AuthScreen} options={{ title: "Login" }} />
      <Stack.Screen name="Mfa" component={MfaScreen} options={{ title: "Duplo fator (demo)" }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />

      <Stack.Screen name="EmployeeDetail" component={EmployeeDetailScreen} options={{ title: "Funcionário" }} />
      <Stack.Screen name="EmployeeForm" component={EmployeeFormScreen} options={{ title: "Funcionário" }} />

      <Stack.Screen name="PatientForm" component={PatientFormScreen} options={{ title: "Paciente" }} />
      <Stack.Screen name="ServiceForm" component={ServiceFormScreen} options={{ title: "Serviço" }} />
      <Stack.Screen name="AppointmentForm" component={AppointmentFormScreen} options={{ title: "Agendamento" }} />
      <Stack.Screen name="PatientChart" component={PatientChartScreen} options={{ title: "Prontuário / Exames" }} />

      <Stack.Screen name="ProcedureOrderForm" component={ProcedureOrderFormScreen} options={{ title: "Ordem" }} />
      <Stack.Screen name="ProcedureOrderDetail" component={ProcedureOrderDetailScreen} options={{ title: "Ordem / Equipe" }} />
    </Stack.Navigator>
  );
}


# Screens: list orders
cat > src/ui/screens/ProcedureOrdersScreen.tsx 
import React, { useEffect, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { ProcedureOrdersRepo, ProcedureOrder } from "@/data/repositories/procedureOrders.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function ProcedureOrdersScreen({ navigation }: Props) {
  const [items, setItems] = useState<(ProcedureOrder & { patientName?: string })[]>([]);

  async function load() {
    const orders = await ProcedureOrdersRepo.list();
    const vm = [];
    for (const o of orders) {
      const p = await PatientsRepo.getById(o.patientId);
      vm.push({ ...o, patientName: p?.name ?? "Paciente?" });
    }
    setItems(vm);
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Ordens / Procedimentos</Text>
      <Button title="Nova ordem" onPress={() => navigation.navigate("ProcedureOrderForm")} />

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${item.title} — ${item.patientName}`}
            subtitle={`${item.status} | ${item.priority}`}
            right={<Button title="Abrir" variant="ghost" onPress={() => navigation.navigate("ProcedureOrderDetail", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}


# Form: create/edit order (médico solicitante = usuário logado se for médico; admin pode criar também)
cat > src/ui/screens/forms/ProcedureOrderFormScreen.tsx 
import React, { useEffect, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";
import { ProcedureOrdersRepo } from "@/data/repositories/procedureOrders.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { Role } from "@/domain/enums/roles";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "ProcedureOrderForm">;

export function ProcedureOrderFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const role = useAuthStore((s) => s.role)!;

  const id = route.params?.id;
  const editing = !!id;

  const [patientId, setPatientId] = useState<string | null>(null);
  const [patientsOpt, setPatientsOpt] = useState<any[]>([]);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [priority, setPriority] = useState<"LOW"|"MEDIUM"|"HIGH"|"URGENT">("MEDIUM");
  const [plannedAt, setPlannedAt] = useState(""); // timestamp opcional
  const [status, setStatus] = useState<"REQUESTED"|"APPROVED"|"SCHEDULED"|"DONE"|"CANCELED">("REQUESTED");

  useEffect(() => {
    (async () => {
      const patients = await PatientsRepo.list();
      setPatientsOpt(patients.map((p) => ({ id: p.id, label: p.name, subtitle: `Doc: ${p.documentId}` })));

      if (editing) {
        const cur = await ProcedureOrdersRepo.getById(id!);
        if (!cur) return;
        setPatientId(cur.patientId);
        setTitle(cur.title);
        setDescription(cur.description ?? "");
        setPriority(cur.priority);
        setPlannedAt(cur.plannedAt ? String(cur.plannedAt) : "");
        setStatus(cur.status);
      }
    })();
  }, [editing, id]);

  async function save() {
    if (!patientId) return;

    if (!editing) {
      const created = await ProcedureOrdersRepo.create({
        patientId,
        requestedByDoctorId: role === Role.DOCTOR ? actorId : actorId, // admin também pode registrar
        coordinatorEmployeeId: null,
        title,
        description: description || null,
        priority,
        plannedAt: plannedAt ? Number(plannedAt) : null,
        status,
        deletedAt: null,
      });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "PROCEDURE_ORDER", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await ProcedureOrdersRepo.getById(id!);
    const next = await ProcedureOrdersRepo.update(id!, {
      patientId,
      title,
      description: description || null,
      priority,
      plannedAt: plannedAt ? Number(plannedAt) : null,
      status,
    });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "PROCEDURE_ORDER", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir ordem (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      { text: "Excluir", style: "destructive", onPress: async () => {
        const before = await ProcedureOrdersRepo.getById(id!);
        await ProcedureOrdersRepo.softDelete(id!);
        await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "PROCEDURE_ORDER", entityId: id!, before });
        navigation.goBack();
      }},
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar ordem" : "Nova ordem"}</Text>

        <SelectList label="Paciente" valueId={patientId} onChange={setPatientId} options={patientsOpt} placeholder="Selecione o paciente" />

        <Input label="Título (ex: Cirurgia...)" value={title} onChangeText={setTitle} />
        <Input label="Descrição (opcional)" value={description} onChangeText={setDescription} />
        <Input label="Prioridade (LOW/MEDIUM/HIGH/URGENT)" value={priority} onChangeText={(t) => setPriority(t as any)} />
        <Input label="Data prevista (timestamp ms opcional)" value={plannedAt} onChangeText={setPlannedAt} />
        <Input label="Status (REQUESTED/APPROVED/SCHEDULED/DONE/CANCELED)" value={status} onChangeText={(t) => setStatus(t as any)} />

        <Button title="Salvar" onPress={save} disabled={!patientId || !title.trim()} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}


# Detail: equipe + permissões + PDF + óbito
cat > src/ui/screens/ProcedureOrderDetailScreen.tsx 
import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";
import { Input } from "@/ui/components/Input";

import { ProcedureOrdersRepo } from "@/data/repositories/procedureOrders.repo";
import { ProcedureTeamRepo } from "@/data/repositories/procedureTeam.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { EmployeesAdminRepo } from "@/data/repositories/employees.admin.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { PatientEventsRepo } from "@/data/repositories/patientEvents.repo";

import { generateAndSharePdf } from "@/services/reports/patientReport.service";
import { auditLog } from "@/services/audit/audit.service";
import { useAuthStore } from "@/store/auth.store";
import { Role } from "@/domain/enums/roles";
import { canManageSurgeryTeam, canSeeOrder } from "@/domain/permissions/permissions";

import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "ProcedureOrderDetail">;

export function ProcedureOrderDetailScreen({ navigation, route }: Props) {
  const { id } = route.params;

  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const role = useAuthStore((s) => s.role)!;

  const [order, setOrder] = useState<any>(null);
  const [patient, setPatient] = useState<any>(null);
  const [team, setTeam] = useState<any[]>([]);
  const [employeesOpt, setEmployeesOpt] = useState<any[]>([]);
  const [assignEmpId, setAssignEmpId] = useState<string | null>(null);
  const [teamRole, setTeamRole] = useState("ASSISTANT");
  const [lead, setLead] = useState(false);

  const [doctorOfPatient, setDoctorOfPatient] = useState(false);
  const [isTeamMember, setIsTeamMember] = useState(false);
  const [doctorFlag, setDoctorFlag] = useState(false);

  async function load() {
    const o = await ProcedureOrdersRepo.getById(id);
    setOrder(o);
    if (!o) return;

    const p = await PatientsRepo.getById(o.patientId);
    setPatient(p);

    const t = await ProcedureTeamRepo.list(id);
    setTeam(t);

    setIsTeamMember(t.some((m) => m.employeeId === actorId));

    const isDoc = await PatientDoctorsRepo.isDoctorOfPatient(o.patientId, actorId);
    setDoctorOfPatient(isDoc);

    const actor = await EmployeesAdminRepo.getById(actorId);
    setDoctorFlag(!!actor?.canBuildTeam);

    const emps = await EmployeesRepo.list();
    setEmployeesOpt(emps.map((e) => ({ id: e.id, label: e.name, subtitle: `${e.role} | ${e.jobTitle}` })));
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, id]);

  const leadDoctorId = useMemo(() => {
    const leadRow = team.find((m) => m.isLead === 1);
    return leadRow?.employeeId ?? order?.requestedByDoctorId;
  }, [team, order]);

  const isRoot = role === Role.ROOT_ADMIN;
  const isCoordinator = role === (Role as any).COORDINATOR_ADMIN || role === (Role as any).SURGERY_COORDINATOR;

  const canSee = useMemo(() => {
    return canSeeOrder({ isRoot, isTeamMember, isDoctorOfPatient: doctorOfPatient, role });
  }, [isRoot, isTeamMember, doctorOfPatient, role]);

  const canManageTeam = useMemo(() => {
    const isLeadDoctor = role === Role.DOCTOR && actorId === leadDoctorId;
    return canManageSurgeryTeam({
      role,
      isRoot,
      isDoctorLead: isLeadDoctor,
      doctorHasPermissionFlag: doctorFlag,
      isCoordinator,
    });
  }, [role, isRoot, actorId, leadDoctorId, doctorFlag, isCoordinator]);

  async function addMember() {
    if (!assignEmpId) return;
    if (!canManageTeam) return;

    // se marcar como lead, vamos limpar lead anterior (simples: limpar tudo e refazer é pesado; aqui só adiciona)
    await ProcedureTeamRepo.add(id, assignEmpId, teamRole, lead);

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "UPDATE",
      entity: "PROCEDURE_ORDER",
      entityId: id,
      meta: { teamAdd: true, employeeId: assignEmpId, teamRole, lead },
    });

    setAssignEmpId(null);
    setLead(false);
    await load();
  }

  async function clearTeam() {
    if (!canManageTeam) return;
    Alert.alert("Limpar equipe", "Remover toda a equipe desta ordem?", [
      { text: "Cancelar", style: "cancel" },
      { text: "OK", style: "destructive", onPress: async () => { await ProcedureTeamRepo.clear(id); await load(); } },
    ]);
  }

  async function exportPdf() {
    if (!order || !patient) return;

    const html = `
      <div class="block">
        <div><b>Paciente:</b> ${patient.name}</div>
        <div><b>Documento:</b> ${patient.documentId}</div>
        <div><b>Telefone:</b> ${patient.phone}</div>
      </div>
      <div class="block">
        <div><b>Ordem:</b> ${order.title}</div>
        <div><b>Status:</b> ${order.status} | <b>Prioridade:</b> ${order.priority}</div>
        <div><b>Descrição:</b> ${order.description ?? "-"}</div>
      </div>
      <div class="block">
        <div><b>Equipe:</b></div>
        ${team.map((m) => `<div>- ${m.employeeId} | ${m.teamRole} ${m.isLead ? "(RESPONSÁVEL)" : ""}</div>`).join("")}
        <div class="muted">Obs: IDs podem virar nomes no próximo patch.</div>
      </div>
    `;

    await generateAndSharePdf({ title: "Relatório - Ordem/Equipe", html });

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "EXPORT",
      entity: "PROCEDURE_ORDER",
      entityId: id,
      meta: { pdf: true },
    });
  }

  async function declareDeath() {
    if (!patient) return;
    Alert.alert("Declaração de óbito", "Confirmar óbito deste paciente? Isso gera histórico.", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Confirmar",
        style: "destructive",
        onPress: async () => {
          const ev = await PatientEventsRepo.declareDeath(patient.id, actorId, "Óbito declarado no app.");
          await auditLog({
            actorEmployeeId: actorId,
            actorName,
            action: "UPDATE",
            entity: "PATIENT",
            entityId: patient.id,
            meta: { death: true, eventId: ev.id },
            after: ev,
          });
          Alert.alert("OK", "Óbito registrado no histórico.");
        },
      },
    ]);
  }

  if (!order) return <Screen><Text>Carregando...</Text></Screen>;

  if (!canSee) {
    return (
      <Screen>
        <Text style={{ fontWeight: "900" }}>Acesso restrito</Text>
        <Text style={{ color: "#666" }}>
          Somente Root, equipe selecionada, ou médico marcado do paciente pode visualizar esta ordem.
        </Text>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 18 }}>{order.title}</Text>
        <Text>Status: {order.status} | Prioridade: {order.priority}</Text>
        <Text style={{ color: "#666" }}>{order.description ?? "-"}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Equipe (múltiplos médicos e funções)</Text>
        {team.map((m) => (
          <View key={m.id} style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>{m.employeeId}</Text>
            <Text>Função: {m.teamRole} {m.isLead ? "(RESPONSÁVEL)" : ""}</Text>
          </View>
        ))}

        {canManageTeam ? (
          <View style={{ gap: 10 }}>
            <SelectList label="Adicionar membro" valueId={assignEmpId} onChange={setAssignEmpId} options={employeesOpt} />
            <Input label="Função (LEAD_SURGEON/ASSISTANT/ANESTHETIST/NURSE/TECH/OTHER)" value={teamRole} onChangeText={setTeamRole} />
            <Button title={lead ? "✓ Marcar como responsável" : "Marcar como responsável"} variant={lead ? "primary" : "ghost"} onPress={() => setLead(!lead)} />
            <Button title="Adicionar na equipe" onPress={addMember} disabled={!assignEmpId} />
            <Button title="Limpar equipe" variant="danger" onPress={clearTeam} />
          </View>
        ) : (
          <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>Sem permissão para alterar equipe</Text>
            <Text style={{ color: "#666" }}>
              Root e Coordenação podem sempre. Médico só se Root liberou e ele for o responsável.
            </Text>
          </View>
        )}

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Button title="Exportar PDF (detalhado)" onPress={exportPdf} />
        <Button title="Declarar óbito (gera histórico)" variant="danger" onPress={declareDeath} />
      </ScrollView>
    </Screen>
  );
}

