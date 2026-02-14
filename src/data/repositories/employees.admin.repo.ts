import { getFirstAsync, runAsync } from "@/data/db/sqlite";

export const EmployeesAdminRepo = {
  getById(id: string) {
    return getFirstAsync<any>("SELECT * FROM employees WHERE isDeleted=0 AND id=?", [id]);
  },

  async setCanBuildTeam(employeeId: string, can: boolean) {
    const now = Date.now();
    await runAsync("UPDATE employees SET canBuildTeam=?, updatedAt=? WHERE id=?", [can ? 1 : 0, now, employeeId]);
  },

  async terminate(employeeId: string, terminatedByEmployeeId: string) {
    const now = Date.now();
    // bloqueia login e mantém histórico
    await runAsync(
      "UPDATE employees SET status='TERMINATED', terminatedAt=?, terminatedByEmployeeId=?, updatedAt=? WHERE id=?",
      [now, terminatedByEmployeeId, terminatedByEmployeeId, now, employeeId]
    );
  },
};
