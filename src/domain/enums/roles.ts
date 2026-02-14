export enum Role {
  ROOT_ADMIN = "ROOT_ADMIN",
  STAFF_ADMIN = "STAFF_ADMIN",
  COORD_ADMIN = "COORD_ADMIN",
  DOCTOR = "DOCTOR",
  NURSE = "NURSE",
  RECEPTION = "RECEPTION",
  EMPLOYEE = "EMPLOYEE",
}

export const RoleLabel: Record<Role, string> = {
  [Role.ROOT_ADMIN]: "Root Admin",
  [Role.STAFF_ADMIN]: "Admin Funcionário",
  [Role.COORD_ADMIN]: "Admin Coordenação",
  [Role.DOCTOR]: "Médico",
  [Role.NURSE]: "Enfermeiro(a)",
  [Role.RECEPTION]: "Recepção",
  [Role.EMPLOYEE]: "Funcionário",
};
