import { id } from "@/utils/id";
import { runAsync } from "@/data/db/sqlite";

export function auditLog(params: {
  actorEmployeeId: string;
  actorName: string;
  action: "CREATE"|"UPDATE"|"DELETE"|"LOGIN"|"MFA_VERIFY"|"MFA_ENABLE"|"MFA_DISABLE";
  entity: "EMPLOYEE"|"PATIENT"|"SERVICE"|"APPOINTMENT"|"BED";
  entityId: string;
  before?: unknown;
  after?: unknown;
  meta?: unknown;
}) {
  const now = Date.now();
  return runAsync(
    `INSERT INTO audit_logs (
      id, createdAt, updatedAt, isDeleted, deletedAt,
      actorEmployeeId, actorName, action, entity, entityId,
      beforeJson, afterJson, metaJson
    ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      id(), now, now,
      params.actorEmployeeId, params.actorName,
      params.action, params.entity, params.entityId,
      params.before ? JSON.stringify(params.before) : null,
      params.after ? JSON.stringify(params.after) : null,
      params.meta ? JSON.stringify(params.meta) : null,
    ]
  );
}
