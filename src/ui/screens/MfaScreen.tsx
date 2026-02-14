import React, { useState } from "react";
import { Text } from "react-native";
import { Screen } from "@/ui/components/Screen";
import { Input } from "@/ui/components/Input";
import { Button } from "@/ui/components/Button";
import { verifyMfa } from "@/services/auth/auth.service";
import { useAuthStore } from "@/store/auth.store";
import { EmployeesRepo } from "@/data/repositories/employees.repo";
import { NativeStackScreenProps } from "@react-navigation/native-stack";
import { RootStackParamList } from "@/navigation/types";

type Props = NativeStackScreenProps<RootStackParamList, "Mfa">;

export function MfaScreen({ navigation }: Props) {
  const setSession = useAuthStore((s) => s.setSession);

  const [phoneCode, setPhoneCode] = useState("111111");
  const [emailCode, setEmailCode] = useState("222222");
  const [imageToken, setImageToken] = useState("IMG");
  const [error, setError] = useState<string | null>(null);

  async function onVerify() {
    setError(null);
    const res = await verifyMfa({ phoneCode, emailCode, imageToken });
    if (!res.ok) return setError(res.error);
    const e = await EmployeesRepo.getById(res.employeeId);
    setSession(res.employeeId, e?.role ?? null, e?.name ?? null);
    navigation.replace("Main");
  }

  return (
    <Screen>
      <Text style={{ fontWeight: "900", fontSize: 18 }}>MFA (DEMO)</Text>
      <Text>Telefone: 111111 | Email: 222222 | Imagem: IMG</Text>
      {!!error && <Text style={{ color: "red" }}>{error}</Text>}
      <Input label="Código do telefone" value={phoneCode} onChangeText={setPhoneCode} />
      <Input label="Código do email" value={emailCode} onChangeText={setEmailCode} />
      <Input label="Token da imagem" value={imageToken} onChangeText={setImageToken} />
      <Button title="Verificar" onPress={onVerify} />
    </Screen>
  );
}
