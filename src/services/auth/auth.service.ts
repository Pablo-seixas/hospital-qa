import AsyncStorage from "@react-native-async-storage/async-storage";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { simpleHash } from "@/utils/hash";
import { auditLog } from "@/services/audit/audit.service";

const SESSION_KEY = "SESSION_EMPLOYEE_ID";
const MFA_PENDING_KEY = "MFA_PENDING_EMPLOYEE_ID";

export async function login(email: string, password: string) {
  const e = await EmployeesRepo.getByEmail(email);
  if (!e) return { ok: false as const, error: "Usuário não encontrado" };
  if (e.passwordHash !== simpleHash(password)) return { ok: false as const, error: "Senha incorreta" };

  await auditLog({
    actorEmployeeId: e.id, actorName: e.name,
    action: "LOGIN", entity: "EMPLOYEE", entityId: e.id,
    meta: { email },
  });

  if (e.mfaEnabled === 1) {
    await AsyncStorage.setItem(MFA_PENDING_KEY, e.id);
    return { ok: true as const, mfaRequired: true, employeeId: e.id };
  }

  await AsyncStorage.setItem(SESSION_KEY, e.id);
  return { ok: true as const, mfaRequired: false, employeeId: e.id };
}

export async function logout() {
  await AsyncStorage.removeItem(SESSION_KEY);
  await AsyncStorage.removeItem(MFA_PENDING_KEY);
}

export async function getSessionEmployeeId() {
  return (await AsyncStorage.getItem(SESSION_KEY)) ?? null;
}

export async function getMfaPendingEmployeeId() {
  return (await AsyncStorage.getItem(MFA_PENDING_KEY)) ?? null;
}

export async function verifyMfa(params: { phoneCode: string; emailCode: string; imageToken: string }) {
  const pendingId = await getMfaPendingEmployeeId();
  if (!pendingId) return { ok: false as const, error: "Sem MFA pendente" };

  const e = await EmployeesRepo.getById(pendingId);
  if (!e) return { ok: false as const, error: "Usuário não encontrado" };

  const okPhone = params.phoneCode === "111111";
  const okEmail = params.emailCode === "222222";
  const okImage = (e.mfaImageToken ? params.imageToken === e.mfaImageToken : params.imageToken === "IMG");

  if (!okPhone || !okEmail || !okImage) return { ok: false as const, error: "Códigos MFA inválidos (demo)" };

  await EmployeesRepo.update(e.id, { mfaPhoneVerified: 1, mfaEmailVerified: 1 });

  await auditLog({
    actorEmployeeId: e.id, actorName: e.name,
    action: "MFA_VERIFY", entity: "EMPLOYEE", entityId: e.id,
  });

  await AsyncStorage.setItem(SESSION_KEY, e.id);
  await AsyncStorage.removeItem(MFA_PENDING_KEY);

  return { ok: true as const, employeeId: e.id };
}
