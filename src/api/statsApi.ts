import { http } from "./http";

export type StatsResponse = {
  counts: { employees: number; patients: number };
  lastLogin: {
    employee: null | { createdAt: string; actorEmployeeId: string };
    patient: null | { createdAt: string; actorPatientId: string };
  };
};

export async function getStats() {
  // backend respondeu OK em /stats/ (com barra)
  return http<StatsResponse>("/stats/", { method: "GET", auth: true });
}
