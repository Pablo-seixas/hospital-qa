import { execAsync, getAllAsync, getFirstAsync, runAsync } from "./sqlite";
import { simpleHash } from "@/utils/hash";

async function ensurePatientsColumns() {
  const cols = await getAllAsync<{ name: string }>(
    "PRAGMA table_info(patients)"
  );

  const hasDocType = cols.some(c => c.name === "documentType");
  if (!hasDocType) {
    await execAsync("ALTER TABLE patients ADD COLUMN documentType TEXT;");
  }
}

export async function migrate() {
  await execAsync(`
    PRAGMA journal_mode = WAL;

    CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );

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

  const seeded = await getFirstAsync<{ value: string }>(
    "SELECT value FROM meta WHERE key='seeded'"
  );

  if (!seeded?.value) {
    const now = Date.now();
    const hash = simpleHash("1234");

    await runAsync(
      "INSERT INTO meta(key,value) VALUES('seeded','1')"
    );

    await runAsync(
      `INSERT INTO employees (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        employeeNumber, name, phone, email, role,
        jobTitle, sector, passwordHash,
        mfaEnabled, mfaPhoneVerified, mfaEmailVerified, mfaImageToken
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, NULL)`,
      [
        "root-1",
        now,
        now,
        "0001",
        "Root Admin",
        "000000000",
        "root@hospital.com",
        "ROOT_ADMIN",
        "Root",
        "Administração",
        hash
      ]
    );
  }
}

.../patientDoctors.repo.ts
import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type PatientDoctor = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0 | 1;
  deletedAt?: number | null;
  patientId: string;
  doctorEmployeeId: string;
  assignedByEmployeeId: string;
};

export const PatientDoctorsRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<PatientDoctor>(
      "SELECT * FROM patient_doctors WHERE isDeleted=0 AND patientId=?",
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
    const exists = await this.isDoctorOfPatient(patientId, doctorEmployeeId);
    if (exists) return;

    const now = Date.now();

    await runAsync(
      `INSERT INTO patient_doctors
       (id, createdAt, updatedAt, isDeleted, deletedAt, patientId, doctorEmployeeId, assignedByEmployeeId)
       VALUES (?, ?, ?, 0, NULL, ?, ?, ?)`,
      [id(), now, now, patientId, doctorEmployeeId, assignedByEmployeeId]
    );
  },

  softUnassignById(rowId: string) {
    const now = Date.now();
    return runAsync(
      "UPDATE patient_doctors SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?",
      [now, now, rowId]
    );
  }
};


data/repositories/audit.repo.ts

import { getAllAsync, getFirstAsync } from "@/data/db/sqlite";
import { AuditLog } from "@/domain/entities/auditLog";

export const AuditRepo = {
  listLatest(limit = 200) {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 ORDER BY createdAt DESC LIMIT ?",
      [limit]
    );
  },

  listByActor(actorEmployeeId: string, limit = 200) {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 AND actorEmployeeId=? ORDER BY createdAt DESC LIMIT ?",
      [actorEmployeeId, limit]
    );
  },

  async lastLogin(actorEmployeeId: string) {
    const r = await getFirstAsync<{ createdAt: number }>(
      "SELECT createdAt FROM audit_logs WHERE action='LOGIN' AND actorEmployeeId=? ORDER BY createdAt DESC LIMIT 1",
      [actorEmployeeId]
    );
    return r?.createdAt ?? null;
  }
};


navigation/types.ts

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


navigation/RootNavigator.tsx


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

export function RootNavigator({ initialRoute }: { initialRoute: keyof RootStackParamList }) {
  return (
    <Stack.Navigator initialRouteName={initialRoute}>
      <Stack.Screen name="Auth" component={AuthScreen} />
      <Stack.Screen name="Mfa" component={MfaScreen} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
      <Stack.Screen name="EmployeeDetail" component={EmployeeDetailScreen} />
      <Stack.Screen name="EmployeeForm" component={EmployeeFormScreen} />
      <Stack.Screen name="PatientForm" component={PatientFormScreen} />
      <Stack.Screen name="ServiceForm" component={ServiceFormScreen} />
      <Stack.Screen name="AppointmentForm" component={AppointmentFormScreen} />
      <Stack.Screen name="PatientChart" component={PatientChartScreen} />
    </Stack.Navigator>
  );
}





