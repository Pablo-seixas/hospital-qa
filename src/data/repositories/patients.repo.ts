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
