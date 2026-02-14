#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# 1) MIGRATION: tabela de acesso médico-paciente (marcação)
#    + helper para ALTER seguro (caso futuro)
cat > src/data/db/migrations.ts <<'EOF'
import { execAsync, getAllAsync, getFirstAsync, runAsync } from "./sqlite";
import { simpleHash } from "@/utils/hash";

async function ensurePatientsColumns() {
  const cols = await getAllAsync<{ name: string }>("PRAGMA table_info(patients)");
  const hasDocType = cols.some((c) => c.name === "documentType");
  if (!hasDocType) {
    await execAsync(`ALTER TABLE patients ADD COLUMN documentType TEXT;`);
  }
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
      -- documentType via ALTER se faltar
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

    CREATE TABLE IF NOT EXISTS employee_service_types (
      id TEXT PRIMARY KEY NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      isDeleted INTEGER NOT NULL,
      deletedAt INTEGER,
      employeeId TEXT NOT NULL,
      serviceTypeId TEXT NOT NULL
    );

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

    -- NOVO: marcação de médico do paciente (controle de acesso)
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
  `);

  await ensurePatientsColumns();

  const seeded = await getFirstAsync<{ value: string }>("SELECT value FROM meta WHERE key='seeded'");
  if (!seeded?.value) {
    const now = Date.now();
    await runAsync("INSERT OR REPLACE INTO meta(key,value) VALUES('seeded','1')");

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

# ---------------------------
# 2) Repo: patient_doctors (marcação do médico do paciente)
cat > src/data/repositories/patientDoctors.repo.ts <<'EOF'
import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type PatientDoctor = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;
  patientId: string;
  doctorEmployeeId: string;
  assignedByEmployeeId: string;
};

export const PatientDoctorsRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<PatientDoctor>(
      "SELECT * FROM patient_doctors WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
      [patientId]
    );
  },

  async isDoctorOfPatient(patientId: string, doctorEmployeeId: string) {
    const r = await getFirstAsync<{ c: number }>(
      "SELECT COUNT(*) as c FROM patient_doctors WHERE isDeleted=0 AND patientId=? AND doctorEmployeeId=?",
      [patientId, doctorEmployeeId]
    );
    return (r?.c ?? 0) > 0;
  },

  async assign(patientId: string, doctorEmployeeId: string, assignedByEmployeeId: string) {
    // evita duplicar
    const already = await this.isDoctorOfPatient(patientId, doctorEmployeeId);
    if (already) return;

    const now = Date.now();
    await runAsync(
      `INSERT INTO patient_doctors (id, createdAt, updatedAt, isDeleted, deletedAt, patientId, doctorEmployeeId, assignedByEmployeeId)
       VALUES (?, ?, ?, 0, NULL, ?, ?, ?)`,
      [id(), now, now, patientId, doctorEmployeeId, assignedByEmployeeId]
    );
  },

  softUnassignById(rowId: string) {
    const now = Date.now();
    return runAsync("UPDATE patient_doctors SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, rowId]);
  },
};
EOF

# ---------------------------
# 3) Repo: audit extra para funcionário (histórico e último acesso)
cat > src/data/repositories/audit.repo.ts <<'EOF'
import { getAllAsync, getFirstAsync } from "@/data/db/sqlite";
import { AuditLog } from "@/domain/entities/auditLog";

export const AuditRepo = {
  listLatest(limit = 200): Promise<AuditLog[]> {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 ORDER BY createdAt DESC LIMIT ?",
      [limit]
    );
  },

  listByActor(actorEmployeeId: string, limit = 200): Promise<AuditLog[]> {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 AND actorEmployeeId=? ORDER BY createdAt DESC LIMIT ?",
      [actorEmployeeId, limit]
    );
  },

  async lastLogin(actorEmployeeId: string): Promise<number | null> {
    const r = await getFirstAsync<{ createdAt: number }>(
      "SELECT createdAt FROM audit_logs WHERE isDeleted=0 AND actorEmployeeId=? AND action='LOGIN' ORDER BY createdAt DESC LIMIT 1",
      [actorEmployeeId]
    );
    return r?.createdAt ?? null;
  },
};
EOF

# ---------------------------
# 4) Navigation: rota EmployeeDetail
cat > src/navigation/types.ts <<'EOF'
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
  Audit: undefined;
};
EOF

cat > src/navigation/RootNavigator.tsx <<'EOF'
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
    </Stack.Navigator>
  );
}
EOF

# ---------------------------
# 5) UI component: SelectList (simples, pesquisável, sem libs)
cat > src/ui/components/SelectList.tsx <<'EOF'
import React, { useMemo, useState } from "react";
import { Modal, Pressable, ScrollView, Text, TextInput, View } from "react-native";

export type SelectOption = { id: string; label: string; subtitle?: string };

export function SelectList(props: {
  label: string;
  valueId: string | null;
  onChange: (id: string) => void;
  options: SelectOption[];
  placeholder?: string;
}) {
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");

  const selected = useMemo(
    () => props.options.find((o) => o.id === props.valueId) ?? null,
    [props.options, props.valueId]
  );

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return props.options;
    return props.options.filter((o) => (o.label + " " + (o.subtitle ?? "")).toLowerCase().includes(s));
  }, [q, props.options]);

  return (
    <View style={{ gap: 6 }}>
      <Text style={{ fontWeight: "800" }}>{props.label}</Text>

      <Pressable
        onPress={() => setOpen(true)}
        style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12, backgroundColor: "#fff" }}
      >
        <Text style={{ fontWeight: "700" }}>{selected?.label ?? (props.placeholder ?? "Selecionar...")}</Text>
        {!!selected?.subtitle && <Text style={{ color: "#666", marginTop: 2 }}>{selected.subtitle}</Text>}
      </Pressable>

      <Modal visible={open} animationType="slide" onRequestClose={() => setOpen(false)}>
        <View style={{ flex: 1, padding: 16, gap: 10 }}>
          <Text style={{ fontSize: 18, fontWeight: "900" }}>{props.label}</Text>

          <TextInput
            placeholder="Buscar..."
            value={q}
            onChangeText={setQ}
            style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12 }}
          />

          <ScrollView contentContainerStyle={{ gap: 10, paddingBottom: 40 }}>
            {filtered.map((o) => (
              <Pressable
                key={o.id}
                onPress={() => {
                  props.onChange(o.id);
                  setOpen(false);
                }}
                style={{
                  borderWidth: 1,
                  borderColor: "#eee",
                  borderRadius: 14,
                  padding: 12,
                  backgroundColor: o.id === props.valueId ? "#111" : "#fff",
                }}
              >
                <Text style={{ fontWeight: "900", color: o.id === props.valueId ? "#fff" : "#111" }}>{o.label}</Text>
                {!!o.subtitle && (
                  <Text style={{ color: o.id === props.valueId ? "#ddd" : "#666", marginTop: 2 }}>{o.subtitle}</Text>
                )}
              </Pressable>
            ))}
          </ScrollView>

          <Pressable
            onPress={() => setOpen(false)}
            style={{ borderWidth: 1, borderColor: "#111", borderRadius: 12, padding: 12, alignItems: "center" }}
          >
            <Text style={{ fontWeight: "900" }}>Fechar</Text>
          </Pressable>
        </View>
      </Modal>
    </View>
  );
}
EOF

# ---------------------------
# 6) EmployeesScreen: abre detalhe
cat > src/ui/screens/EmployeesScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { FlatList, Text, TextInput } from "react-native";
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
            right={
              <>
                <Button title="Ver" variant="ghost" onPress={() => navigation.navigate("EmployeeDetail", { id: item.id })} />
              </>
            }
          />
        )}
      />
    </Screen>
  );
}
EOF

# ---------------------------
# 7) EmployeeDetailScreen: mostra dados, skills, último login, histórico de alterações
cat > src/ui/screens/EmployeeDetailScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { FlatList, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { AuditRepo } from "@/data/repositories/audit.repo";
import { formatDateTime } from "@/utils/dates";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "EmployeeDetail">;

export function EmployeeDetailScreen({ navigation, route }: Props) {
  const { id } = route.params;

  const [emp, setEmp] = useState<any>(null);
  const [skills, setSkills] = useState<string[]>([]);
  const [lastLogin, setLastLogin] = useState<number | null>(null);
  const [history, setHistory] = useState<any[]>([]);
  const [serviceMap, setServiceMap] = useState<Map<string, string>>(new Map());

  async function load() {
    const e = await EmployeesRepo.getById(id);
    setEmp(e);

    const services = await ServicesRepo.list();
    setServiceMap(new Map(services.map((s) => [s.id, s.name])));

    const sk = await EmployeeSkillsRepo.listByEmployee(id);
    setSkills(sk.map((x) => x.serviceTypeId));

    setLastLogin(await AuditRepo.lastLogin(id));
    setHistory(await AuditRepo.listByActor(id, 200));
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, id]);

  const skillsLabel = useMemo(() => {
    if (!skills.length) return "—";
    return skills.map((sid) => serviceMap.get(sid) ?? sid).join(", ");
  }, [skills, serviceMap]);

  if (!emp) return <Screen><Text>Carregando...</Text></Screen>;

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 18 }}>{emp.name}</Text>
        <Text>Número: {emp.employeeNumber}</Text>
        <Text>Role: {emp.role}</Text>
        <Text>Cargo: {emp.jobTitle}</Text>
        <Text>Setor: {emp.sector}</Text>
        <Text>Email: {emp.email}</Text>
        <Text>Telefone: {emp.phone}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Último acesso</Text>
        <Text>{lastLogin ? formatDateTime(lastLogin) : "—"}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Procedimentos/serviços que realiza</Text>
        <Text style={{ color: "#666" }}>{skillsLabel}</Text>

        <Button title="Editar funcionário" variant="ghost" onPress={() => navigation.navigate("EmployeeForm", { id })} />

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Histórico de ações (até 200)</Text>
        <FlatList
          data={history}
          keyExtractor={(i) => i.id}
          scrollEnabled={false}
          contentContainerStyle={{ gap: 10 }}
          renderItem={({ item }) => (
            <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
              <Text style={{ fontWeight: "900" }}>{item.action} {item.entity}</Text>
              <Text>{formatDateTime(item.createdAt)}</Text>
              <Text style={{ color: "#666" }}>Entidade ID: {item.entityId}</Text>
            </View>
          )}
        />
      </ScrollView>
    </Screen>
  );
}
EOF

# ---------------------------
# 8) AppointmentFormScreen: SELECTS (paciente, médico, serviço) + auto-assign médico do paciente
cat > src/ui/screens/forms/AppointmentFormScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";
import { AppointmentsRepo } from "@/data/repositories/appointments.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";
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

  const [patientId, setPatientId] = useState<string | null>(null);
  const [doctorEmployeeId, setDoctorEmployeeId] = useState<string | null>(null);
  const [serviceTypeId, setServiceTypeId] = useState<string | null>(null);

  const [scheduledAt, setScheduledAt] = useState(String(Date.now()));
  const [durationMin, setDurationMin] = useState("30");
  const [status, setStatus] = useState("SCHEDULED");
  const [notes, setNotes] = useState("");

  const [patientsOpt, setPatientsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [doctorsOpt, setDoctorsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [servicesOpt, setServicesOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);

  const [hint, setHint] = useState("");

  useEffect(() => {
    (async () => {
      const patients = await PatientsRepo.list();
      setPatientsOpt(patients.map((p) => ({ id: p.id, label: p.name, subtitle: `Doc: ${p.documentId} | Tel: ${p.phone}` })));

      const doctors = await EmployeesRepo.listDoctors();
      setDoctorsOpt(doctors.map((d) => ({ id: d.id, label: d.name, subtitle: `${d.jobTitle} | ${d.sector}` })));

      const services = await ServicesRepo.list();
      setServicesOpt(services.map((s) => ({ id: s.id, label: s.name, subtitle: s.treatment })));

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
    if (!doctorEmployeeId || !serviceTypeId) return setHint("");
    const skills = await EmployeeSkillsRepo.listByEmployee(doctorEmployeeId);
    const ok = skills.some((x) => x.serviceTypeId === serviceTypeId);
    if (!ok) setHint("⚠️ Este médico não está vinculado a este serviço (cadastro de procedimentos).");
    else setHint("");
  }
  useEffect(() => { validateDoctorSkill(); }, [doctorEmployeeId, serviceTypeId]);

  const canSave = useMemo(() => !!patientId && !!doctorEmployeeId && !!serviceTypeId, [patientId, doctorEmployeeId, serviceTypeId]);

  async function save() {
    if (!canSave) return;

    const sa = Number(scheduledAt);
    const dm = Number(durationMin);

    if (!editing) {
      const created = await AppointmentsRepo.create({
        patientId: patientId!,
        doctorEmployeeId: doctorEmployeeId!,
        serviceTypeId: serviceTypeId!,
        scheduledAt: sa,
        durationMin: dm,
        status: "SCHEDULED",
        notes: notes || null,
        deletedAt: null,
      });

      // REGRA: ao agendar, marca o médico como médico do paciente (controle de acesso)
      await PatientDoctorsRepo.assign(patientId!, doctorEmployeeId!, actorId);

      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "APPOINTMENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await AppointmentsRepo.getById(id!);
    const next = await AppointmentsRepo.update(id!, {
      patientId: patientId!,
      doctorEmployeeId: doctorEmployeeId!,
      serviceTypeId: serviceTypeId!,
      scheduledAt: sa,
      durationMin: dm,
      status: status as any,
      notes: notes || null,
    });

    // ao editar, garante marcação também
    await PatientDoctorsRepo.assign(patientId!, doctorEmployeeId!, actorId);

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
        {!!hint && <Text style={{ color: "#8b0000", fontWeight: "800" }}>{hint}</Text>}

        <SelectList label="Paciente" valueId={patientId} onChange={setPatientId} options={patientsOpt} placeholder="Selecione o paciente" />
        <SelectList label="Médico" valueId={doctorEmployeeId} onChange={setDoctorEmployeeId} options={doctorsOpt} placeholder="Selecione o médico" />
        <SelectList label="Serviço" valueId={serviceTypeId} onChange={setServiceTypeId} options={servicesOpt} placeholder="Selecione o serviço" />

        <Input label="Data/hora (timestamp ms)" value={scheduledAt} onChangeText={setScheduledAt} />
        <Input label="Duração (min)" value={durationMin} onChangeText={setDurationMin} />
        <Input label="Status (SCHEDULED/DONE/CANCELED)" value={status} onChangeText={setStatus} />
        <Input label="Observações" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} disabled={!canSave} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

# ---------------------------
# 9) PatientChartScreen: controle de acesso + marcar médico do paciente + abrir anexos
cat > src/ui/screens/PatientChartScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { Alert, FlatList, Linking, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";

import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { MedicalRecordsRepo } from "@/data/repositories/medicalRecords.repo";
import { ExamsRepo, Exam } from "@/data/repositories/exams.repo";
import { PatientFilesRepo, PatientFile } from "@/data/repositories/patientFiles.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";

import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { formatDateTime } from "@/utils/dates";
import { Role } from "@/domain/enums/roles";

import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";

import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "PatientChart">;

export function PatientChartScreen({ route }: Props) {
  const { patientId } = route.params;

  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const role = useAuthStore((s) => s.role)!;

  const isRoot = role === Role.ROOT_ADMIN;

  const [patientName, setPatientName] = useState("");

  const [summary, setSummary] = useState("");
  const [diagnosis, setDiagnosis] = useState("");
  const [notes, setNotes] = useState("");

  const [examName, setExamName] = useState("");
  const [examScheduledAt, setExamScheduledAt] = useState("");
  const [exams, setExams] = useState<Exam[]>([]);

  const [files, setFiles] = useState<PatientFile[]>([]);
  const [assigned, setAssigned] = useState<any[]>([]);
  const [doctorsOpt, setDoctorsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [assignDoctorId, setAssignDoctorId] = useState<string | null>(null);

  const [doctorAccess, setDoctorAccess] = useState(false);

  const canSeeAttachments = useMemo(() => {
    // regra do usuário:
    // - ROOT_ADMIN vê tudo
    // - DOCTOR só vê se estiver marcado no paciente
    // - enfermagem/técnico/outros: não vê
    if (isRoot) return true;
    if (role === Role.DOCTOR) return doctorAccess;
    return false;
  }, [isRoot, role, doctorAccess]);

  const canDeleteAttachments = canSeeAttachments; // você pediu: root e médico podem excluir

  async function load() {
    const p = await PatientsRepo.getById(patientId);
    setPatientName(p?.name ?? "Paciente");

    // checa acesso do médico
    const isDoctorOf = await PatientDoctorsRepo.isDoctorOfPatient(patientId, actorId);
    setDoctorAccess(isDoctorOf);

    const rec = await MedicalRecordsRepo.getByPatient(patientId);
    setSummary(rec?.summary ?? "");
    setDiagnosis(rec?.diagnosis ?? "");
    setNotes(rec?.notes ?? "");

    setExams(await ExamsRepo.listByPatient(patientId));

    // anexos só carrega se permitido
    if (isRoot || (role === Role.DOCTOR && isDoctorOf)) {
      setFiles(await PatientFilesRepo.listByPatient(patientId));
    } else {
      setFiles([]);
    }

    const ass = await PatientDoctorsRepo.listByPatient(patientId);
    setAssigned(ass);

    // lista de médicos pra admin marcar
    const doctors = await EmployeesRepo.listDoctors();
    setDoctorsOpt(doctors.map((d) => ({ id: d.id, label: d.name, subtitle: `${d.jobTitle} | ${d.sector}` })));
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
      { text: "OK", onPress: async () => { await ExamsRepo.markDone(examId, "Resultado preenchido (editar depois)"); await load(); } },
    ]);
  }

  async function assignDoctor() {
    if (!assignDoctorId) return;
    await PatientDoctorsRepo.assign(patientId, assignDoctorId, actorId);
    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "UPDATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { assignedDoctorId: assignDoctorId },
    });
    setAssignDoctorId(null);
    await load();
  }

  async function unassign(rowId: string) {
    Alert.alert("Remover médico", "Remover marcação deste médico do paciente?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Remover",
        style: "destructive",
        onPress: async () => {
          await PatientDoctorsRepo.softUnassignById(rowId);
          await load();
        },
      },
    ]);
  }

  async function pickAndAttachFile() {
    if (!canSeeAttachments) return;

    const res = await DocumentPicker.getDocumentAsync({
      type: "*/*",
      multiple: false,
      copyToCacheDirectory: true,
    });
    if (res.canceled) return;

    const file = res.assets?.[0];
    if (!file?.uri) return;

    const folder = `${FileSystem.documentDirectory}patient_files/${patientId}/`;
    await FileSystem.makeDirectoryAsync(folder, { intermediates: true });

    const safeName = (file.name ?? `arquivo_${Date.now()}`).replace(/[^\w.\-]/g, "_");
    const dest = `${folder}${Date.now()}_${safeName}`;

    await FileSystem.copyAsync({ from: file.uri, to: dest });

    const created = await PatientFilesRepo.create({
      patientId,
      name: safeName,
      mimeType: file.mimeType ?? null,
      size: file.size ?? null,
      localUri: dest,
      deletedAt: null,
    });

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { attachment: true, fileId: created.id, name: created.name, mimeType: created.mimeType },
      after: created,
    });

    await load();
  }

  async function openFile(item: PatientFile) {
    if (!canSeeAttachments) return;

    try {
      // Em Android: converte file:// para content:// (necessário para abrir)
      const contentUri = await FileSystem.getContentUriAsync(item.localUri);
      await Linking.openURL(contentUri);
    } catch {
      // fallback
      await Linking.openURL(item.localUri);
    }
  }

  async function deleteFile(fileId: string) {
    if (!canDeleteAttachments) return;
    Alert.alert("Excluir anexo", "Excluir este anexo (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          await PatientFilesRepo.softDelete(fileId);
          await load();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>Prontuário: {patientName}</Text>

        {/* Admin pode marcar médico do paciente */}
        {isRoot && (
          <View style={{ gap: 10 }}>
            <Text style={{ fontWeight: "900" }}>Médico(s) marcado(s) do paciente</Text>

            <SelectList
              label="Marcar médico"
              valueId={assignDoctorId}
              onChange={setAssignDoctorId}
              options={doctorsOpt}
              placeholder="Selecione um médico"
            />
            <Button title="Marcar médico do paciente" onPress={assignDoctor} disabled={!assignDoctorId} />

            {assigned.map((a) => (
              <View key={a.id} style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
                <Text style={{ fontWeight: "900" }}>DoctorId: {a.doctorEmployeeId}</Text>
                <Text style={{ color: "#666" }}>Marcado em: {formatDateTime(a.createdAt)}</Text>
                <Button title="Remover marcação" variant="danger" onPress={() => unassign(a.id)} />
              </View>
            ))}

            <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />
          </View>
        )}

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

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900", fontSize: 16 }}>Anexos do paciente (PDF/Imagem)</Text>

        {!canSeeAttachments ? (
          <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>Acesso restrito</Text>
            <Text style={{ color: "#666" }}>
              Somente Root Admin e o médico marcado do paciente podem visualizar e excluir anexos.
            </Text>
          </View>
        ) : (
          <>
            <Button title="Adicionar anexo" onPress={pickAndAttachFile} />

            <FlatList
              data={files}
              keyExtractor={(i) => i.id}
              scrollEnabled={false}
              contentContainerStyle={{ gap: 10 }}
              renderItem={({ item }) => (
                <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
                  <Text style={{ fontWeight: "900" }}>{item.name}</Text>
                  <Text>Tipo: {item.mimeType ?? "—"} | Tamanho: {item.size ?? "—"}</Text>
                  <Text style={{ color: "#666" }} numberOfLines={1}>Local: {item.localUri}</Text>

                  <View style={{ flexDirection: "row", gap: 10 }}>
                    <Button title="Abrir" variant="ghost" onPress={() => openFile(item)} />
                    {canDeleteAttachments && <Button title="Excluir" variant="danger" onPress={() => deleteFile(item.id)} />}
                  </View>
                </View>
              )}
            />
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
EOF

echo "✅ Patch aplicado: Selects no agendamento + Employee Detail + Acesso anexos por médico marcado + Abrir PDF/Imagem."
echo "➡️ Rode: npx expo start -c"
