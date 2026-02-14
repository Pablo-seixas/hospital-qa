#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# 1) Migration: adiciona documentType em patients + tabela patient_files
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
      -- documentType será adicionado via ALTER se faltar
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

    -- NOVO: anexos do paciente (pdf, imagem, etc.)
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
# 2) Repo: patients atualiza pra incluir documentType
cat > src/data/repositories/patients.repo.ts <<'EOF'
import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { Patient } from "@/domain/entities/patient";
import { id } from "@/utils/id";

export type PatientRow = Patient & { documentType?: string | null };

export const PatientsRepo = {
  list(): Promise<PatientRow[]> {
    return getAllAsync<PatientRow>("SELECT * FROM patients WHERE isDeleted=0 ORDER BY name");
  },
  getById(pid: string): Promise<PatientRow | null> {
    return getFirstAsync<PatientRow>("SELECT * FROM patients WHERE id=? AND isDeleted=0", [pid]);
  },
  async create(p: Omit<PatientRow, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<PatientRow> {
    const now = Date.now();
    const row: PatientRow = { ...p, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO patients (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        name, documentId, documentType, phone, email, birthDate, notes
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?)`,
      [
        row.id, row.createdAt, row.updatedAt,
        row.name, row.documentId, row.documentType ?? null,
        row.phone, row.email ?? null, row.birthDate ?? null, row.notes ?? null
      ]
    );
    return row;
  },
  async update(pid: string, patch: Partial<PatientRow>): Promise<PatientRow | null> {
    const cur = await this.getById(pid);
    if (!cur) return null;
    const next: PatientRow = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE patients SET
        updatedAt=?,
        name=?, documentId=?, documentType=?,
        phone=?, email=?, birthDate=?, notes=?
      WHERE id=?`,
      [
        next.updatedAt,
        next.name, next.documentId, next.documentType ?? null,
        next.phone, next.email ?? null, next.birthDate ?? null, next.notes ?? null,
        pid
      ]
    );
    return next;
  },
  softDelete(pid: string) {
    const now = Date.now();
    return runAsync("UPDATE patients SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, pid]);
  },
};
EOF

# ---------------------------
# 3) Repo: patient_files
cat > src/data/repositories/patientFiles.repo.ts <<'EOF'
import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type PatientFile = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number | null;
  patientId: string;
  name: string;
  mimeType?: string | null;
  size?: number | null;
  localUri: string;
};

export const PatientFilesRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<PatientFile>(
      "SELECT * FROM patient_files WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
      [patientId]
    );
  },

  async create(f: Omit<PatientFile,"id"|"createdAt"|"updatedAt"|"isDeleted">) {
    const now = Date.now();
    const row: PatientFile = { ...f, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO patient_files (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, name, mimeType, size, localUri
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?)`,
      [
        row.id, row.createdAt, row.updatedAt,
        row.patientId, row.name, row.mimeType ?? null, row.size ?? null, row.localUri
      ]
    );
    return row;
  },

  softDelete(fileId: string) {
    const now = Date.now();
    return runAsync("UPDATE patient_files SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, fileId]);
  },
};
EOF

# ---------------------------
# 4) Repo: Stats + Last logins
cat > src/data/repositories/stats.repo.ts <<'EOF'
import { getFirstAsync, getAllAsync } from "@/data/db/sqlite";

export const StatsRepo = {
  async counts() {
    const employees = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM employees WHERE isDeleted=0");
    const patients = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM patients WHERE isDeleted=0");
    const services = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM service_types WHERE isDeleted=0");
    return {
      employees: employees?.c ?? 0,
      patients: patients?.c ?? 0,
      services: services?.c ?? 0,
    };
  },

  async todayAppointmentsCount(todayStart: number, todayEnd: number) {
    const r = await getFirstAsync<{ c: number }>(
      "SELECT COUNT(*) as c FROM appointments WHERE isDeleted=0 AND scheduledAt>=? AND scheduledAt<?",
      [todayStart, todayEnd]
    );
    return r?.c ?? 0;
  },

  async lastLogins(limit = 10) {
    return getAllAsync<{ actorName: string; actorEmployeeId: string; createdAt: number }>(
      "SELECT actorName, actorEmployeeId, createdAt FROM audit_logs WHERE isDeleted=0 AND action='LOGIN' ORDER BY createdAt DESC LIMIT ?",
      [limit]
    );
  },
};
EOF

# ---------------------------
# 5) Validators: documento + telefone + nascimento
cat > src/domain/validators/patient.validators.ts <<'EOF'
export type DocumentType = "CPF" | "RG" | "CNH";

export function normalizeDigits(s: string) {
  return (s ?? "").replace(/\D/g, "");
}

export function validateCPF(raw: string): boolean {
  const cpf = normalizeDigits(raw);
  if (cpf.length !== 11) return false;
  if (/^(\d)\1+$/.test(cpf)) return false;

  // checksum
  let sum = 0;
  for (let i = 0; i < 9; i++) sum += Number(cpf[i]) * (10 - i);
  let d1 = (sum * 10) % 11;
  if (d1 === 10) d1 = 0;
  if (d1 !== Number(cpf[9])) return false;

  sum = 0;
  for (let i = 0; i < 10; i++) sum += Number(cpf[i]) * (11 - i);
  let d2 = (sum * 10) % 11;
  if (d2 === 10) d2 = 0;
  return d2 === Number(cpf[10]);
}

export function validateRG(raw: string): boolean {
  // RG varia por estado; regra mínima: 7 a 12 caracteres/dígitos
  const v = raw.trim();
  const digits = normalizeDigits(v);
  return digits.length >= 7 && digits.length <= 12;
}

export function validateCNH(raw: string): boolean {
  const d = normalizeDigits(raw);
  return d.length === 11;
}

export function validateDocument(docType: DocumentType, docValue: string): boolean {
  if (!docValue.trim()) return false;
  if (docType === "CPF") return validateCPF(docValue);
  if (docType === "RG") return validateRG(docValue);
  return validateCNH(docValue);
}

export function validatePhone(raw: string): boolean {
  const d = normalizeDigits(raw);
  // BR: 10 ou 11 dígitos (DDD + número)
  return d.length === 10 || d.length === 11;
}

export function validateBirthDate(birthDateYYYYMMDD: string, nowYear: number): { ok: boolean; reason?: string } {
  const v = birthDateYYYYMMDD.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) return { ok: false, reason: "Formato deve ser YYYY-MM-DD" };

  const [yS, mS, dS] = v.split("-");
  const y = Number(yS), m = Number(mS), d = Number(dS);
  if (y > nowYear) return { ok: false, reason: `Ano máximo é ${nowYear}` };
  if (y < nowYear - 126) return { ok: false, reason: `Ano mínimo é ${nowYear - 126}` };
  if (m < 1 || m > 12) return { ok: false, reason: "Mês inválido" };
  if (d < 1 || d > 31) return { ok: false, reason: "Dia inválido" };

  return { ok: true };
}
EOF

# ---------------------------
# 6) UI: PatientForm com regras obrigatórias e limites (ano atual e 126 anos)
cat > src/ui/screens/forms/PatientFormScreen.tsx <<'EOF'
import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";
import { DocumentType, validateBirthDate, validateDocument, validatePhone } from "@/domain/validators/patient.validators";

type Props = NativeStackScreenProps<RootStackParamList, "PatientForm">;

export function PatientFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const nowYear = new Date().getFullYear(); // em 2026, trava em 2026
  const minYear = nowYear - 126;

  const id = route.params?.id;
  const editing = !!id;

  const [name, setName] = useState("");
  const [documentType, setDocumentType] = useState<DocumentType>("CPF");
  const [documentId, setDocumentId] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [birthDate, setBirthDate] = useState(""); // obrigatório
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await PatientsRepo.getById(id!);
        if (!cur) return;
        setName(cur.name);
        setDocumentId(cur.documentId);
        setDocumentType((cur.documentType as DocumentType) ?? "CPF");
        setPhone(cur.phone);
        setEmail(cur.email ?? "");
        setBirthDate(cur.birthDate ?? "");
        setNotes(cur.notes ?? "");
      }
    })();
  }, [editing, id]);

  const docHint = useMemo(() => {
    if (documentType === "CPF") return "CPF: 11 dígitos (com validação)";
    if (documentType === "RG") return "RG: 7 a 12 dígitos (regra mínima)";
    return "CNH: 11 dígitos";
  }, [documentType]);

  function validateAll(): boolean {
    setError(null);

    if (!name.trim()) return setError("Nome é obrigatório"), false;

    if (!documentId.trim()) return setError("Documento é obrigatório"), false;
    if (!validateDocument(documentType, documentId)) return setError(`Documento inválido para ${documentType}. ${docHint}`), false;

    if (!phone.trim()) return setError("Telefone é obrigatório"), false;
    if (!validatePhone(phone)) return setError("Telefone inválido (use DDD + número: 10 ou 11 dígitos)"), false;

    if (!birthDate.trim()) return setError("Data de nascimento é obrigatória"), false;
    const bd = validateBirthDate(birthDate, nowYear);
    if (!bd.ok) return setError(`Nascimento inválido: ${bd.reason}. Permitido: ${minYear} até ${nowYear}`), false;

    return true;
  }

  async function save() {
    if (!validateAll()) return;

    if (!editing) {
      const created = await PatientsRepo.create({
        name,
        documentId,
        documentType,
        phone,
        email: email || null,
        birthDate, // obrigatório
        notes: notes || null,
        deletedAt: null,
      });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "PATIENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await PatientsRepo.getById(id!);
    const next = await PatientsRepo.update(id!, {
      name,
      documentId,
      documentType,
      phone,
      email: email || null,
      birthDate,
      notes: notes || null,
    });
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

        {!!error && <Text style={{ color: "#8b0000", fontWeight: "800" }}>{error}</Text>}

        <Input label="Nome (obrigatório)" value={name} onChangeText={setName} />

        <Text style={{ fontWeight: "900" }}>Tipo de documento (obrigatório)</Text>
        <View style={{ flexDirection: "row", gap: 10 }}>
          <Button title={documentType === "CPF" ? "✓ CPF" : "CPF"} variant={documentType === "CPF" ? "primary" : "ghost"} onPress={() => setDocumentType("CPF")} />
          <Button title={documentType === "RG" ? "✓ RG" : "RG"} variant={documentType === "RG" ? "primary" : "ghost"} onPress={() => setDocumentType("RG")} />
          <Button title={documentType === "CNH" ? "✓ CNH" : "CNH"} variant={documentType === "CNH" ? "primary" : "ghost"} onPress={() => setDocumentType("CNH")} />
        </View>

        <Input label={`Documento (${documentType}) - obrigatório`} value={documentId} onChangeText={setDocumentId} placeholder={docHint} />

        <Input label="Telefone (obrigatório)" value={phone} onChangeText={setPhone} placeholder="ex: (71) 99999-9999" />
        <Input label="Data nascimento (YYYY-MM-DD) obrigatório" value={birthDate} onChangeText={setBirthDate} placeholder={`Entre ${minYear}-01-01 e ${nowYear}-12-31`} />

        <Input label="Email (opcional)" value={email} onChangeText={setEmail} />
        <Input label="Observações (opcional)" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
EOF

# ---------------------------
# 7) UI: PatientChart agora com anexos (PDF/Imagem/etc.)
cat > src/ui/screens/PatientChartScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Alert, FlatList, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { MedicalRecordsRepo } from "@/data/repositories/medicalRecords.repo";
import { ExamsRepo, Exam } from "@/data/repositories/exams.repo";
import { PatientFilesRepo, PatientFile } from "@/data/repositories/patientFiles.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { formatDateTime } from "@/utils/dates";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";

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

  const [files, setFiles] = useState<PatientFile[]>([]);

  async function load() {
    const p = await PatientsRepo.getById(patientId);
    setPatientName(p?.name ?? "Paciente");

    const rec = await MedicalRecordsRepo.getByPatient(patientId);
    setSummary(rec?.summary ?? "");
    setDiagnosis(rec?.diagnosis ?? "");
    setNotes(rec?.notes ?? "");

    setExams(await ExamsRepo.listByPatient(patientId));
    setFiles(await PatientFilesRepo.listByPatient(patientId));
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

  async function pickAndAttachFile() {
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

  async function deleteFile(fileId: string) {
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
              {!!item.result && <Text>Resultado: {item.result}</Text>
              }
              {item.status !== "DONE" && <Button title="Marcar DONE" variant="ghost" onPress={() => markDone(item.id)} />}
            </View>
          )}
        />

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900", fontSize: 16 }}>Anexos do paciente (PDF/Imagem)</Text>
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
              <Button title="Excluir anexo" variant="danger" onPress={() => deleteFile(item.id)} />
            </View>
          )}
        />
      </ScrollView>
    </Screen>
  );
}
EOF

# ---------------------------
# 8) Dashboard: contagens + últimos logins (último acesso)
cat > src/ui/screens/DashboardScreen.tsx <<'EOF'
import React, { useEffect, useState } from "react";
import { Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { useAuthStore } from "@/store/auth.store";
import { logout } from "@/services/auth/auth.service";
import { RoleLabel } from "@/domain/enums/roles";
import { StatsRepo } from "@/data/repositories/stats.repo";
import { formatDateTime } from "@/utils/dates";
import { startOfDay, addDays } from "date-fns";

export function DashboardScreen({ navigation }: any) {
  const name = useAuthStore((s) => s.employeeName);
  const role = useAuthStore((s) => s.role);

  const [counts, setCounts] = useState({ employees: 0, patients: 0, services: 0 });
  const [todayAppts, setTodayAppts] = useState(0);
  const [logins, setLogins] = useState<{ actorName: string; actorEmployeeId: string; createdAt: number }[]>([]);

  async function load() {
    const c = await StatsRepo.counts();
    setCounts(c);

    const start = startOfDay(new Date()).getTime();
    const end = addDays(new Date(start), 1).getTime();
    setTodayAppts(await StatsRepo.todayAppointmentsCount(start, end));

    setLogins(await StatsRepo.lastLogins(10));
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  async function onLogout() {
    await logout();
    useAuthStore.getState().setSession(null);
    navigation.replace("Auth");
  }

  return (
    <Screen>
      <Text style={{ fontSize: 18, fontWeight: "900" }}>Painel</Text>
      <Text>Usuário: {name}</Text>
      <Text>Nível: {role ? RoleLabel[role] : "-"}</Text>

      <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

      <Text style={{ fontWeight: "900" }}>Resumo do sistema</Text>
      <Text>Funcionários cadastrados: {counts.employees}</Text>
      <Text>Pacientes cadastrados: {counts.patients}</Text>
      <Text>Serviços cadastrados: {counts.services}</Text>
      <Text>Agendamentos de hoje: {todayAppts}</Text>

      <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

      <Text style={{ fontWeight: "900" }}>Últimos acessos (LOGIN)</Text>
      {logins.map((l) => (
        <Text key={`${l.actorEmployeeId}-${l.createdAt}`}>
          {formatDateTime(l.createdAt)} — {l.actorName}
        </Text>
      ))}

      <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

      <Button title="Sair" variant="ghost" onPress={onLogout} />
    </Screen>
  );
}
EOF

echo "✅ Patch aplicado: validações (CPF/RG/CNH + nascimento + telefone), anexos, e dashboard ADM."
echo "➡️ Rode: npx expo start -c"
