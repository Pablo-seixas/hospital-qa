import React, { useState } from "react";
import { View, Text, TextInput, Button } from "react-native";
import { http } from "@/api/http";

export function PatientRegisterScreen() {
  const [name, setName] = useState("");
  const [documentType, setDocumentType] = useState<"CPF"|"RG"|"CNH">("CPF");
  const [documentId, setDocumentId] = useState("");
  const [phone, setPhone] = useState("");
  const [birthDate, setBirthDate] = useState(""); // YYYY-MM-DD
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function onRegister() {
    setLoading(true);
    setError(null);
    setMsg(null);
    try {
      // backend esperado: POST /auth/patient/register
      await http("/auth/patient/register", {
        method: "POST",
        body: { name, documentType, documentId, phone, birthDate, email, password },
      });
      setMsg("Cadastro enviado. Verifique o código (email) no fluxo de verificação.");
    } catch (e: any) {
      setError(String(e?.message ?? "register_failed"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{ flex: 1, padding: 16, gap: 10 }}>
      <Text style={{ fontSize: 20, fontWeight: "700" }}>Criar conta (Paciente)</Text>

      <TextInput placeholder="Nome" value={name} onChangeText={setName} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />
      <TextInput placeholder="Tipo doc (CPF/RG/CNH)" value={documentType} onChangeText={(v) => setDocumentType((v as any) || "CPF")} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />
      <TextInput placeholder="Documento" value={documentId} onChangeText={setDocumentId} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />
      <TextInput placeholder="Telefone" value={phone} onChangeText={setPhone} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />
      <TextInput placeholder="Nascimento (YYYY-MM-DD)" value={birthDate} onChangeText={setBirthDate} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />

      <TextInput placeholder="Email" autoCapitalize="none" value={email} onChangeText={setEmail} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />
      <TextInput placeholder="Senha" secureTextEntry value={password} onChangeText={setPassword} style={{ borderWidth: 1, borderRadius: 10, padding: 10 }} />

      {msg ? <Text style={{ color: "green" }}>{msg}</Text> : null}
      {error ? <Text style={{ color: "red" }}>{error}</Text> : null}

      <Button title={loading ? "Criando..." : "Criar conta"} onPress={onRegister} />
    </View>
  );
}
