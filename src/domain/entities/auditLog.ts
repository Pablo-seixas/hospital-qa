import { BaseEntity } from "./base";
export type AuditLog = BaseEntity & {
  actorEmployeeId: string;
  actorName: string;
  action: "CREATE"|"UPDATE"|"DELETE"|"LOGIN"|"MFA_VERIFY"|"MFA_ENABLE"|"MFA_DISABLE";
  entity: "EMPLOYEE"|"PATIENT"|"SERVICE"|"APPOINTMENT"|"BED";
  entityId: string;
  beforeJson?: string | null;
  afterJson?: string | null;
  metaJson?: string | null;
};
