import React, { useEffect, useState } from "react";
import { View, Text, ScrollView, RefreshControl } from "react-native";
import { http } from "@/api/http";

type Stats = {
  counts: { employees: number; patients: number };
  lastLogin: {
    employee: { createdAt: string; actorEmployeeId: string } | null;
    patient: { createdAt: string; actorPatientId: string } | null;
  };
};

function getBaseUrlForDisplay() {
  const envUrl = process.env.EXPO_PUBLIC_API_BASE_URL;
  if (envUrl && envUrl.trim().length > 0) return envUrl;
  // fallback do http.ts
  return "http://10.0.2.2:3333 (Android emulador) / http://localhost:3333 (PC)";
}

export function DashboardScreen() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  async function load() {
    setError(null);
    try {
      const data = await http<Stats>("/stats/", { method: "GET", auth: true });
      setStats(data);
    } catch (e: any) {
      setStats(null);
      setError(String(e?.message ?? "erro"));
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function onRefresh() {
    setRefreshing(true);
    try {
      await load();
    } finally {
      setRefreshing(false);
    }
  }

  return (
    <ScrollView
      contentContainerStyle={{ padding: 16, gap: 12 }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
    >
      <Text style={{ fontSize: 22, fontWeight: "700" }}>Dashboard</Text>

      <View style={{ borderWidth: 1, borderRadius: 10, padding: 12 }}>
        <Text style={{ fontWeight: "700" }}>API</Text>
        <Text>Base URL (env/fallback): {getBaseUrlForDisplay()}</Text>
        <Text style={{ marginTop: 6 }}>
          Dica Android emulador: EXPO_PUBLIC_API_BASE_URL = http://10.0.2.2:3333
        </Text>
      </View>

      {error ? (
        <View style={{ borderWidth: 1, borderRadius: 10, padding: 12 }}>
          <Text style={{ fontWeight: "700" }}>Erro</Text>
          <Text>AUTH_EXPIRED / TOKEN / URL: {error}</Text>
        </View>
      ) : null}

      <View style={{ borderWidth: 1, borderRadius: 10, padding: 12 }}>
        <Text style={{ fontWeight: "700" }}>Cadastros</Text>
        <Text>Funcionários: {stats?.counts?.employees ?? "--"}</Text>
        <Text>Pacientes: {stats?.counts?.patients ?? "--"}</Text>
      </View>

      <View style={{ borderWidth: 1, borderRadius: 10, padding: 12 }}>
        <Text style={{ fontWeight: "700" }}>Últimos acessos</Text>
        <Text>Funcionário: {stats?.lastLogin?.employee?.createdAt ?? "--"}</Text>
        <Text>Paciente: {stats?.lastLogin?.patient?.createdAt ?? "--"}</Text>
      </View>

      <Text style={{ opacity: 0.7 }}>Puxe para baixo para atualizar.</Text>
    </ScrollView>
  );
}
