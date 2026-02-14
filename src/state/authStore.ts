import { create } from "zustand";
import { employeeLogin, employeeMe, employeeLogout } from "@/api/authApi";

type AuthState = {
  loading: boolean;
  employee: null | { id: string; name: string; role: string };
  error?: string;
  bootstrap: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
};

export const useAuthStore = create<AuthState>((set, get) => ({
  loading: false,
  employee: null,
  error: undefined,

  bootstrap: async () => {
    set({ loading: true, error: undefined });
    try {
      const me = await employeeMe();
      set({ employee: { id: me.id, name: me.name, role: me.role }, loading: false });
    } catch {
      set({ employee: null, loading: false });
    }
  },

  login: async (email, password) => {
    set({ loading: true, error: undefined });
    try {
      const res = await employeeLogin(email, password);
      set({ employee: res.employee, loading: false });
    } catch (e: any) {
      set({ loading: false, error: String(e?.message ?? "login_failed") });
      throw e;
    }
  },

  logout: async () => {
    set({ loading: true });
    await employeeLogout();
    set({ employee: null, loading: false });
  },
}));
