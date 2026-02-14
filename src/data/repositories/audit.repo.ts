import { getAllAsync, getFirstAsync } from "@/data/db/sqlite";
import { AuditLog } from "@/domain/entities/auditLog";

export const AuditRepo = {
  listLatest(limit = 200): Promise<AuditLog[]> {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 ORDER BY createdAt DESC LIMIT ?",
      [limit]
    );
  },

  listByActor(actorEmployeeId: string, limit = 200): Promise<AuditLog[]> {
    return getAllAsync<AuditLog>(
      "SELECT * FROM audit_logs WHERE isDeleted=0 AND actorEmployeeId=? ORDER BY createdAt DESC LIMIT ?",
      [actorEmployeeId, limit]
    );
  },

  async lastLogin(actorEmployeeId: string): Promise<number | null> {
    const r = await getFirstAsync<{ createdAt: number }>(
      "SELECT createdAt FROM audit_logs WHERE isDeleted=0 AND actorEmployeeId=? AND action='LOGIN' ORDER BY createdAt DESC LIMIT 1",
      [actorEmployeeId]
    );
    return r?.createdAt ?? null;
  },
};
