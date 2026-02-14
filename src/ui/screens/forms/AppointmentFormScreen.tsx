import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";
import { AppointmentsRepo } from "@/data/repositories/appointments.repo";
import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "AppointmentForm">;

export function AppointmentFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [patientId, setPatientId] = useState<string | null>(null);
  const [doctorEmployeeId, setDoctorEmployeeId] = useState<string | null>(null);
  const [serviceTypeId, setServiceTypeId] = useState<string | null>(null);

  const [scheduledAt, setScheduledAt] = useState(String(Date.now()));
  const [durationMin, setDurationMin] = useState("30");
  const [status, setStatus] = useState("SCHEDULED");
  const [notes, setNotes] = useState("");

  const [patientsOpt, setPatientsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [doctorsOpt, setDoctorsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [servicesOpt, setServicesOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);

  const [hint, setHint] = useState("");

  useEffect(() => {
    (async () => {
      const patients = await PatientsRepo.list();
      setPatientsOpt(patients.map((p) => ({ id: p.id, label: p.name, subtitle: `Doc: ${p.documentId} | Tel: ${p.phone}` })));

      const doctors = await EmployeesRepo.listDoctors();
      setDoctorsOpt(doctors.map((d) => ({ id: d.id, label: d.name, subtitle: `${d.jobTitle} | ${d.sector}` })));

      const services = await ServicesRepo.list();
      setServicesOpt(services.map((s) => ({ id: s.id, label: s.name, subtitle: s.treatment })));

      if (editing) {
        const cur = await AppointmentsRepo.getById(id!);
        if (!cur) return;
        setPatientId(cur.patientId);
        setDoctorEmployeeId(cur.doctorEmployeeId);
        setServiceTypeId(cur.serviceTypeId);
        setScheduledAt(String(cur.scheduledAt));
        setDurationMin(String(cur.durationMin));
        setStatus(cur.status);
        setNotes(cur.notes ?? "");
      }
    })();
  }, [editing, id]);

  async function validateDoctorSkill() {
    if (!doctorEmployeeId || !serviceTypeId) return setHint("");
    const skills = await EmployeeSkillsRepo.listByEmployee(doctorEmployeeId);
    const ok = skills.some((x) => x.serviceTypeId === serviceTypeId);
    if (!ok) setHint("⚠️ Este médico não está vinculado a este serviço (cadastro de procedimentos).");
    else setHint("");
  }
  useEffect(() => { validateDoctorSkill(); }, [doctorEmployeeId, serviceTypeId]);

  const canSave = useMemo(() => !!patientId && !!doctorEmployeeId && !!serviceTypeId, [patientId, doctorEmployeeId, serviceTypeId]);

  async function save() {
    if (!canSave) return;

    const sa = Number(scheduledAt);
    const dm = Number(durationMin);

    if (!editing) {
      const created = await AppointmentsRepo.create({
        patientId: patientId!,
        doctorEmployeeId: doctorEmployeeId!,
        serviceTypeId: serviceTypeId!,
        scheduledAt: sa,
        durationMin: dm,
        status: "SCHEDULED",
        notes: notes || null,
        deletedAt: null,
      });

      // REGRA: ao agendar, marca o médico como médico do paciente (controle de acesso)
      await PatientDoctorsRepo.assign(patientId!, doctorEmployeeId!, actorId);

      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "APPOINTMENT", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await AppointmentsRepo.getById(id!);
    const next = await AppointmentsRepo.update(id!, {
      patientId: patientId!,
      doctorEmployeeId: doctorEmployeeId!,
      serviceTypeId: serviceTypeId!,
      scheduledAt: sa,
      durationMin: dm,
      status: status as any,
      notes: notes || null,
    });

    // ao editar, garante marcação também
    await PatientDoctorsRepo.assign(patientId!, doctorEmployeeId!, actorId);

    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "APPOINTMENT", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir agendamento (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await AppointmentsRepo.getById(id!);
          await AppointmentsRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "APPOINTMENT", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar agendamento" : "Novo agendamento"}</Text>
        {!!hint && <Text style={{ color: "#8b0000", fontWeight: "800" }}>{hint}</Text>}

        <SelectList label="Paciente" valueId={patientId} onChange={setPatientId} options={patientsOpt} placeholder="Selecione o paciente" />
        <SelectList label="Médico" valueId={doctorEmployeeId} onChange={setDoctorEmployeeId} options={doctorsOpt} placeholder="Selecione o médico" />
        <SelectList label="Serviço" valueId={serviceTypeId} onChange={setServiceTypeId} options={servicesOpt} placeholder="Selecione o serviço" />

        <Input label="Data/hora (timestamp ms)" value={scheduledAt} onChangeText={setScheduledAt} />
        <Input label="Duração (min)" value={durationMin} onChangeText={setDurationMin} />
        <Input label="Status (SCHEDULED/DONE/CANCELED)" value={status} onChangeText={setStatus} />
        <Input label="Observações" value={notes} onChangeText={setNotes} />

        <Button title="Salvar" onPress={save} disabled={!canSave} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
