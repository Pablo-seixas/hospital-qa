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
