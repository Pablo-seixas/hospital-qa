import { Platform } from "react-native";
import { useAuthStore } from "@/state/authStore";

type HttpOptions = {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  body?: any;
  auth?: boolean;
  headers?: Record<string, string>;
};

function getBaseUrl() {
  const envUrl = process.env.EXPO_PUBLIC_API_BASE_URL;
  if (envUrl && envUrl.trim().length > 0) return envUrl.replace(/\/+$/, "");

  // fallback automático pra evitar dor de cabeça
  if (Platform.OS === "android") return "http://10.0.2.2:3333";
  return "http://localhost:3333";
}

export async function http<T>(path: string, opts: HttpOptions = {}): Promise<T> {
  const baseURL = getBaseUrl();
  const url = `${baseURL}${path.startsWith("/") ? "" : "/"}${path}`;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(opts.headers ?? {}),
  };

  if (opts.auth) {
    const accessToken = useAuthStore.getState().accessToken;
    if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
  }

  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });

  const text = await res.text();
  const isJson = (res.headers.get("content-type") ?? "").includes("application/json");
  const data = isJson && text ? JSON.parse(text) : text;

  if (!res.ok) {
    const msg =
      typeof data === "object" && data && "error" in data
        ? `${data.error}`
        : `HTTP_${res.status}`;
    throw new Error(msg);
  }

  return data as T;
}
