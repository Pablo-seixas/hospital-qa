import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";
import { Input } from "@/ui/components/Input";

import { ProcedureOrdersRepo } from "@/data/repositories/procedureOrders.repo";
import { ProcedureTeamRepo } from "@/data/repositories/procedureTeam.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { EmployeesAdminRepo } from "@/data/repositories/employees.admin.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { PatientEventsRepo } from "@/data/repositories/patientEvents.repo";

import { generateAndSharePdf } from "@/services/reports/patientReport.service";
import { auditLog } from "@/services/audit/audit.service";
import { useAuthStore } from "@/store/auth.store";
import { Role } from "@/domain/enums/roles";
import { canManageSurgeryTeam, canSeeOrder } from "@/domain/permissions/permissions";

import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";
import { formatDateTime } from "@/utils/dates";

type Props = NativeStackScreenProps<RootStackParamList, "ProcedureOrderDetail">;

export function ProcedureOrderDetailScreen({ navigation, route }: Props) {
  const { id } = route.params;

  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const role = useAuthStore((s) => s.role)!;

  const [order, setOrder] = useState<any>(null);
  const [patient, setPatient] = useState<any>(null);
  const [team, setTeam] = useState<any[]>([]);
  const [employeesOpt, setEmployeesOpt] = useState<any[]>([]);
  const [empNameMap, setEmpNameMap] = useState<Map<string, string>>(new Map());

  const [assignEmpId, setAssignEmpId] = useState<string | null>(null);
  const [teamRole, setTeamRole] = useState("ASSISTANT");
  const [lead, setLead] = useState(false);

  const [doctorOfPatient, setDoctorOfPatient] = useState(false);
  const [isTeamMember, setIsTeamMember] = useState(false);
  const [doctorFlag, setDoctorFlag] = useState(false);

  async function load() {
    const o = await ProcedureOrdersRepo.getById(id);
    setOrder(o);
    if (!o) return;

    const p = await PatientsRepo.getById(o.patientId);
    setPatient(p);

    const t = await ProcedureTeamRepo.list(id);
    setTeam(t);
    setIsTeamMember(t.some((m) => m.employeeId === actorId));

    const isDoc = await PatientDoctorsRepo.isDoctorOfPatient(o.patientId, actorId);
    setDoctorOfPatient(isDoc);

    const actor = await EmployeesAdminRepo.getById(actorId);
    setDoctorFlag(!!actor?.canBuildTeam);

    const emps = await EmployeesRepo.list();
    setEmployeesOpt(emps.map((e) => ({ id: e.id, label: e.name, subtitle: `${e.role} | ${e.jobTitle}` })));
    setEmpNameMap(new Map(emps.map((e) => [e.id, e.name])));
  }

  useEffect(() => {
    const unsub = navigation.addListener("focus", load);
    load();
    return unsub;
  }, [navigation, id]);

  const leadDoctorId = useMemo(() => {
    const leadRow = team.find((m) => m.isLead === 1);
    return leadRow?.employeeId ?? order?.requestedByDoctorId;
  }, [team, order]);

  const isRoot = role === Role.ROOT_ADMIN;

  // (Se você tiver um role de coordenação no seu enum depois, pluga aqui)
  const isCoordinator = false;

  const canSee = useMemo(() => {
    return canSeeOrder({ isRoot, isTeamMember, isDoctorOfPatient: doctorOfPatient, role });
  }, [isRoot, isTeamMember, doctorOfPatient, role]);

  const canManageTeam = useMemo(() => {
    const isLeadDoctor = role === Role.DOCTOR && actorId === leadDoctorId;
    return canManageSurgeryTeam({
      role,
      isRoot,
      isDoctorLead: isLeadDoctor,
      doctorHasPermissionFlag: doctorFlag,
      isCoordinator,
    });
  }, [role, isRoot, actorId, leadDoctorId, doctorFlag, isCoordinator]);

  async function addMember() {
    if (!assignEmpId) return;
    if (!canManageTeam) return;

    await ProcedureTeamRepo.add(id, assignEmpId, teamRole, lead);

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "UPDATE",
      entity: "PROCEDURE_ORDER",
      entityId: id,
      meta: { teamAdd: true, employeeId: assignEmpId, teamRole, lead },
    });

    setAssignEmpId(null);
    setLead(false);
    await load();
  }

  async function clearTeam() {
    if (!canManageTeam) return;
    Alert.alert("Limpar equipe", "Remover toda a equipe desta ordem?", [
      { text: "Cancelar", style: "cancel" },
      { text: "OK", style: "destructive", onPress: async () => { await ProcedureTeamRepo.clear(id); await load(); } },
    ]);
  }

  async function exportPdf() {
    if (!order || !patient) return;

    const teamHtml = team.map((m) => {
      const nm = empNameMap.get(m.employeeId) ?? m.employeeId;
      return `<div>- ${nm} | ${m.teamRole} ${m.isLead ? "(RESPONSÁVEL)" : ""}</div>`;
    }).join("");

    const html = `
      <div class="block">
        <div><b>Paciente:</b> ${patient.name}</div>
        <div><b>Documento:</b> ${patient.documentId}</div>
        <div><b>Telefone:</b> ${patient.phone}</div>
      </div>
      <div class="block">
        <div><b>Ordem:</b> ${order.title}</div>
        <div><b>Status:</b> ${order.status} | <b>Prioridade:</b> ${order.priority}</div>
        <div><b>Descrição:</b> ${order.description ?? "-"}</div>
      </div>
      <div class="block">
        <div><b>Equipe:</b></div>
        ${teamHtml || "<div>- (sem equipe)</div>"}
      </div>
    `;

    await generateAndSharePdf({ title: "Relatório - Ordem/Equipe", html });

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "EXPORT",
      entity: "PROCEDURE_ORDER",
      entityId: id,
      meta: { pdf: true },
    });
  }

  async function declareDeath() {
    if (!patient) return;
    Alert.alert("Declaração de óbito", "Confirmar óbito deste paciente? Isso gera histórico.", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Confirmar",
        style: "destructive",
        onPress: async () => {
          const ev = await PatientEventsRepo.declareDeath(patient.id, actorId, "Óbito declarado no app.");
          await auditLog({
            actorEmployeeId: actorId,
            actorName,
            action: "UPDATE",
            entity: "PATIENT",
            entityId: patient.id,
            meta: { death: true, eventId: ev.id },
            after: ev,
          });
          Alert.alert("OK", "Óbito registrado no histórico.");
        },
      },
    ]);
  }

  if (!order) return <Screen><Text>Carregando...</Text></Screen>;

  if (!canSee) {
    return (
      <Screen>
        <Text style={{ fontWeight: "900" }}>Acesso restrito</Text>
        <Text style={{ color: "#666" }}>
          Somente Root, equipe selecionada, ou médico marcado do paciente pode visualizar esta ordem.
        </Text>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 18 }}>{order.title}</Text>
        <Text>Status: {order.status} | Prioridade: {order.priority}</Text>
        <Text style={{ color: "#666" }}>{order.description ?? "-"}</Text>

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900" }}>Equipe</Text>
        {team.map((m) => (
          <View key={m.id} style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>{empNameMap.get(m.employeeId) ?? m.employeeId}</Text>
            <Text>Função: {m.teamRole} {m.isLead ? "(RESPONSÁVEL)" : ""}</Text>
            <Text style={{ color: "#666" }}>Adicionado em: {formatDateTime(m.createdAt)}</Text>
          </View>
        ))}

        {canManageTeam ? (
          <View style={{ gap: 10 }}>
            <SelectList label="Adicionar membro" valueId={assignEmpId} onChange={setAssignEmpId} options={employeesOpt} />
            <Input label="Função (ex: LEAD_SURGEON/ASSISTANT/ANESTHETIST/NURSE/TECH/OTHER)" value={teamRole} onChangeText={setTeamRole} />
            <Button title={lead ? "✓ Marcar como responsável" : "Marcar como responsável"} variant={lead ? "primary" : "ghost"} onPress={() => setLead(!lead)} />
            <Button title="Adicionar na equipe" onPress={addMember} disabled={!assignEmpId} />
            <Button title="Limpar equipe" variant="danger" onPress={clearTeam} />
          </View>
        ) : (
          <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>Sem permissão para alterar equipe</Text>
            <Text style={{ color: "#666" }}>
              Root pode sempre. Médico só se Root liberar (canBuildTeam) e ele for o responsável.
            </Text>
          </View>
        )}

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Button title="Exportar PDF" onPress={exportPdf} />
        <Button title="Declarar óbito" variant="danger" onPress={declareDeath} />
      </ScrollView>
    </Screen>
  );
}
