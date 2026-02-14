import React, { useEffect, useState } from "react";
import { FlatList, Text, TextInput } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { Employee } from "@/domain/entities/employee";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function EmployeesScreen({ navigation }: Props) {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<Employee[]>([]);

  async function load() {
    setItems(await EmployeesRepo.list());
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation]);

  const filtered = items.filter((e) => {
    const s = q.trim().toLowerCase();
    if (!s) return true;
    return (e.name + e.employeeNumber + e.sector + e.jobTitle + e.role).toLowerCase().includes(s);
  });

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Funcionários</Text>
      <TextInput
        placeholder="Buscar por nome, número, setor..."
        value={q}
        onChangeText={setQ}
        style={{ borderWidth: 1, borderColor: "#ddd", borderRadius: 12, padding: 12 }}
      />

      <Button title="Novo funcionário" onPress={() => navigation.navigate("EmployeeForm")} />

      <FlatList
        data={filtered}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${item.employeeNumber} - ${item.name}`}
            subtitle={`${item.role} | ${item.jobTitle} | ${item.sector}`}
            right={
              <>
                <Button title="Ver" variant="ghost" onPress={() => navigation.navigate("EmployeeDetail", { id: item.id })} />
              </>
            }
          />
        )}
      />
    </Screen>
  );
}
