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
