import { create } from "zustand";
import { Role } from "@/domain/enums/roles";
import { getSessionEmployeeId } from "@/services/auth/auth.service";
import { EmployeesRepo } from "@/data/repositories/employees.repo";

type AuthState = {
  booting: boolean;
  employeeId: string | null;
  role: Role | null;
  employeeName: string | null;

  boot: () => Promise<void>;
  setSession: (employeeId: string | null, role?: Role | null, name?: string | null) => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  booting: true,
  employeeId: null,
  role: null,
  employeeName: null,

  boot: async () => {
    const id = await getSessionEmployeeId();
    if (!id) return set({ booting: false, employeeId: null, role: null, employeeName: null });
    const e = await EmployeesRepo.getById(id);
    set({ booting: false, employeeId: id, role: e?.role ?? null, employeeName: e?.name ?? null });
  },

  setSession: (employeeId, role, name) => set({ employeeId, role: role ?? null, employeeName: name ?? null }),
}));
