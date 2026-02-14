#!/usr/bin/env bash
set -euo pipefail

# ---------- 1) MIGRATION: adiciona tabelas novas (skills/procedimentos + prontuário + exames)
cat > src/data/db/migrations.ts <<'EOF'
import { execAsync, getFirstAsync, runAsync } from "./sqlite";
import { simpleHash } from "@/utils/hash";

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

    CREATE TABLE IF NOT EXISTS beds (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      code TEXT NOT NULL,
      sector TEXT NOT NULL,
      status TEXT NOT NULL,
      patientId TEXT,
      expectedReleaseAt INTEGER
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

    -- NOVO: vínculos do que o funcionário pode realizar (procedimentos/serviços)
    CREATE TABLE IF NOT EXISTS employee_service_types (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      employeeId TEXT NOT NULL,
      serviceTypeId TEXT NOT NULL
    );

    -- NOVO: prontuário (registro clínico)
    CREATE TABLE IF NOT EXISTS medical_records (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      patientId TEXT NOT NULL,
      summary TEXT,
      diagnosis TEXT,
      notes TEXT
    );

    -- NOVO: exames (a fazer / feitos)
    CREATE TABLE IF NOT EXISTS exams (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      patientId TEXT NOT NULL,
      requestedByEmployeeId TEXT NOT NULL,
      appointmentId TEXT,
      name TEXT NOT NULL,
      status TEXT NOT NULL,
      scheduledAt INTEGER,
      result TEXT
    );
  `);

  const seeded = await getFirstAsync<{ value: string }>("SELECT value FROM meta WHERE key='seeded'");
  if (!seeded?.value) {
    const now = Date.now();
    await runAsync("INSERT OR REPLACE INTO meta(key,value) VALUES('seeded','1')");

    // ROOT: root@hospital.com / 1234
    const hash = simpleHash("1234");
    await runAsync(
      `INSERT INTO employees (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        employeeNumber, name, phone, email, role, jobTitle, sector,
        passwordHash, mfaEnabled, mfaPhoneVerified, mfaEmailVerified, mfaImageToken
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, NULL)`,
      ["root-1", now, now, "0001", "Root Admin", "000000000", "root@hospital.com", "ROOT_ADMIN", "Root", "Administração", hash]
    );
  }
}
EOF

# ---------- 2) REPOS NOVOS
cat > src/data/repositories/employeeSkills.repo.ts <<'EOF'
import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type EmployeeSkill = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0 | 1;
  deletedAt?: number | null;
  employeeId: string;
  serviceTypeId: string;
};

export const EmployeeSkillsRepo = {
  listByEmployee(employeeId: string) {
    return getAllAsync<EmployeeSkill>(
      "SELECT * FROM employee_service_types WHERE isDeleted=0 AND employeeId=? ORDER BY createdAt DESC",
      [employeeId]
    );
  },

  async setSkills(employeeId: string, serviceTypeIds: string[]) {
    // estratégia simples: apaga (soft) e recria
    const now = Date.now();
    await runAsync(
      "UPDATE employee_service_types SET isDeleted=1, deletedAt=?, updatedAt=? WHERE employeeId=? AND isDeleted=0",
      [now, now, employeeId]
    );

    for (const sid of serviceTypeIds) {
      const rowId = id();
      await runAsync(
        `INSERT INTO employee_service_types (id, createdAt, updatedAt, isDeleted, deletedAt, employeeId, serviceTypeId)
         VALUES (?, ?, ?, 0, NULL, ?, ?)`,
        [rowId, now, now, employeeId, sid]
      );
    }
  },
};
EOF

cat > src/data/repositories/medicalRecords.repo.ts <<'EOF'
import { getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type MedicalRecord = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number | null;
  patientId: string;
  summary?: string | null;
  diagnosis?: string | null;
  notes?: string | null;
};

export const MedicalRecordsRepo = {
  getByPatient(patientId: string) {
    return getFirstAsync<MedicalRecord>(
      "SELECT * FROM medical_records WHERE isDeleted=0 AND patientId=?",
      [patientId]
    );
  },

  async upsert(patientId: string, patch: Partial<MedicalRecord>) {
    const current = await this.getByPatient(patientId);
    const now = Date.now();

    if (!current) {
      const row: MedicalRecord = {
        id: id(),
        createdAt: now,
        updatedAt: now,
        isDeleted: 0,
        patientId,
        summary: patch.summary ?? null,
        diagnosis: patch.diagnosis ?? null,
        notes: patch.notes ?? null,
      };
      await runAsync(
        `INSERT INTO medical_records (id, createdAt, updatedAt, isDeleted, deletedAt, patientId, summary, diagnosis, notes)
         VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?)`,
        [row.id, row.createdAt, row.updatedAt, row.patientId, row.summary ?? null, row.diagnosis ?? null, row.notes ?? null]
      );
      return row;
    }

    const next = { ...current, ...patch, updatedAt: now };
    await runAsync(
      "UPDATE medical_records SET updatedAt=?, summary=?, diagnosis=?, notes=? WHERE id=?",
      [next.updatedAt, next.summary ?? null, next.diagnosis ?? null, next.notes ?? null, current.id]
    );
    return next;
  },
};
EOF

cat > src/data/repositories/exams.repo.ts <<'EOF'
import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type Exam = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;
  patientId: string;
  requestedByEmployeeId: string;
  appointmentId?: string | null;
  name: string;
  status: "PLANNED" | "DONE";
  scheduledAt?: number | null;
  result?: string | null;
};

export const ExamsRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<Exam>(
      "SELECT * FROM exams WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
      [patientId]
    );
  },

  async create(e: Omit<Exam,"id"|"createdAt"|"updatedAt"|"isDeleted">) {
    const now = Date.now();
    const row: Exam = { ...e, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO exams (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, requestedByEmployeeId, appointmentId,
        name, status, scheduledAt, result
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?)`,
      [
        row.id, row.createdAt, row.updatedAt,
        row.patientId, row.requestedByEmployeeId, row.appointmentId ?? null,
        row.name, row.status, row.scheduledAt ?? null, row.result ?? null
      ]
    );
    return row;
  },

  async markDone(examId: string, result: string) {
    const now = Date.now();
    await runAsync(
      "UPDATE exams SET updatedAt=?, status='DONE', result=? WHERE id=?",
      [now, result, examId]
    );
  },

  softDelete(examId: string) {
    const now = Date.now();
    return runAsync("UPDATE exams SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, examId]);
  },
};
EOF

# ---------- 3) Ajuste EmployeesRepo: lista médicos (DOCTOR) e lista enfermagem (NURSE)
cat > src/data/repositories/employees.repo.ts <<'EOF'
import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { Employee } from "@/domain/entities/employee";
import { id } from "@/utils/id";

export const EmployeesRepo = {
  list(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 ORDER BY name");
  },
  listDoctors(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 AND role='DOCTOR' ORDER BY name");
  },
  listNurses(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 AND role='NURSE' ORDER BY name");
  },
  getById(empId: string): Promise<Employee | null> {
    return getFirstAsync<Employee>("SELECT * FROM employees WHERE id=? AND isDeleted=0", [empId]);
  },
  getByEmail(email: string): Promise<Employee | null> {
    return getFirstAsync<Employee>("SELECT * FROM employees WHERE email=? AND isDeleted=0", [email]);
  },
  async create(e: Omit<Employee, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<Employee> {
    const now = Date.now();
    const emp: Employee = { ...e, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO employees (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        employeeNumber, name, phone, email, role, jobTitle, sector,
        passwordHash, mfaEnabled, mfaPhoneVerified, mfaEmailVerified, mfaImageToken
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        emp.id, emp.createdAt, emp.updatedAt,
        emp.employeeNumber, emp.name, emp.phone, emp.email, emp.role, emp.jobTitle, emp.sector,
        emp.passwordHash, emp.mfaEnabled, emp.mfaPhoneVerified, emp.mfaEmailVerified, emp.mfaImageToken ?? null,
      ]
    );
    return emp;
  },
  async update(empId: string, patch: Partial<Employee>): Promise<Employee | null> {
    const cur = await this.getById(empId);
    if (!cur) return null;
    const next: Employee = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE employees SET
        updatedAt=?,
        employeeNumber=?, name=?, phone=?, email=?, role=?, jobTitle=?, sector=?,
        passwordHash=?, mfaEnabled=?, mfaPhoneVerified=?, mfaEmailVerified=?, mfaImageToken=?
      WHERE id=?`,
      [
        next.updatedAt,
        next.employeeNumber, next.name, next.phone, next.email, next.role, next.jobTitle, next.sector,
        next.passwordHash, next.mfaEnabled, next.mfaPhoneVerified, next.mfaEmailVerified, next.mfaImageToken ?? null,
        empId,
      ]
    );
    return next;
  },
  softDelete(empId: string) {
    const now = Date.now();
    return runAsync("UPDATE employees SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, empId]);
  },
};
EOF

# ---------- 4) UI: Tabs completos + Rotas de Forms e Prontuário
cat > src/navigation/types.ts <<'EOF'
export type RootStackParamList = {
  Auth: undefined;
  Mfa: undefined;
  Main: undefined;

  EmployeeForm: { id?: string } | undefined;
  PatientForm: { id?: string } | undefined;
  ServiceForm: { id?: string } | undefined;
  AppointmentForm: { id?: string } | undefined;

  PatientChart: { patientId: string };     // prontuário + exames
  Audit: undefined;
};
EOF

cat > src/navigation/MainTabs.tsx <<'EOF'
import React from "react";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { DashboardScreen } from "@/ui/screens/DashboardScreen";
import { EmployeesScreen } from "@/ui/screens/EmployeesScreen";
import { PatientsScreen } from "@/ui/screens/PatientsScreen";
import { ServicesScreen } from "@/ui/screens/ServicesScreen";
import { AppointmentsScreen } from "@/ui/screens/AppointmentsScreen";
import { AuditScreen } from "@/ui/screens/AuditScreen";

const Tab = createBottomTabNavigator();

export function MainTabs() {
  return (
    <Tab.Navigator screenOptions={{ headerShown: true }}>
      <Tab.Screen name="Dashboard" component={DashboardScreen} options={{ title: "Início" }} />
      <Tab.Screen name="Employees" component={EmployeesScreen} options={{ title: "Funcionários" }} />
      <Tab.Screen name="Patients" component={PatientsScreen} options={{ title: "Pacientes" }} />
      <Tab.Screen name="Appointments" component={AppointmentsScreen} options={{ title: "Agenda" }} />
      <Tab.Screen name="Services" component={ServicesScreen} options={{ title: "Serviços" }} />
      <Tab.Screen name="Audit" component={AuditScreen} options={{ title: "Histórico" }} />
    </Tab.Navigator>
  );
}
EOF

cat > src/navigation/RootNavigator.tsx <<'EOF'
import React from "react";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { RootStackParamList } from "./types";
import { AuthScreen } from "@/ui/screens/AuthScreen";
import { MfaScreen } from "@/ui/screens/MfaScreen";
import { MainTabs } from "./MainTabs";
import { EmployeeFormScreen } from "@/ui/screens/forms/EmployeeFormScreen";
import { PatientFormScreen } from "@/ui/screens/forms/PatientFormScreen";
import { ServiceFormScreen } from "@/ui/screens/forms/ServiceFormScreen";
import { AppointmentFormScreen } from "@/ui/screens/forms/AppointmentFormScreen";
import { PatientChartScreen } from "@/ui/screens/PatientChartScreen";

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator(props: { initialRoute: keyof RootStackParamList }) {
  return (
    <Stack.Navigator initialRouteName={props.initialRoute}>
      <Stack.Screen name="Auth" component={AuthScreen} options={{ title: "Login" }} />
      <Stack.Screen name="Mfa" component={MfaScreen} options={{ title: "Duplo fator (demo)" }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />

      <Stack.Screen name="EmployeeForm" component={EmployeeFormScreen} options={{ title: "Funcionário" }} />
      <Stack.Screen name="PatientForm" component={PatientFormScreen} options={{ title: "Paciente" }} />
      <Stack.Screen name="ServiceForm" component={ServiceFormScreen} options={{ title: "Serviço" }} />
      <Stack.Screen name="AppointmentForm" component={AppointmentFormScreen} options={{ title: "Agendamento" }} />

      <Stack.Screen name="PatientChart" component={PatientChartScreen} options={{ title: "Prontuário / Exames" }} />
    </Stack.Navigator>
  );
}
EOF

# ---------- 5) Screens: Funcionários, Pacientes, Serviços, Agenda + Prontuário
cat > src/ui/screens/EmployeesScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { FlatList, Text, TextInput, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { Employee } from "@/domain/entities/employee";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function EmployeesScreen({ navigation }: Props) {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<Employee[]>([]);

  async function load() {
    setItems(await EmployeesRepo.list());
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  const filtered = items.filter((e) => {
    const s = q.trim().toLowerCase();
    if (!s) return true;
    return (e.name + e.employeeNumber + e.sector + e.jobTitle + e.role).toLowerCase().includes(s);
  });

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Funcionários</Text>
      <TextInput
        placeholder="Buscar por nome, número, setor..."
        value={q}
        onChangeText={setQ}
        style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12 }}
      />

      <Button title="Novo funcionário" onPress={() => navigation.navigate("EmployeeForm")} />

      <FlatList
        data={filtered}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${item.employeeNumber} - ${item.name}`}
            subtitle={`${item.role} | ${item.jobTitle} | ${item.sector}`}
            right={<Button title="Editar" variant="ghost" onPress={() => navigation.navigate("EmployeeForm", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}
EOF

cat > src/ui/screens/PatientsScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { Patient } from "@/domain/entities/patient";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function PatientsScreen({ navigation }: Props) {
  const [items, setItems] = useState<Patient[]>([]);

  async function load() {
    setItems(await PatientsRepo.list());
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Pacientes</Text>

      <View style={{ flexDirection: "row", gap: 10 }}>
        <Button title="Novo paciente" onPress={() => navigation.navigate("PatientForm")} />
      </View>

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={item.name}
            subtitle={`Doc: ${item.documentId} | Tel: ${item.phone}`}
            right={
              <View style={{ gap: 8 }}>
                <Button title="Prontuário" variant="ghost" onPress={() => navigation.navigate("PatientChart", { patientId: item.id })} />
                <Button title="Editar" variant="ghost" onPress={() => navigation.navigate("PatientForm", { id: item.id })} />
              </View>
            }
          />
        )}
      />
    </Screen>
  );
}
EOF

cat > src/ui/screens/ServicesScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { FlatList, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { ServiceType } from "@/domain/entities/serviceType";
import { centsToBRL } from "@/utils/money";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function ServicesScreen({ navigation }: Props) {
  const [items, setItems] = useState<ServiceType[]>([]);

  async function load() {
    setItems(await ServicesRepo.list());
  }
  React.useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Serviços / Tratamentos / Preços</Text>
      <Button title="Novo serviço" onPress={() => navigation.navigate("ServiceForm")} />

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={item.name}
            subtitle={`${item.treatment} | ${centsToBRL(item.priceCents)}`}
            right={<Button title="Editar" variant="ghost" onPress={() => navigation.navigate("ServiceForm", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}
EOF

cat > src/ui/screens/AppointmentsScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { AppointmentsRepo } from "@/data/repositories/appointments.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { formatDateTime } from "@/utils/dates";
import { startOfDay, addDays } from "date-fns";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function AppointmentsScreen({ navigation }: Props) {
  const [cursor, setCursor] = useState<Date>(new Date());
  const [items, setItems] = useState<any[]>([]);

  const start = startOfDay(cursor).getTime();
  const end = addDays(new Date(start), 1).getTime();

  async function load() {
    const appts = await AppointmentsRepo.listBetween(start, end);
    const vm = [];
    for (const a of appts) {
      const p = await PatientsRepo.getById(a.patientId);
      const d = await EmployeesRepo.getById(a.doctorEmployeeId);
      const s = await ServicesRepo.getById(a.serviceTypeId);
      vm.push({
        ...a,
        patientName: p?.name ?? "Paciente?",
        doctorName: d?.name ?? "Médico?",
        serviceName: s?.name ?? "Serviço?",
      });
    }
    setItems(vm);
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, start, end]);

  const dateLabel = useMemo(() => formatDateTime(start).split(" ")[0], [start]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Agenda do dia ({dateLabel})</Text>
      <View style={{ flexDirection: "row", gap: 10 }}>
        <Button title="Dia -1" variant="ghost" onPress={() => setCursor(new Date(cursor.getTime() - 86400000))} />
        <Button title="Dia +1" variant="ghost" onPress={() => setCursor(new Date(cursor.getTime() + 86400000))} />
      </View>

      <Button title="Novo agendamento" onPress={() => navigation.navigate("AppointmentForm")} />

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${formatDateTime(item.scheduledAt)} - ${item.patientName}`}
            subtitle={`Médico: ${item.doctorName} | Serviço: ${item.serviceName} | ${item.status}`}
            right={<Button title="Editar" variant="ghost" onPress={() => navigation.navigate("AppointmentForm", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}
EOF

# ---------- 6) Forms: Employee/Patient/Service/Appointment
# Reaproveita seus repos existentes; cria forms com soft delete e "procedimentos do funcionário" (skills)
cat > src/ui/screens/forms/EmployeeFormScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { ServiceType } from "@/domain/entities/serviceType";
import { simpleHash } from "@/utils/hash";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { Role } from "@/domain/enums/roles";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "EmployeeForm">;

export function EmployeeFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [loaded, setLoaded] = useState(false);
  const [services, setServices] = useState<ServiceType[]>([]);
  const [selectedServiceIds, setSelectedServiceIds] = useState<string[]>([]);

  const [employeeNumber, setEmployeeNumber] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [sector, setSector] = useState("");
  const [roleStr, setRoleStr] = useState<Role>(Role.EMPLOYEE);
  const [password, setPassword] = useState("");

  useEffect(() => {
    (async () => {
      const s = await ServicesRepo.list();
      setServices(s);

      if (editing) {
        const cur = await EmployeesRepo.getById(id!);
        if (cur) {
          setEmployeeNumber(cur.employeeNumber);
          setName(cur.name);
          setPhone(cur.phone);
          setEmail(cur.email);
          setJobTitle(cur.jobTitle);
          setSector(cur.sector);
          setRoleStr(cur.role);
        }

        const skills = await EmployeeSkillsRepo.listByEmployee(id!);
        setSelectedServiceIds(skills.map((x) => x.serviceTypeId));
      }
      setLoaded(true);
    })();
  }, [editing, id]);

  const canHaveSkills = roleStr === Role.DOCTOR || roleStr === Role.NURSE;

  const selectedLabels = useMemo(() => {
    const map = new Map(services.map((x) => [x.id, x.name]));
    return selectedServiceIds.map((sid) => map.get(sid) ?? sid).join(", ");
  }, [selectedServiceIds, services]);

  function toggleService(sid: string) {
    setSelectedServiceIds((prev) => (prev.includes(sid) ? prev.filter((x) => x !== sid) : [...prev, sid]));
  }

  async function save() {
    if (!loaded) return;

    if (!editing) {
      const created = await EmployeesRepo.create({
        employeeNumber,
        name,
        phone,
        email,
        role: roleStr,
        jobTitle,
        sector,
        passwordHash: simpleHash(password || "1234"),
        mfaEnabled: 0,
        mfaPhoneVerified: 0,
        mfaEmailVerified: 0,
        mfaImageToken: null,
        deletedAt: null,
      });

      if (canHaveSkills) {
        await EmployeeSkillsRepo.setSkills(created.id, selectedServiceIds);
      }

      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "EMPLOYEE", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await EmployeesRepo.getById(id!);
    const next = await EmployeesRepo.update(id!, {
      employeeNumber, name, phone, email, role: roleStr, jobTitle, sector,
      ...(password ? { passwordHash: simpleHash(password) } : {}),
    });

    if (canHaveSkills) {
      await EmployeeSkillsRepo.setSkills(id!, selectedServiceIds);
    } else {
      // se não for médico/enfermagem, zera skills
      await EmployeeSkillsRepo.setSkills(id!, []);
    }

    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "EMPLOYEE", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir funcionário (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await EmployeesRepo.getById(id!);
          await EmployeesRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "EMPLOYEE", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar funcionário" : "Novo funcionário"}</Text>

        <Input label="Número do funcionário" value={employeeNumber} onChangeText={setEmployeeNumber} />
        <Input label="Nome" value={name} onChangeText={setName} />
        <Input label="Telefone" value={phone} onChangeText={setPhone} />
        <Input label="Email" value={email} onChangeText={setEmail} />
        <Input label="Cargo (jobTitle)" value={jobTitle} onChangeText={setJobTitle} />
        <Input label="Setor" value={sector} onChangeText={setSector} />
        <Input label="Role (DOCTOR/NURSE/RECEPTION/...)" value={roleStr} onChangeText={(t) => setRoleStr((t as Role) ?? Role.EMPLOYEE)} />
        <Input label="Senha (opcional)" value={password} onChangeText={setPassword} secureTextEntry />

        {canHaveSkills && (
          <View style={{ gap: 8 }}>
            <Text style={{ fontWeight: "900" }}>O que este funcionário pode realizar (serviços)</Text>
            <Text style={{ color: "#666" }}>{selectedLabels || "Nenhum selecionado"}</Text>
            {services.map((s) => (
              <Button
                key={s.id}
                title={`${selectedServiceIds.includes(s.id) ? "✓ " : ""}${s.name}`}
                variant={selectedServiceIds.includes(s.id) ? "primary" : "ghost"}
                onPress={() => toggleService(s.id)}
              />
            ))}
          </View>
        )}

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

cat > src/ui/screens/forms/PatientFormScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "PatientForm">;

export function PatientFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [name, setName] = useState("");
  const [documentId, setDocumentId] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [birthDate, setBirthDate] = useState("");
  const [notes, setNotes] = useState("");

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await PatientsRepo.getById(id!);
        if (!cur) return;
        setName(cur.name);
        setDocumentId(cur.documentId);
        setPhone(cur.phone);
        setEmail(cur.email ?? "");
        setBirthDate(cur.birthDate ?? "");
        setNotes(cur.notes ?? "");
      }
    })();
  }, [editing, id]);

  async function save() {
    if (!editing) {
      const created = await PatientsRepo.create({
        name, documentId, phone,
        email: email || null,
        birthDate: birthDate || null,
        notes: notes || null,
        deletedAt: null,
      });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "PATIENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await PatientsRepo.getById(id!);
    const next = await PatientsRepo.update(id!, { name, documentId, phone, email: email || null, birthDate: birthDate || null, notes: notes || null });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "PATIENT", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir paciente (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await PatientsRepo.getById(id!);
          await PatientsRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "PATIENT", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar paciente" : "Novo paciente"}</Text>

        <Input label="Nome" value={name} onChangeText={setName} />
        <Input label="Documento" value={documentId} onChangeText={setDocumentId} />
        <Input label="Telefone" value={phone} onChangeText={setPhone} />
        <Input label="Email (opcional)" value={email} onChangeText={setEmail} />
        <Input label="Nascimento YYYY-MM-DD (opcional)" value={birthDate} onChangeText={setBirthDate} />
        <Input label="Observações" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

cat > src/ui/screens/forms/ServiceFormScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "ServiceForm">;

export function ServiceFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [name, setName] = useState("");
  const [treatment, setTreatment] = useState("");
  const [priceCents, setPriceCents] = useState("0");

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await ServicesRepo.getById(id!);
        if (!cur) return;
        setName(cur.name);
        setTreatment(cur.treatment);
        setPriceCents(String(cur.priceCents));
      }
    })();
  }, [editing, id]);

  async function save() {
    const pc = Number(priceCents || "0");
    if (!editing) {
      const created = await ServicesRepo.create({ name, treatment, priceCents: pc, deletedAt: null });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "SERVICE", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await ServicesRepo.getById(id!);
    const next = await ServicesRepo.update(id!, { name, treatment, priceCents: pc });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "SERVICE", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir serviço (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await ServicesRepo.getById(id!);
          await ServicesRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "SERVICE", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar serviço" : "Novo serviço"}</Text>

        <Input label="Nome do serviço" value={name} onChangeText={setName} />
        <Input label="Tipo de tratamento" value={treatment} onChangeText={setTreatment} />
        <Input label="Preço (centavos)" value={priceCents} onChangeText={setPriceCents} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

cat > src/ui/screens/forms/AppointmentFormScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { AppointmentsRepo } from "@/data/repositories/appointments.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "AppointmentForm">;

export function AppointmentFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [patientId, setPatientId] = useState("");
  const [doctorEmployeeId, setDoctorEmployeeId] = useState("");
  const [serviceTypeId, setServiceTypeId] = useState("");
  const [scheduledAt, setScheduledAt] = useState(String(Date.now()));
  const [durationMin, setDurationMin] = useState("30");
  const [status, setStatus] = useState("SCHEDULED");
  const [notes, setNotes] = useState("");

  const [hint, setHint] = useState("");

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await AppointmentsRepo.getById(id!);
        if (!cur) return;
        setPatientId(cur.patientId);
        setDoctorEmployeeId(cur.doctorEmployeeId);
        setServiceTypeId(cur.serviceTypeId);
        setScheduledAt(String(cur.scheduledAt));
        setDurationMin(String(cur.durationMin));
        setStatus(cur.status);
        setNotes(cur.notes ?? "");
      }
    })();
  }, [editing, id]);

  async function validateDoctorSkill() {
    if (!doctorEmployeeId || !serviceTypeId) return;
    const skills = await EmployeeSkillsRepo.listByEmployee(doctorEmployeeId);
    const ok = skills.some((x) => x.serviceTypeId === serviceTypeId);
    if (!ok) {
      const d = await EmployeesRepo.getById(doctorEmployeeId);
      setHint(`⚠️ Atenção: ${d?.name ?? "Médico"} não está vinculado a este serviço (cadastro de procedimentos).`);
    } else {
      setHint("");
    }
  }

  useEffect(() => { validateDoctorSkill(); }, [doctorEmployeeId, serviceTypeId]);

  async function save() {
    const sa = Number(scheduledAt);
    const dm = Number(durationMin);

    if (!editing) {
      const created = await AppointmentsRepo.create({
        patientId,
        doctorEmployeeId,
        serviceTypeId,
        scheduledAt: sa,
        durationMin: dm,
        status: "SCHEDULED",
        notes: notes || null,
        deletedAt: null,
      });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "APPOINTMENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await AppointmentsRepo.getById(id!);
    const next = await AppointmentsRepo.update(id!, {
      patientId, doctorEmployeeId, serviceTypeId,
      scheduledAt: sa,
      durationMin: dm,
      status: status as any,
      notes: notes || null,
    });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "APPOINTMENT", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir agendamento (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await AppointmentsRepo.getById(id!);
          await AppointmentsRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "APPOINTMENT", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar agendamento" : "Novo agendamento"}</Text>

        <Text style={{ color: "#666" }}>
          Dica: pegue os IDs nas telas de Pacientes / Funcionários / Serviços.
          Depois eu troco isso por Select bonitinho.
        </Text>

        {!!hint && <Text style={{ color: "#8b0000", fontWeight: "800" }}>{hint}</Text>}

        <Input label="patientId" value={patientId} onChangeText={setPatientId} />
        <Input label="doctorEmployeeId" value={doctorEmployeeId} onChangeText={setDoctorEmployeeId} />
        <Input label="serviceTypeId" value={serviceTypeId} onChangeText={setServiceTypeId} />
        <Input label="scheduledAt (timestamp ms)" value={scheduledAt} onChangeText={setScheduledAt} />
        <Input label="durationMin" value={durationMin} onChangeText={setDurationMin} />
        <Input label="status (SCHEDULED/DONE/CANCELED)" value={status} onChangeText={setStatus} />
        <Input label="notes" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

# ---------- 7) Prontuário + Exames (feito / a fazer)
cat > src/ui/screens/PatientChartScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Alert, FlatList, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { MedicalRecordsRepo } from "@/data/repositories/medicalRecords.repo";
import { ExamsRepo, Exam } from "@/data/repositories/exams.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { formatDateTime } from "@/utils/dates";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "PatientChart">;

export function PatientChartScreen({ route }: Props) {
  const { patientId } = route.params;
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const [patientName, setPatientName] = useState("");
  const [summary, setSummary] = useState("");
  const [diagnosis, setDiagnosis] = useState("");
  const [notes, setNotes] = useState("");

  const [examName, setExamName] = useState("");
  const [examScheduledAt, setExamScheduledAt] = useState("");
  const [exams, setExams] = useState<Exam[]>([]);

  async function load() {
    const p = await PatientsRepo.getById(patientId);
    setPatientName(p?.name ?? "Paciente");

    const rec = await MedicalRecordsRepo.getByPatient(patientId);
    setSummary(rec?.summary ?? "");
    setDiagnosis(rec?.diagnosis ?? "");
    setNotes(rec?.notes ?? "");

    setExams(await ExamsRepo.listByPatient(patientId));
  }

  useEffect(() => { load(); }, [patientId]);

  async function saveRecord() {
    const before = await MedicalRecordsRepo.getByPatient(patientId);
    const after = await MedicalRecordsRepo.upsert(patientId, {
      summary: summary || null,
      diagnosis: diagnosis || null,
      notes: notes || null,
    });

    await auditLog({
      actorEmployeeId: actorId, actorName,
      action: before ? "UPDATE" : "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { record: true },
      before,
      after,
    });

    await load();
  }

  async function addExam() {
    if (!examName.trim()) return;

    const created = await ExamsRepo.create({
      patientId,
      requestedByEmployeeId: actorId,
      appointmentId: null,
      name: examName.trim(),
      status: "PLANNED",
      scheduledAt: examScheduledAt ? Number(examScheduledAt) : null,
      result: null,
      deletedAt: null,
    });

    await auditLog({
      actorEmployeeId: actorId, actorName,
      action: "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { examId: created.id, examName: created.name },
      after: created,
    });

    setExamName("");
    setExamScheduledAt("");
    await load();
  }

  async function markDone(examId: string) {
    Alert.alert("Finalizar exame", "Marcar como DONE e salvar resultado?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "OK",
        onPress: async () => {
          await ExamsRepo.markDone(examId, "Resultado preenchido (editar depois)");
          await load();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>Prontuário: {patientName}</Text>

        <Text style={{ fontWeight: "900" }}>Resumo</Text>
        <Input label="Resumo" value={summary} onChangeText={setSummary} />

        <Text style={{ fontWeight: "900" }}>Diagnóstico</Text>
        <Input label="Diagnóstico" value={diagnosis} onChangeText={setDiagnosis} />

        <Text style={{ fontWeight: "900" }}>Observações</Text>
        <Input label="Observações" value={notes} onChangeText={setNotes} />

        <Button title="Salvar prontuário" onPress={saveRecord} />

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900", fontSize: 16 }}>Exames</Text>

        <Input label="Novo exame (nome)" value={examName} onChangeText={setExamName} />
        <Input label="Data do exame (timestamp ms) opcional" value={examScheduledAt} onChangeText={setExamScheduledAt} />
        <Button title="Adicionar exame (PLANNED)" onPress={addExam} />

        <FlatList
          data={exams}
          keyExtractor={(i) => i.id}
          scrollEnabled={false}
          contentContainerStyle={{ gap: 10 }}
          renderItem={({ item }) => (
            <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
              <Text style={{ fontWeight: "900" }}>{item.name}</Text>
              <Text>Status: {item.status}</Text>
              <Text>Agendado: {item.scheduledAt ? formatDateTime(item.scheduledAt) : "—"}</Text>
              {!!item.result && <Text>Resultado: {item.result}</Text>}

              {item.status !== "DONE" && <Button title="Marcar DONE" variant="ghost" onPress={() => markDone(item.id)} />}
            </View>
          )}
        />
      </ScrollView>
    </Screen>
  );
}
EOF

echo "✅ Patch aplicado (telas + forms + prontuário + exames)."
echo "➡️ Agora rode: npx expo start -c"
