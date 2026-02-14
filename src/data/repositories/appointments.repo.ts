import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { Appointment } from "@/domain/entities/appointment";
import { id } from "@/utils/id";

export const AppointmentsRepo = {
  listBetween(startTs: number, endTs: number): Promise<Appointment[]> {
    return getAllAsync<Appointment>(
      "SELECT * FROM appointments WHERE isDeleted=0 AND scheduledAt>=? AND scheduledAt<? ORDER BY scheduledAt ASC",
      [startTs, endTs]
    );
  },
  getById(aid: string): Promise<Appointment | null> {
    return getFirstAsync<Appointment>("SELECT * FROM appointments WHERE id=? AND isDeleted=0", [aid]);
  },
  async create(a: Omit<Appointment, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<Appointment> {
    const now = Date.now();
    const row: Appointment = { ...a, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO appointments (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, doctorEmployeeId, serviceTypeId,
        scheduledAt, durationMin, status, notes
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?)`,
      [row.id, row.createdAt, row.updatedAt, row.patientId, row.doctorEmployeeId, row.serviceTypeId, row.scheduledAt, row.durationMin, row.status, row.notes ?? null]
    );
    return row;
  },
  async update(aid: string, patch: Partial<Appointment>): Promise<Appointment | null> {
    const cur = await this.getById(aid);
    if (!cur) return null;
    const next: Appointment = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE appointments SET updatedAt=?, patientId=?, doctorEmployeeId=?, serviceTypeId=?, scheduledAt=?, durationMin=?, status=?, notes=? WHERE id=?`,
      [next.updatedAt, next.patientId, next.doctorEmployeeId, next.serviceTypeId, next.scheduledAt, next.durationMin, next.status, next.notes ?? null, aid]
    );
    return next;
  },
  softDelete(aid: string) {
    const now = Date.now();
    return runAsync("UPDATE appointments SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, aid]);
  },
};
