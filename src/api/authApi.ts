import { http } from "./http";
import { setTokens, clearTokens, getRefreshToken } from "./tokenStorage";
import { API_BASE_URL } from "./config";

export type EmployeeLoginResponse = {
  accessToken: string;
  refreshToken: string;
  employee: { id: string; name: string; role: string };
  accessExpiresIn?: string;
  refreshExpiresDays?: number;
};

export async function employeeLogin(email: string, password: string) {
  const data = await http<EmployeeLoginResponse>("/auth/employee/login", {
    method: "POST",
    auth: false,
    body: { email, password },
  });

  // salva tokens
  await setTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
  return data;
}

export async function employeeMe() {
  return http<any>("/auth/employee/me", { method: "GET", auth: true });
}

export async function employeeLogout() {
  const refreshToken = await getRefreshToken();
  if (refreshToken) {
    // logout não precisa access token
    await fetch(`${API_BASE_URL}/auth/employee/logout`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken }),
    }).catch(() => {});
  }
  await clearTokens();
}
