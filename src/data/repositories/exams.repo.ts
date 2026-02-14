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
