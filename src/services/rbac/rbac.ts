import { Role } from "@/domain/enums/roles";
import { Permission } from "@/domain/enums/permissions";

const rolePermissions: Record<Role, Permission[]> = {
  [Role.ROOT_ADMIN]: Object.values(Permission),

  [Role.STAFF_ADMIN]: [
    Permission.EMPLOYEE_CREATE,
    Permission.EMPLOYEE_UPDATE,
    Permission.EMPLOYEE_DELETE,
    Permission.EMPLOYEE_VIEW,
    Permission.AUDIT_VIEW,
  ],

  [Role.COORD_ADMIN]: [
    Permission.APPOINTMENT_CREATE,
    Permission.APPOINTMENT_UPDATE,
    Permission.APPOINTMENT_DELETE,
    Permission.APPOINTMENT_VIEW,
    Permission.BED_CREATE,
    Permission.BED_UPDATE,
    Permission.BED_VIEW,
    Permission.AUDIT_VIEW,
    Permission.PATIENT_VIEW,
  ],

  [Role.DOCTOR]: [Permission.APPOINTMENT_VIEW, Permission.PATIENT_VIEW, Permission.BED_VIEW],
  [Role.NURSE]: [Permission.APPOINTMENT_VIEW, Permission.PATIENT_VIEW, Permission.BED_VIEW],

  [Role.RECEPTION]: [
    Permission.PATIENT_CREATE,
    Permission.PATIENT_UPDATE,
    Permission.PATIENT_VIEW,
    Permission.APPOINTMENT_CREATE,
    Permission.APPOINTMENT_UPDATE,
    Permission.APPOINTMENT_VIEW,
    Permission.BED_VIEW,
  ],

  [Role.EMPLOYEE]: [Permission.APPOINTMENT_VIEW, Permission.PATIENT_VIEW],
};

export function can(role: Role, permission: Permission): boolean {
  return rolePermissions[role]?.includes(permission) ?? false;
}
