import { http } from "./http";

export type Patient = {
  id: string;
  name: string;
  documentType: "CPF" | "RG" | "CNH";
  documentId: string;
  phone: string;
  birthDate: string;
  email?: string | null;
  deletedAt?: string | null;
};

export async function listPatients() {
  return http<Patient[]>("/patients", { method: "GET" });
}

export async function createPatient(data: {
  name: string;
  documentType: "CPF" | "RG" | "CNH";
  documentId: string;
  phone: string;
  birthDate: string;
  email?: string;
}) {
  return http<Patient>("/patients", {
    method: "POST",
    body: data,
  });
}

export async function updatePatient(id: string, data: Partial<Patient>) {
  return http<Patient>(`/patients/${id}`, {
    method: "PUT",
    body: data,
  });
}

export async function deletePatient(id: string) {
  return http<{ ok: boolean }>(`/patients/${id}`, {
    method: "DELETE",
  });
}
