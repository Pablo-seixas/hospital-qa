import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";
import { DocumentType, validateBirthDate, validateDocument, validatePhone } from "@/domain/validators/patient.validators";

type Props = NativeStackScreenProps<RootStackParamList, "PatientForm">;

export function PatientFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const nowYear = new Date().getFullYear(); // em 2026, trava em 2026
  const minYear = nowYear - 126;

  const id = route.params?.id;
  const editing = !!id;

  const [name, setName] = useState("");
  const [documentType, setDocumentType] = useState<DocumentType>("CPF");
  const [documentId, setDocumentId] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [birthDate, setBirthDate] = useState(""); // obrigatório
  const [notes, setNotes] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await PatientsRepo.getById(id!);
        if (!cur) return;
        setName(cur.name);
        setDocumentId(cur.documentId);
        setDocumentType((cur.documentType as DocumentType) ?? "CPF");
        setPhone(cur.phone);
        setEmail(cur.email ?? "");
        setBirthDate(cur.birthDate ?? "");
        setNotes(cur.notes ?? "");
      }
    })();
  }, [editing, id]);

  const docHint = useMemo(() => {
    if (documentType === "CPF") return "CPF: 11 dígitos (com validação)";
    if (documentType === "RG") return "RG: 7 a 12 dígitos (regra mínima)";
    return "CNH: 11 dígitos";
  }, [documentType]);

  function validateAll(): boolean {
    setError(null);

    if (!name.trim()) return setError("Nome é obrigatório"), false;

    if (!documentId.trim()) return setError("Documento é obrigatório"), false;
    if (!validateDocument(documentType, documentId)) return setError(`Documento inválido para ${documentType}. ${docHint}`), false;

    if (!phone.trim()) return setError("Telefone é obrigatório"), false;
    if (!validatePhone(phone)) return setError("Telefone inválido (use DDD + número: 10 ou 11 dígitos)"), false;

    if (!birthDate.trim()) return setError("Data de nascimento é obrigatória"), false;
    const bd = validateBirthDate(birthDate, nowYear);
    if (!bd.ok) return setError(`Nascimento inválido: ${bd.reason}. Permitido: ${minYear} até ${nowYear}`), false;

    return true;
  }

  async function save() {
    if (!validateAll()) return;

    if (!editing) {
      const created = await PatientsRepo.create({
        name,
        documentId,
        documentType,
        phone,
        email: email || null,
        birthDate, // obrigatório
        notes: notes || null,
        deletedAt: null,
      });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "PATIENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await PatientsRepo.getById(id!);
    const next = await PatientsRepo.update(id!, {
      name,
      documentId,
      documentType,
      phone,
      email: email || null,
      birthDate,
      notes: notes || null,
    });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "PATIENT", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir paciente (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await PatientsRepo.getById(id!);
          await PatientsRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "PATIENT", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar paciente" : "Novo paciente"}</Text>

        {!!error && <Text style={{ color: "#8b0000", fontWeight: "800" }}>{error}</Text>}

        <Input label="Nome (obrigatório)" value={name} onChangeText={setName} />

        <Text style={{ fontWeight: "900" }}>Tipo de documento (obrigatório)</Text>
        <View style={{ flexDirection: "row", gap: 10 }}>
          <Button title={documentType === "CPF" ? "✓ CPF" : "CPF"} variant={documentType === "CPF" ? "primary" : "ghost"} onPress={() => setDocumentType("CPF")} />
          <Button title={documentType === "RG" ? "✓ RG" : "RG"} variant={documentType === "RG" ? "primary" : "ghost"} onPress={() => setDocumentType("RG")} />
          <Button title={documentType === "CNH" ? "✓ CNH" : "CNH"} variant={documentType === "CNH" ? "primary" : "ghost"} onPress={() => setDocumentType("CNH")} />
        </View>

        <Input label={`Documento (${documentType}) - obrigatório`} value={documentId} onChangeText={setDocumentId} placeholder={docHint} />

        <Input label="Telefone (obrigatório)" value={phone} onChangeText={setPhone} placeholder="ex: (71) 99999-9999" />
        <Input label="Data nascimento (YYYY-MM-DD) obrigatório" value={birthDate} onChangeText={setBirthDate} placeholder={`Entre ${minYear}-01-01 e ${nowYear}-12-31`} />

        <Input label="Email (opcional)" value={email} onChangeText={setEmail} />
        <Input label="Observações (opcional)" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
