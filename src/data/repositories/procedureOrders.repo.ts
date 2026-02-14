import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type ProcedureOrder = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;

  patientId: string;
  requestedByDoctorId: string;
  coordinatorEmployeeId?: string|null;

  title: string;
  description?: string|null;
  priority: "LOW"|"MEDIUM"|"HIGH"|"URGENT";
  plannedAt?: number|null;
  status: "REQUESTED"|"APPROVED"|"SCHEDULED"|"DONE"|"CANCELED";
};

export const ProcedureOrdersRepo = {
  list(): Promise<ProcedureOrder[]> {
    return getAllAsync<ProcedureOrder>("SELECT * FROM procedure_orders WHERE isDeleted=0 ORDER BY createdAt DESC");
  },

  listByPatient(patientId: string): Promise<ProcedureOrder[]> {
    return getAllAsync<ProcedureOrder>(
      "SELECT * FROM procedure_orders WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
      [patientId]
    );
  },

  getById(orderId: string): Promise<ProcedureOrder | null> {
    return getFirstAsync<ProcedureOrder>("SELECT * FROM procedure_orders WHERE isDeleted=0 AND id=?", [orderId]);
  },

  async create(o: Omit<ProcedureOrder,"id"|"createdAt"|"updatedAt"|"isDeleted">) {
    const now = Date.now();
    const row: ProcedureOrder = { ...o, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO procedure_orders (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        patientId, requestedByDoctorId, coordinatorEmployeeId,
        title, description, priority, plannedAt, status
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        row.id, row.createdAt, row.updatedAt,
        row.patientId, row.requestedByDoctorId, row.coordinatorEmployeeId ?? null,
        row.title, row.description ?? null, row.priority, row.plannedAt ?? null, row.status
      ]
    );
    return row;
  },

  async update(orderId: string, patch: Partial<ProcedureOrder>) {
    const cur = await this.getById(orderId);
    if (!cur) return null;
    const next: ProcedureOrder = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE procedure_orders SET
        updatedAt=?,
        patientId=?, requestedByDoctorId=?, coordinatorEmployeeId=?,
        title=?, description=?, priority=?, plannedAt=?, status=?
      WHERE id=?`,
      [
        next.updatedAt,
        next.patientId, next.requestedByDoctorId, next.coordinatorEmployeeId ?? null,
        next.title, next.description ?? null, next.priority, next.plannedAt ?? null, next.status,
        orderId
      ]
    );
    return next;
  },

  softDelete(orderId: string) {
    const now = Date.now();
    return runAsync("UPDATE procedure_orders SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, orderId]);
  },
};
