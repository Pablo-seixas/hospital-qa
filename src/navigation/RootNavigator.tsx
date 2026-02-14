import React from "react";
import { View, ActivityIndicator } from "react-native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { RootStackParamList } from "./types";
import { useAuthStore } from "@/state/authStore";

import { AuthScreen } from "@/ui/screens/AuthScreen";
import { MfaScreen } from "@/ui/screens/MfaScreen";
import { PatientRegisterScreen } from "@/ui/screens/PatientRegisterScreen";
import { ForgotPasswordScreen } from "@/ui/screens/ForgotPasswordScreen";

import { MainTabs } from "./MainTabs";
import { EmployeeFormScreen } from "@/ui/screens/forms/EmployeeFormScreen";
import { EmployeeDetailScreen } from "@/ui/screens/EmployeeDetailScreen";
import { PatientFormScreen } from "@/ui/screens/forms/PatientFormScreen";
import { ServiceFormScreen } from "@/ui/screens/forms/ServiceFormScreen";
import { AppointmentFormScreen } from "@/ui/screens/forms/AppointmentFormScreen";
import { PatientChartScreen } from "@/ui/screens/PatientChartScreen";

const Stack = createNativeStackNavigator<RootStackParamList>();

function Splash() {
  return (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <ActivityIndicator />
    </View>
  );
}

export function RootNavigator() {
  const employee = useAuthStore((s) => s.employee);
  const loading = useAuthStore((s) => s.loading);

  if (loading) return <Splash />;

  if (employee) {
    return (
      <Stack.Navigator>
        <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
        <Stack.Screen name="EmployeeDetail" component={EmployeeDetailScreen} options={{ title: "Funcionário" }} />
        <Stack.Screen name="EmployeeForm" component={EmployeeFormScreen} options={{ title: "Funcionário" }} />
        <Stack.Screen name="PatientForm" component={PatientFormScreen} options={{ title: "Paciente" }} />
        <Stack.Screen name="ServiceForm" component={ServiceFormScreen} options={{ title: "Serviço" }} />
        <Stack.Screen name="AppointmentForm" component={AppointmentFormScreen} options={{ title: "Agendamento" }} />
        <Stack.Screen name="PatientChart" component={PatientChartScreen} options={{ title: "Prontuário / Exames" }} />
      </Stack.Navigator>
    );
  }

  return (
    <Stack.Navigator>
      <Stack.Screen name="Auth" component={AuthScreen} options={{ title: "Login" }} />
      <Stack.Screen name="PatientRegister" component={PatientRegisterScreen} options={{ title: "Criar conta" }} />
      <Stack.Screen name="ForgotPassword" component={ForgotPasswordScreen} options={{ title: "Esqueci a senha" }} />
      <Stack.Screen name="Mfa" component={MfaScreen} options={{ title: "Duplo fator (demo)" }} />
      <Stack.Screen name="Main" component={MainTabs} options={{ headerShown: false }} />
    </Stack.Navigator>
  );
}
