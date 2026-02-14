import React, { useEffect, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "ServiceForm">;

export function ServiceFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [name, setName] = useState("");
  const [treatment, setTreatment] = useState("");
  const [priceCents, setPriceCents] = useState("0");

  useEffect(() => {
    (async () => {
      if (editing) {
        const cur = await ServicesRepo.getById(id!);
        if (!cur) return;
        setName(cur.name);
        setTreatment(cur.treatment);
        setPriceCents(String(cur.priceCents));
      }
    })();
  }, [editing, id]);

  async function save() {
    const pc = Number(priceCents || "0");
    if (!editing) {
      const created = await ServicesRepo.create({ name, treatment, priceCents: pc, deletedAt: null });
      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "SERVICE", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await ServicesRepo.getById(id!);
    const next = await ServicesRepo.update(id!, { name, treatment, priceCents: pc });
    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "SERVICE", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir serviço (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await ServicesRepo.getById(id!);
          await ServicesRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "SERVICE", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar serviço" : "Novo serviço"}</Text>

        <Input label="Nome do serviço" value={name} onChangeText={setName} />
        <Input label="Tipo de tratamento" value={treatment} onChangeText={setTreatment} />
        <Input label="Preço (centavos)" value={priceCents} onChangeText={setPriceCents} />

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
