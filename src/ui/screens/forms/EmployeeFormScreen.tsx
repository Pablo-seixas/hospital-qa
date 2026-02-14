import React, { useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, Text, View } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { ServicesRepo } from "@/data/repositories/services.repo";
import { EmployeeSkillsRepo } from "@/data/repositories/employeeSkills.repo";
import { ServiceType } from "@/domain/entities/serviceType";
import { simpleHash } from "@/utils/hash";
import { useAuthStore } from "@/store/auth.store";
import { auditLog } from "@/services/audit/audit.service";
import { Role } from "@/domain/enums/roles";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "EmployeeForm">;

export function EmployeeFormScreen({ navigation, route }: Props) {
  const actorId = useAuthStore((s) => s.employeeId)!;
  const actorName = useAuthStore((s) => s.employeeName)!;

  const id = route.params?.id;
  const editing = !!id;

  const [loaded, setLoaded] = useState(false);
  const [services, setServices] = useState<ServiceType[]>([]);
  const [selectedServiceIds, setSelectedServiceIds] = useState<string[]>([]);

  const [employeeNumber, setEmployeeNumber] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [sector, setSector] = useState("");
  const [roleStr, setRoleStr] = useState<Role>(Role.EMPLOYEE);
  const [password, setPassword] = useState("");

  useEffect(() => {
    (async () => {
      const s = await ServicesRepo.list();
      setServices(s);

      if (editing) {
        const cur = await EmployeesRepo.getById(id!);
        if (cur) {
          setEmployeeNumber(cur.employeeNumber);
          setName(cur.name);
          setPhone(cur.phone);
          setEmail(cur.email);
          setJobTitle(cur.jobTitle);
          setSector(cur.sector);
          setRoleStr(cur.role);
        }

        const skills = await EmployeeSkillsRepo.listByEmployee(id!);
        setSelectedServiceIds(skills.map((x) => x.serviceTypeId));
      }
      setLoaded(true);
    })();
  }, [editing, id]);

  const canHaveSkills = roleStr === Role.DOCTOR || roleStr === Role.NURSE;

  const selectedLabels = useMemo(() => {
    const map = new Map(services.map((x) => [x.id, x.name]));
    return selectedServiceIds.map((sid) => map.get(sid) ?? sid).join(", ");
  }, [selectedServiceIds, services]);

  function toggleService(sid: string) {
    setSelectedServiceIds((prev) => (prev.includes(sid) ? prev.filter((x) => x !== sid) : [...prev, sid]));
  }

  async function save() {
    if (!loaded) return;

    if (!editing) {
      const created = await EmployeesRepo.create({
        employeeNumber,
        name,
        phone,
        email,
        role: roleStr,
        jobTitle,
        sector,
        passwordHash: simpleHash(password || "1234"),
        mfaEnabled: 0,
        mfaPhoneVerified: 0,
        mfaEmailVerified: 0,
        mfaImageToken: null,
        deletedAt: null,
      });

      if (canHaveSkills) {
        await EmployeeSkillsRepo.setSkills(created.id, selectedServiceIds);
      }

      await auditLog({ actorEmployeeId: actorId, actorName, action: "CREATE", entity: "EMPLOYEE", entityId: created.id, after: created });
      navigation.goBack();
      return;
    }

    const before = await EmployeesRepo.getById(id!);
    const next = await EmployeesRepo.update(id!, {
      employeeNumber, name, phone, email, role: roleStr, jobTitle, sector,
      ...(password ? { passwordHash: simpleHash(password) } : {}),
    });

    if (canHaveSkills) {
      await EmployeeSkillsRepo.setSkills(id!, selectedServiceIds);
    } else {
      // se não for médico/enfermagem, zera skills
      await EmployeeSkillsRepo.setSkills(id!, []);
    }

    await auditLog({ actorEmployeeId: actorId, actorName, action: "UPDATE", entity: "EMPLOYEE", entityId: id!, before, after: next });
    navigation.goBack();
  }

  async function del() {
    if (!editing) return;
    Alert.alert("Excluir", "Excluir funcionário (soft delete)?", [
      { text: "Cancelar", style: "cancel" },
      {
        text: "Excluir",
        style: "destructive",
        onPress: async () => {
          const before = await EmployeesRepo.getById(id!);
          await EmployeesRepo.softDelete(id!);
          await auditLog({ actorEmployeeId: actorId, actorName, action: "DELETE", entity: "EMPLOYEE", entityId: id!, before });
          navigation.goBack();
        },
      },
    ]);
  }

  return (
    <Screen>
      <ScrollView contentContainerStyle={{ gap: 12, paddingBottom: 40 }}>
        <Text style={{ fontWeight: "900", fontSize: 16 }}>{editing ? "Editar funcionário" : "Novo funcionário"}</Text>

        <Input label="Número do funcionário" value={employeeNumber} onChangeText={setEmployeeNumber} />
        <Input label="Nome" value={name} onChangeText={setName} />
        <Input label="Telefone" value={phone} onChangeText={setPhone} />
        <Input label="Email" value={email} onChangeText={setEmail} />
        <Input label="Cargo (jobTitle)" value={jobTitle} onChangeText={setJobTitle} />
        <Input label="Setor" value={sector} onChangeText={setSector} />
        <Input label="Role (DOCTOR/NURSE/RECEPTION/...)" value={roleStr} onChangeText={(t) => setRoleStr((t as Role) ?? Role.EMPLOYEE)} />
        <Input label="Senha (opcional)" value={password} onChangeText={setPassword} secureTextEntry />

        {canHaveSkills && (
          <View style={{ gap: 8 }}>
            <Text style={{ fontWeight: "900" }}>O que este funcionário pode realizar (serviços)</Text>
            <Text style={{ color: "#666" }}>{selectedLabels || "Nenhum selecionado"}</Text>
            {services.map((s) => (
              <Button
                key={s.id}
                title={`${selectedServiceIds.includes(s.id) ? "✓ " : ""}${s.name}`}
                variant={selectedServiceIds.includes(s.id) ? "primary" : "ghost"}
                onPress={() => toggleService(s.id)}
              />
            ))}
          </View>
        )}

        <Button title="Salvar" onPress={save} />
        {editing && <Button title="Excluir" variant="danger" onPress={del} />}
      </ScrollView>
    </Screen>
  );
}
