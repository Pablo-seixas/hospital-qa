import React, { useState } from "react";
import { View, Text, TextInput, Button } from "react-native";
import { http } from "@/api/http";

export function ForgotPasswordScreen() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onRequest() {
    setLoading(true);
    setError(null);
    setMsg(null);
    try {
      // backend esperado (vamos implementar depois se ainda não existir):
      // POST /auth/password/reset/request  { email }
      await http("/auth/password/reset/request", {
        method: "POST",
        body: { email },
      });
      setMsg("Se o email existir, enviamos um código para redefinir a senha.");
    } catch (e: any) {
      setError(String(e?.message ?? "reset_request_failed"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{ flex: 1, padding: 16, gap: 10 }}>
      <Text style={{ fontSize: 20, fontWeight: "700" }}>Esqueci a senha</Text>

      <TextInput
        placeholder="Email"
        autoCapitalize="none"
        value={email}
        onChangeText={setEmail}
        style={{ borderWidth: 1, borderRadius: 10, padding: 10 }}
      />

      {msg ? <Text style={{ color: "green" }}>{msg}</Text> : null}
      {error ? <Text style={{ color: "red" }}>{error}</Text> : null}

      <Button title={loading ? "Enviando..." : "Enviar código"} onPress={onRequest} />
      <Text style={{ opacity: 0.7 }}>
        Obs: esta tela depende do endpoint do backend para reset. Se der 404, a gente cria no backend na próxima etapa.
      </Text>
    </View>
  );
}
