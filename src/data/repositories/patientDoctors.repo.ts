import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type PatientDoctor = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;
  patientId: string;
  doctorEmployeeId: string;
  assignedByEmployeeId: string;
};

export const PatientDoctorsRepo = {
  listByPatient(patientId: string) {
    return getAllAsync<PatientDoctor>(
      "SELECT * FROM patient_doctors WHERE isDeleted=0 AND patientId=? ORDER BY createdAt DESC",
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
    // evita duplicar
    const already = await this.isDoctorOfPatient(patientId, doctorEmployeeId);
    if (already) return;

    const now = Date.now();
    await runAsync(
      `INSERT INTO patient_doctors (id, createdAt, updatedAt, isDeleted, deletedAt, patientId, doctorEmployeeId, assignedByEmployeeId)
       VALUES (?, ?, ?, 0, NULL, ?, ?, ?)`,
      [id(), now, now, patientId, doctorEmployeeId, assignedByEmployeeId]
    );
  },

  softUnassignById(rowId: string) {
    const now = Date.now();
    return runAsync("UPDATE patient_doctors SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, rowId]);
  },
};
