import { getFirstAsync, getAllAsync } from "@/data/db/sqlite";

export const StatsRepo = {
  async counts() {
    const employees = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM employees WHERE isDeleted=0");
    const patients = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM patients WHERE isDeleted=0");
    const services = await getFirstAsync<{ c: number }>("SELECT COUNT(*) as c FROM service_types WHERE isDeleted=0");
    return {
      employees: employees?.c ?? 0,
      patients: patients?.c ?? 0,
      services: services?.c ?? 0,
    };
  },

  async todayAppointmentsCount(todayStart: number, todayEnd: number) {
    const r = await getFirstAsync<{ c: number }>(
      "SELECT COUNT(*) as c FROM appointments WHERE isDeleted=0 AND scheduledAt>=? AND scheduledAt<?",
      [todayStart, todayEnd]
    );
    return r?.c ?? 0;
  },

  async lastLogins(limit = 10) {
    return getAllAsync<{ actorName: string; actorEmployeeId: string; createdAt: number }>(
      "SELECT actorName, actorEmployeeId, createdAt FROM audit_logs WHERE isDeleted=0 AND action='LOGIN' ORDER BY createdAt DESC LIMIT ?",
      [limit]
    );
  },
};
