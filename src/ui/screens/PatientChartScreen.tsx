import React, { useEffect, useMemo, useState } from "react";
import { Alert, FlatList, Linking, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { SelectList } from "@/ui/components/SelectList";

import { PatientsRepo } from "@/data/repositories/patients.repo";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { MedicalRecordsRepo } from "@/data/repositories/medicalRecords.repo";
import { ExamsRepo, Exam } from "@/data/repositories/exams.repo";
import { PatientFilesRepo, PatientFile } from "@/data/repositories/patientFiles.repo";
import { PatientDoctorsRepo } from "@/data/repositories/patientDoctors.repo";

import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { formatDateTime } from "@/utils/dates";
import { Role } from "@/domain/enums/roles";

import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";

import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "PatientChart">;

export function PatientChartScreen({ route }: Props) {
  const { patientId } = route.params;

  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;
  const role = useAuthStore((s) => s.role)!;

  const isRoot = role === Role.ROOT_ADMIN;

  const [patientName, setPatientName] = useState("");

  const [summary, setSummary] = useState("");
  const [diagnosis, setDiagnosis] = useState("");
  const [notes, setNotes] = useState("");

  const [examName, setExamName] = useState("");
  const [examScheduledAt, setExamScheduledAt] = useState("");
  const [exams, setExams] = useState<Exam[]>([]);

  const [files, setFiles] = useState<PatientFile[]>([]);
  const [assigned, setAssigned] = useState<any[]>([]);
  const [doctorsOpt, setDoctorsOpt] = useState<{ id: string; label: string; subtitle?: string }[]>([]);
  const [assignDoctorId, setAssignDoctorId] = useState<string | null>(null);

  const [doctorAccess, setDoctorAccess] = useState(false);

  const canSeeAttachments = useMemo(() => {
    // regra do usuário:
    // - ROOT_ADMIN vê tudo
    // - DOCTOR só vê se estiver marcado no paciente
    // - enfermagem/técnico/outros: não vê
    if (isRoot) return true;
    if (role === Role.DOCTOR) return doctorAccess;
    return false;
  }, [isRoot, role, doctorAccess]);

  const canDeleteAttachments = canSeeAttachments; // você pediu: root e médico podem excluir

  async function load() {
    const p = await PatientsRepo.getById(patientId);
    setPatientName(p?.name ?? "Paciente");

    // checa acesso do médico
    const isDoctorOf = await PatientDoctorsRepo.isDoctorOfPatient(patientId, actorId);
    setDoctorAccess(isDoctorOf);

    const rec = await MedicalRecordsRepo.getByPatient(patientId);
    setSummary(rec?.summary ?? "");
    setDiagnosis(rec?.diagnosis ?? "");
    setNotes(rec?.notes ?? "");

    setExams(await ExamsRepo.listByPatient(patientId));

    // anexos só carrega se permitido
    if (isRoot || (role === Role.DOCTOR && isDoctorOf)) {
      setFiles(await PatientFilesRepo.listByPatient(patientId));
    } else {
      setFiles([]);
    }

    const ass = await PatientDoctorsRepo.listByPatient(patientId);
    setAssigned(ass);

    // lista de médicos pra admin marcar
    const doctors = await EmployeesRepo.listDoctors();
    setDoctorsOpt(doctors.map((d) => ({ id: d.id, label: d.name, subtitle: `${d.jobTitle} | ${d.sector}` })));
  }

  useEffect(() => { load(); }, [patientId]);

  async function saveRecord() {
    const before = await MedicalRecordsRepo.getByPatient(patientId);
    const after = await MedicalRecordsRepo.upsert(patientId, {
      summary: summary || null,
      diagnosis: diagnosis || null,
      notes: notes || null,
    });

    await auditLog({
      actorEmployeeId: actorId, actorName,
      action: before ? "UPDATE" : "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { record: true },
      before,
      after,
    });

    await load();
  }

  async function addExam() {
    if (!examName.trim()) return;
    const created = await ExamsRepo.create({
      patientId,
      requestedByEmployeeId: actorId,
      appointmentId: null,
      name: examName.trim(),
      status: "PLANNED",
      scheduledAt: examScheduledAt ? Number(examScheduledAt) : null,
      result: null,
      deletedAt: null,
    });

    await auditLog({
      actorEmployeeId: actorId, actorName,
      action: "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { examId: created.id, examName: created.name },
      after: created,
    });

    setExamName("");
    setExamScheduledAt("");
    await load();
  }

  async function markDone(examId: string) {
    Alert.alert("Finalizar exame", "Marcar como DONE e salvar resultado?", [
      { text: "Cancelar", style: "cancel" },
      { text: "OK", onPress: async () => { await ExamsRepo.markDone(examId, "Resultado preenchido (editar depois)"); await load(); } },
    ]);
  }

  async function assignDoctor() {
    if (!assignDoctorId) return;
    await PatientDoctorsRepo.assign(patientId, assignDoctorId, actorId);
    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "UPDATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { assignedDoctorId: assignDoctorId },
    });
    setAssignDoctorId(null);
    await load();
  }

  async function unassign(rowId: string) {
    Alert.alert("Remover médico", "Remover marcação deste médico do paciente?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Remover",
        style: "destructive",
        onPress: async () => {
          await PatientDoctorsRepo.softUnassignById(rowId);
          await load();
        },
      },
    ]);
  }

  async function pickAndAttachFile() {
    if (!canSeeAttachments) return;

    const res = await DocumentPicker.getDocumentAsync({
      type: "*/*",
      multiple: false,
      copyToCacheDirectory: true,
    });
    if (res.canceled) return;

    const file = res.assets?.[0];
    if (!file?.uri) return;

    const folder = `${FileSystem.documentDirectory}patient_files/${patientId}/`;
    await FileSystem.makeDirectoryAsync(folder, { intermediates: true });

    const safeName = (file.name ?? `arquivo_${Date.now()}`).replace(/[^\w.\-]/g, "_");
    const dest = `${folder}${Date.now()}_${safeName}`;

    await FileSystem.copyAsync({ from: file.uri, to: dest });

    const created = await PatientFilesRepo.create({
      patientId,
      name: safeName,
      mimeType: file.mimeType ?? null,
      size: file.size ?? null,
      localUri: dest,
      deletedAt: null,
    });

    await auditLog({
      actorEmployeeId: actorId,
      actorName,
      action: "CREATE",
      entity: "PATIENT",
      entityId: patientId,
      meta: { attachment: true, fileId: created.id, name: created.name, mimeType: created.mimeType },
      after: created,
    });

    await load();
  }

  async function openFile(item: PatientFile) {
    if (!canSeeAttachments) return;

    try {
      // Em Android: converte file:// para content:// (necessário para abrir)
      const contentUri = await FileSystem.getContentUriAsync(item.localUri);
      await Linking.openURL(contentUri);
    } catch {
      // fallback
      await Linking.openURL(item.localUri);
    }
  }

  async function deleteFile(fileId: string) {
    if (!canDeleteAttachments) return;
    Alert.alert("Excluir anexo", "Excluir este anexo (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          await PatientFilesRepo.softDelete(fileId);
          await load();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>Prontuário: {patientName}</Text>

        {/* Admin pode marcar médico do paciente */}
        {isRoot && (
          <View style={{ gap: 10 }}>
            <Text style={{ fontWeight: "900" }}>Médico(s) marcado(s) do paciente</Text>

            <SelectList
              label="Marcar médico"
              valueId={assignDoctorId}
              onChange={setAssignDoctorId}
              options={doctorsOpt}
              placeholder="Selecione um médico"
            />
            <Button title="Marcar médico do paciente" onPress={assignDoctor} disabled={!assignDoctorId} />

            {assigned.map((a) => (
              <View key={a.id} style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
                <Text style={{ fontWeight: "900" }}>DoctorId: {a.doctorEmployeeId}</Text>
                <Text style={{ color: "#666" }}>Marcado em: {formatDateTime(a.createdAt)}</Text>
                <Button title="Remover marcação" variant="danger" onPress={() => unassign(a.id)} />
              </View>
            ))}

            <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />
          </View>
        )}

        <Text style={{ fontWeight: "900" }}>Resumo</Text>
        <Input label="Resumo" value={summary} onChangeText={setSummary} />

        <Text style={{ fontWeight: "900" }}>Diagnóstico</Text>
        <Input label="Diagnóstico" value={diagnosis} onChangeText={setDiagnosis} />

        <Text style={{ fontWeight: "900" }}>Observações</Text>
        <Input label="Observações" value={notes} onChangeText={setNotes} />

        <Button title="Salvar prontuário" onPress={saveRecord} />

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900", fontSize: 16 }}>Exames</Text>
        <Input label="Novo exame (nome)" value={examName} onChangeText={setExamName} />
        <Input label="Data do exame (timestamp ms) opcional" value={examScheduledAt} onChangeText={setExamScheduledAt} />
        <Button title="Adicionar exame (PLANNED)" onPress={addExam} />

        <FlatList
          data={exams}
          keyExtractor={(i) => i.id}
          scrollEnabled={false}
          contentContainerStyle={{ gap: 10 }}
          renderItem={({ item }) => (
            <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
              <Text style={{ fontWeight: "900" }}>{item.name}</Text>
              <Text>Status: {item.status}</Text>
              <Text>Agendado: {item.scheduledAt ? formatDateTime(item.scheduledAt) : "—"}</Text>
              {!!item.result && <Text>Resultado: {item.result}</Text>}
              {item.status !== "DONE" && <Button title="Marcar DONE" variant="ghost" onPress={() => markDone(item.id)} />}
            </View>
          )}
        />

        <View style={{ height: 1, backgroundColor: "#eee", marginVertical: 8 }} />

        <Text style={{ fontWeight: "900", fontSize: 16 }}>Anexos do paciente (PDF/Imagem)</Text>

        {!canSeeAttachments ? (
          <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
            <Text style={{ fontWeight: "900" }}>Acesso restrito</Text>
            <Text style={{ color: "#666" }}>
              Somente Root Admin e o médico marcado do paciente podem visualizar e excluir anexos.
            </Text>
          </View>
        ) : (
          <>
            <Button title="Adicionar anexo" onPress={pickAndAttachFile} />

            <FlatList
              data={files}
              keyExtractor={(i) => i.id}
              scrollEnabled={false}
              contentContainerStyle={{ gap: 10 }}
              renderItem={({ item }) => (
                <View style={{ borderWidth: 1, borderColor: "#eee", borderRadius: 14, padding: 12, backgroundColor: "#fff" }}>
                  <Text style={{ fontWeight: "900" }}>{item.name}</Text>
                  <Text>Tipo: {item.mimeType ?? "—"} | Tamanho: {item.size ?? "—"}</Text>
                  <Text style={{ color: "#666" }} numberOfLines={1}>Local: {item.localUri}</Text>

                  <View style={{ flexDirection: "row", gap: 10 }}>
                    <Button title="Abrir" variant="ghost" onPress={() => openFile(item)} />
                    {canDeleteAttachments && <Button title="Excluir" variant="danger" onPress={() => deleteFile(item.id)} />}
                  </View>
                </View>
              )}
            />
          </>
        )}
      </ScrollView>
    </Screen>
  );
}
