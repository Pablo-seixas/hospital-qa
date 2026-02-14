import { getAllAsync, runAsync } from "@/data/db/sqlite";
import { id } from "@/utils/id";

export type TeamMember = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0|1;
  deletedAt?: number|null;
  orderId: string;
  employeeId: string;
  teamRole: string;
  isLead: 0|1;
};

export const ProcedureTeamRepo = {
  list(orderId: string): Promise<TeamMember[]> {
    return getAllAsync<TeamMember>(
      "SELECT * FROM procedure_team_members WHERE isDeleted=0 AND orderId=? ORDER BY isLead DESC, createdAt ASC",
      [orderId]
    );
  },

  async add(orderId: string, employeeId: string, teamRole: string, isLead: boolean) {
    const now = Date.now();
    await runAsync(
      `INSERT INTO procedure_team_members (id, createdAt, updatedAt, isDeleted, deletedAt, orderId, employeeId, teamRole, isLead)
       VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?)`,
      [id(), now, now, orderId, employeeId, teamRole, isLead ? 1 : 0]
    );
  },

  async clear(orderId: string) {
    const now = Date.now();
    await runAsync(
      "UPDATE procedure_team_members SET isDeleted=1, deletedAt=?, updatedAt=? WHERE orderId=? AND isDeleted=0",
      [now, now, orderId]
    );
  },
};
