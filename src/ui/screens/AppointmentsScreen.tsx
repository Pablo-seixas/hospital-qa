import React, { useEffect, useMemo, useState } from "react";
import { FlatList, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { Card } from "@/ui/components/Card";
import { AppointmentsRepo } from "@/data/repositories/appointments.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { formatDateTime } from "@/utils/dates";
import { startOfDay, addDays } from "date-fns";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, any>;

export function AppointmentsScreen({ navigation }: Props) {
  const [cursor, setCursor] = useState<Date>(new Date());
  const [items, setItems] = useState<any[]>([]);

  const start = startOfDay(cursor).getTime();
  const end = addDays(new Date(start), 1).getTime();

  async function load() {
    const appts = await AppointmentsRepo.listBetween(start, end);
    const vm = [];
    for (const a of appts) {
      const p = await PatientsRepo.getById(a.patientId);
      const d = await EmployeesRepo.getById(a.doctorEmployeeId);
      const s = await ServicesRepo.getById(a.serviceTypeId);
      vm.push({
        ...a,
        patientName: p?.name ?? "Paciente?",
        doctorName: d?.name ?? "Médico?",
        serviceName: s?.name ?? "Serviço?",
      });
    }
    setItems(vm);
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, start, end]);

  const dateLabel = useMemo(() => formatDateTime(start).split(" ")[0], [start]);

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 16 }}>Agenda do dia ({dateLabel})</Text>
      <View style={{ flexDirection: "row", gap: 10 }}>
        <Button title="Dia -1" variant="ghost" onPress={() => setCursor(new Date(cursor.getTime() - 86400000))} />
        <Button title="Dia +1" variant="ghost" onPress={() => setCursor(new Date(cursor.getTime() + 86400000))} />
      </View>

      <Button title="Novo agendamento" onPress={() => navigation.navigate("AppointmentForm")} />

      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerStyle={{ gap: 10 }}
        renderItem={({ item }) => (
          <Card
            title={`${formatDateTime(item.scheduledAt)} - ${item.patientName}`}
            subtitle={`Médico: ${item.doctorName} | Serviço: ${item.serviceName} | ${item.status}`}
            right={<Button title="Editar" variant="ghost" onPress={() => navigation.navigate("AppointmentForm", { id: item.id })} />}
          />
        )}
      />
    </Screen>
  );
}
