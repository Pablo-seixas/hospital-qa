import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type EmployeeSkill = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0 | 1;
  deletedAt?: number | null;
  employeeId: string;
  serviceTypeId: string;
};

export const EmployeeSkillsRepo = {
  listByEmployee(employeeId: string) {
    return getAllAsync<EmployeeSkill>(
      "SELECT * FROM employee_service_types WHERE isDeleted=0 AND employeeId=? ORDER BY createdAt DESC",
      [employeeId]
    );
  },

  async setSkills(employeeId: string, serviceTypeIds: string[]) {
    // estratégia simples: apaga (soft) e recria
    const now = Date.now();
    await runAsync(
      "UPDATE employee_service_types SET isDeleted=1, deletedAt=?, updatedAt=? WHERE employeeId=? AND isDeleted=0",
      [now, now, employeeId]
    );

    for (const sid of serviceTypeIds) {
      const rowId = id();
      await runAsync(
        `INSERT INTO employee_service_types (id, createdAt, updatedAt, isDeleted, deletedAt, employeeId, serviceTypeId)
         VALUES (?, ?, ?, 0, NULL, ?, ?)`,
        [rowId, now, now, employeeId, sid]
      );
    }
  },
};
