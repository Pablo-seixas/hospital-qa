import { can } from '@/services/rbac/rbac';
import { Role } from '@/domain/enums/roles';
import { Permission } from '@/domain/enums/permissions';

describe('rbac.can', () => {
  it('ROOT_ADMIN has all permissions', () => {
    for (const p of Object.values(Permission)) {
      expect(can(Role.ROOT_ADMIN, p)).toBe(true);
    }
  });

  it('RECEPTION can create/view patient but cannot delete employee', () => {
    expect(can(Role.RECEPTION, Permission.PATIENT_CREATE)).toBe(true);
    expect(can(Role.RECEPTION, Permission.PATIENT_VIEW)).toBe(true);
    expect(can(Role.RECEPTION, Permission.EMPLOYEE_DELETE)).toBe(false);
  });

  it('EMPLOYEE has limited permissions', () => {
    expect(can(Role.EMPLOYEE, Permission.APPOINTMENT_VIEW)).toBe(true);
    expect(can(Role.EMPLOYEE, Permission.PATIENT_VIEW)).toBe(true);
    expect(can(Role.EMPLOYEE, Permission.PATIENT_CREATE)).toBe(false);
  });
});
