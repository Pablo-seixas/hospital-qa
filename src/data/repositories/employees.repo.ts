import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { Employee } from "@/domain/entities/employee";
import { id } from "@/utils/id";

export const EmployeesRepo = {
  list(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 ORDER BY name");
  },
  listDoctors(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 AND role='DOCTOR' ORDER BY name");
  },
  listNurses(): Promise<Employee[]> {
    return getAllAsync<Employee>("SELECT * FROM employees WHERE isDeleted=0 AND role='NURSE' ORDER BY name");
  },
  getById(empId: string): Promise<Employee | null> {
    return getFirstAsync<Employee>("SELECT * FROM employees WHERE id=? AND isDeleted=0", [empId]);
  },
  getByEmail(email: string): Promise<Employee | null> {
    return getFirstAsync<Employee>("SELECT * FROM employees WHERE email=? AND isDeleted=0", [email]);
  },
  async create(e: Omit<Employee, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<Employee> {
    const now = Date.now();
    const emp: Employee = { ...e, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO employees (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        employeeNumber, name, phone, email, role, jobTitle, sector,
        passwordHash, mfaEnabled, mfaPhoneVerified, mfaEmailVerified, mfaImageToken
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        emp.id, emp.createdAt, emp.updatedAt,
        emp.employeeNumber, emp.name, emp.phone, emp.email, emp.role, emp.jobTitle, emp.sector,
        emp.passwordHash, emp.mfaEnabled, emp.mfaPhoneVerified, emp.mfaEmailVerified, emp.mfaImageToken ?? null,
      ]
    );
    return emp;
  },
  async update(empId: string, patch: Partial<Employee>): Promise<Employee | null> {
    const cur = await this.getById(empId);
    if (!cur) return null;
    const next: Employee = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE employees SET
        updatedAt=?,
        employeeNumber=?, name=?, phone=?, email=?, role=?, jobTitle=?, sector=?,
        passwordHash=?, mfaEnabled=?, mfaPhoneVerified=?, mfaEmailVerified=?, mfaImageToken=?
      WHERE id=?`,
      [
        next.updatedAt,
        next.employeeNumber, next.name, next.phone, next.email, next.role, next.jobTitle, next.sector,
        next.passwordHash, next.mfaEnabled, next.mfaPhoneVerified, next.mfaEmailVerified, next.mfaImageToken ?? null,
        empId,
      ]
    );
    return next;
  },
  softDelete(empId: string) {
    const now = Date.now();
    return runAsync("UPDATE employees SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, empId]);
  },
};
