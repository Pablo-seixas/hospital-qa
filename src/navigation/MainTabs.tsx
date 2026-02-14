import React from "react";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";

import { DashboardScreen } from "@/ui/screens/DashboardScreen";
import { EmployeesScreen } from "@/ui/screens/EmployeesScreen";
import { PatientsScreen } from "@/ui/screens/PatientsScreen";
import { AppointmentsScreen } from "@/ui/screens/AppointmentsScreen";
import { ServicesScreen } from "@/ui/screens/ServicesScreen";
import { AuditScreen } from "@/ui/screens/AuditScreen";

type TabParamList = {
  Dashboard: undefined;
  Employees: undefined;
  Patients: undefined;
  Appointments: undefined;
  Services: undefined;
  Audit: undefined;
};

const Tab = createBottomTabNavigator<TabParamList>();

export function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: true,
        tabBarShowLabel: true,
        tabBarLabelStyle: { fontSize: 12, marginBottom: 4 },
        tabBarStyle: { height: 62, paddingTop: 6 },
        tabBarActiveTintColor: "#111",
        tabBarInactiveTintColor: "#666",
      }}
    >
      <Tab.Screen name="Dashboard" component={DashboardScreen} options={{ title: "Início", tabBarLabel: "Início" }} />
      <Tab.Screen name="Employees" component={EmployeesScreen} options={{ title: "Funcionários", tabBarLabel: "Funcionários" }} />
      <Tab.Screen name="Patients" component={PatientsScreen} options={{ title: "Pacientes", tabBarLabel: "Pacientes" }} />
      <Tab.Screen name="Appointments" component={AppointmentsScreen} options={{ title: "Agenda", tabBarLabel: "Agenda" }} />
      <Tab.Screen name="Services" component={ServicesScreen} options={{ title: "Serviços", tabBarLabel: "Serviços" }} />
      <Tab.Screen name="Audit" component={AuditScreen} options={{ title: "Histórico", tabBarLabel: "Histórico" }} />
    </Tab.Navigator>
  );
}
