import React, { useEffect, useMemo, useState } from "react";
import { Alert, FlatList, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { AuditRepo } from "@/data/repositories/audit.repo";
import { EmployeesAdminRepo } from "@/data/repositories/employees.admin.repo";
import { formatDateTime } from "@/utils/dates";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { Role } from "@/domain/enums/roles";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "EmployeeDetail">;

export function EmployeeDetailScreen({ navigation, route }: Props) {
  const { id } = route.params;

  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const actorRole = useAuthStore((s) => s.role)!;

  const isRoot = actorRole === Role.ROOT_ADMIN;

  const [emp, setEmp] = useState<any>(null);
  const [skills, setSkills] = useState<string[]>([]);
  const [lastLogin, setLastLogin] = useState<number | null>(null);
  const [history, setHistory] = useState<any[]>([]);
  const [serviceMap, setServiceMap] = useState<Map<string, string>>(new Map());

  async function load() {
    const e = await EmployeesAdminRepo.getById(id); // pega status/canBuildTeam também
    setEmp(e);

    const services = await ServicesRepo.list();
    setServiceMap(new Map(services.map((s) => [s.id, s.name])));

    const sk = await EmployeeSkillsRepo.listByEmployee(id);
    setSkills(sk.map((x) => x.serviceTypeId));

    setLastLogin(await AuditRepo.lastLogin(id));
    setHistory(await AuditRepo.listByActor(id, 200));
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, id]);

  const skillsLabel = useMemo(() => {
    if (!skills.length) return "—";
    return skills.map((sid) => serviceMap.get(sid) ?? sid).join(", ");
  }, [skills, serviceMap]);

  async function toggleCanBuildTeam() {
    if (!isRoot) return;
    if (!emp) return;

    const next = !(emp.canBuildTeam === 1);
    await EmployeesAdminRepo.setCanBuildTeam(emp.id, next);

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "UPDATE",
      entity: "EMPLOYEE",
      entityId: emp.id,
      meta: { canBuildTeam: next },
      before: emp,
      after: { ...emp, canBuildTeam: next ? 1 : 0 },
    });

    await load();
  }

  async function terminateEmployee() {
    if (!isRoot) return;
    if (!emp) return;

    if (emp.id === actorId) {
      Alert.alert("Bloqueado", "Você não pode desligar o próprio Root Admin.");
      return;
    }

    Alert.alert(
      "Desligamento (RH)",
      "Isso bloqueia o login do funcionário (status TERMINATED), mantém o histórico e impede novas alterações por ele. Confirmar?",
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Confirmar desligamento",
          style: "destructive",
          onPress: async () => {
            const before = emp;
            await EmployeesAdminRepo.terminate(emp.id, actorId);

            await auditLog({
              actorEmployeeId: actorId,
              actorName,
              action: "UPDATE",
              entity: "EMPLOYEE",
              entityId: emp.id,
              meta: { terminated: true },
              before,
              after: { ...before, status: "TERMINATED" },
            });

            await load();
            Alert.alert("OK", "Funcionário desligado (RH).");
          },
        },
      ]
    );
  }

  if (!emp) return <Screen><Text>Carregando...</Text></Screen>;

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 18 }}>{emp.name}</Text>
        <Text>Número: {emp.employeeNumber}</Text>
        <Text>Role: {emp.role}</Text>
        <Text>Cargo: {emp.jobTitle}</Text>
        <Text>Setor: {emp.sector}</Text>
        <Text>Email: {emp.email}</Text>
        <Text>Telefone: {emp.phone}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Status (RH)</Text>
        <Text>{emp.status ?? "ACTIVE"}</Text>

        <Text style={{ fontWeight: "900" }}>Último acesso</Text>
        <Text>{lastLogin ? formatDateTime(lastLogin) : "—"}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Procedimentos/serviços que realiza</Text>
        <Text style={{ color: "#666" }}>{skillsLabel}</Text>

        <Button title="Editar funcionário" variant="ghost" onPress={() => navigation.navigate("EmployeeForm", { id })} />

        {/* AÇÕES ADMIN (ROOT) */}
        {isRoot && (
          <View style={{ gap: 10, marginTop: 8 }}>
            <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />
            <Text style={{ fontWeight: "900" }}>Ações do Root Admin</Text>

            <Text style={{ color: "#666" }}>
              Permitir que este médico (ou funcionário) monte equipe em ordens/procedimentos:
            </Text>
            <Button
              title={emp.canBuildTeam === 1 ? "✓ Pode montar equipe (clique p/ remover)" : "Permitir montar equipe"}
              onPress={toggleCanBuildTeam}
              variant={emp.canBuildTeam === 1 ? "primary" : "ghost"}
            />

            <Text style={{ color: "#666" }}>
              Desligamento RH: bloqueia login, mantém histórico e auditoria.
            </Text>
            <Button title="Desligar (RH)" variant="danger" onPress={terminateEmployee} />
          </View>
        )}

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Histórico de ações (até 200)</Text>
        <FlatList
          data={history}
          keyExtractor={(i) => i.id}
          scrollEnabled={false}
          contentContainerStyle={{ gap: 10 }}
          renderItem={({ item }) => (
            <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
              <Text style={{ fontWeight: "900" }}>{item.action} {item.entity}</Text>
              <Text>{formatDateTime(item.createdAt)}</Text>
              <Text style={{ color: "#666" }}>Entidade ID: {item.entityId}</Text>
            </View>
          )}
        />
      </ScrollView>
    </Screen>
  );
}
