import React, { useState } from "react";
import { View, TextInput, Button, Text } from "react-native";

type Props = {
  initial?: any;
  onSubmit: (data: any) => Promise<void>;
};

export function PatientForm({ initial, onSubmit }: Props) {
  const [name, setName] = useState(initial?.name ?? "");
  const [documentType, setDocumentType] = useState(initial?.documentType ?? "CPF");
  const [documentId, setDocumentId] = useState(initial?.documentId ?? "");
  const [phone, setPhone] = useState(initial?.phone ?? "");
  const [birthDate, setBirthDate] = useState(initial?.birthDate?.slice(0,10) ?? "");
  const [email, setEmail] = useState(initial?.email ?? "");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit() {
    setLoading(true);
    setError(null);
    try {
      await onSubmit({
        name,
        documentType,
        documentId,
        phone,
        birthDate,
        email,
      });
    } catch (e: any) {
      setError(String(e.message ?? "Erro"));
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={{ gap: 8 }}>
      <TextInput placeholder="Nome" value={name} onChangeText={setName} style={{ borderWidth:1, padding:8 }} />
      <TextInput placeholder="Tipo Documento (CPF/RG/CNH)" value={documentType} onChangeText={setDocumentType} style={{ borderWidth:1, padding:8 }} />
      <TextInput placeholder="Documento" value={documentId} onChangeText={setDocumentId} style={{ borderWidth:1, padding:8 }} />
      <TextInput placeholder="Telefone" value={phone} onChangeText={setPhone} style={{ borderWidth:1, padding:8 }} />
      <TextInput placeholder="Data Nascimento (YYYY-MM-DD)" value={birthDate} onChangeText={setBirthDate} style={{ borderWidth:1, padding:8 }} />
      <TextInput placeholder="Email" value={email} onChangeText={setEmail} style={{ borderWidth:1, padding:8 }} />

      {error && <Text style={{ color: "red" }}>{error}</Text>}

      <Button title={loading ? "Salvando..." : "Salvar"} onPress={handleSubmit} />
    </View>
  );
}
