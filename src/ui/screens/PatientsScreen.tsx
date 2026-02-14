import React, { useEffect, useState } from "react";
import { View, Text, Button, FlatList, Alert } from "react-native";
import { listPatients, createPatient, deletePatient, updatePatient, Patient } from "@/api/patientsApi";
import { PatientForm } from "./forms/PatientForm";

export function PatientsScreen() {
  const [patients, setPatients] = useState<Patient[]>([]);
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<Patient | null>(null);

  async function load() {
    const data = await listPatients();
    setPatients(data);
  }

  useEffect(() => {
    load();
  }, []);

  async function handleCreate(data: any) {
    await createPatient(data);
    setCreating(false);
    await load();
  }

  async function handleUpdate(data: any) {
    if (!editing) return;
    await updatePatient(editing.id, data);
    setEditing(null);
    await load();
  }

  async function handleDelete(id: string) {
    Alert.alert("Confirmar", "Deseja excluir?", [
      { text: "Cancelar" },
      {
        text: "Excluir",
        onPress: async () => {
          await deletePatient(id);
          await load();
        },
      },
    ]);
  }

  if (creating) {
    return <PatientForm onSubmit={handleCreate} />;
  }

  if (editing) {
    return <PatientForm initial={editing} onSubmit={handleUpdate} />;
  }

  return (
    <View style={{ flex:1, padding:16 }}>
      <Button title="Novo Paciente" onPress={() => setCreating(true)} />
      <FlatList
        data={patients}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={{ padding:10, borderWidth:1, marginTop:10 }}>
            <Text style={{ fontWeight:"bold" }}>{item.name}</Text>
            <Text>{item.documentType}: {item.documentId}</Text>
            <Text>{item.phone}</Text>
            <Text>{item.birthDate.slice(0,10)}</Text>

            <View style={{ flexDirection:"row", gap:10 }}>
              <Button title="Editar" onPress={() => setEditing(item)} />
              <Button title="Excluir" onPress={() => handleDelete(item.id)} />
            </View>
          </View>
        )}
      />
    </View>
  );
}
