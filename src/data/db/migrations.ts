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
