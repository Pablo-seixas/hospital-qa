import React, { useState } from "react";
import { View, Text, TextInput, Button, Pressable } from "react-native";
import { useAuthStore } from "@/state/authStore";
import { useNavigation } from "@react-navigation/native";

export function AuthScreen() {
  const navigation = useNavigation<any>();
  const login = useAuthStore((s) => s.login);
  const loading = useAuthStore((s) => s.loading);

  const [email, setEmail] = useState("root@hospital.com");
  const [password, setPassword] = useState("1234");
  const [error, setError] = useState<string | null>(null);

  async function onLogin() {
    setError(null);
    try {
      await login(email.trim(), password);
    } catch (e: any) {
      setError(String(e?.message ?? "login_failed"));
    }
  }

  return (
    <View style={{ flex: 1, padding: 16, justifyContent: "center", gap: 10 }}>
      <Text style={{ fontSize: 22, fontWeight: "700" }}>Hospital</Text>

      <TextInput
        placeholder="Email"
        autoCapitalize="none"
        value={email}
        onChangeText={setEmail}
        style={{ borderWidth: 1, borderRadius: 10, padding: 10 }}
      />
      <TextInput
        placeholder="Senha"
        secureTextEntry
        value={password}
        onChangeText={setPassword}
        style={{ borderWidth: 1, borderRadius: 10, padding: 10 }}
      />

      {error ? <Text style={{ color: "red" }}>{error}</Text> : null}

      <Button title={loading ? "Entrando..." : "Entrar"} onPress={onLogin} />

      {/* ✅ links embaixo */}
      <View style={{ marginTop: 10, gap: 8 }}>
        <Pressable onPress={() => navigation.navigate("PatientRegister")}>
          <Text style={{ color: "#0b5", fontWeight: "700" }}>Criar conta</Text>
        </Pressable>

        <Pressable onPress={() => navigation.navigate("ForgotPassword")}>
          <Text style={{ color: "#06c", fontWeight: "700" }}>Esqueci a senha</Text>
        </Pressable>
      </View>

      <Text style={{ opacity: 0.7, marginTop: 12 }}>
        Android emulador: EXPO_PUBLIC_API_BASE_URL = http://10.0.2.2:3333
      </Text>
    </View>
  );
}
