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
