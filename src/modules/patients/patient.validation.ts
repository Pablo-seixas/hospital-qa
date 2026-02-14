import { z } from "zod";

const CURRENT_YEAR = 2026; // regra fixa conforme solicitado
const MIN_YEAR = CURRENT_YEAR - 126;

export const DocumentTypeEnum = z.enum(["CPF", "RG", "CNH"]);

function onlyDigits(s: string) {
  return s.replace(/\D+/g, "");
}

export function validateDocument(documentType: "CPF"|"RG"|"CNH", documentId: string) {
  const d = onlyDigits(documentId);

  if (documentType === "CPF") {
    if (d.length !== 11) return { ok: false as const, normalized: d, error: "CPF deve ter 11 dígitos" };
  }

  if (documentType === "CNH") {
    if (d.length !== 11) return { ok: false as const, normalized: d, error: "CNH deve ter 11 dígitos" };
  }

  if (documentType === "RG") {
    if (d.length < 5 || d.length > 14) return { ok: false as const, normalized: d, error: "RG deve ter 5 a 14 dígitos" };
  }

  return { ok: true as const, normalized: d };
}

export function validateBirthDate(birthDateISO: string) {
  const dt = new Date(birthDateISO);
  if (Number.isNaN(dt.getTime())) return { ok: false as const, error: "Data de nascimento inválida" };

  const year = dt.getFullYear();
  if (year > CURRENT_YEAR) return { ok: false as const, error: `Ano de nascimento não pode ser maior que ${CURRENT_YEAR}` };
  if (year < MIN_YEAR) return { ok: false as const, error: `Ano de nascimento deve ser >= ${MIN_YEAR} (máx 126 anos)` };

  return { ok: true as const, date: dt };
}

export function normalizePhone(phone: string) {
  const d = onlyDigits(phone);
  if (d.length < 10 || d.length > 15) return { ok: false as const, error: "Telefone deve ter 10 a 15 dígitos" };
  return { ok: true as const, normalized: d };
}

export const PatientCreateSchema = z.object({
  name: z.string().min(2),
  documentType: DocumentTypeEnum,
  documentId: z.string().min(5),
  phone: z.string().min(10),
  birthDate: z.string(), // ISO (YYYY-MM-DD)
  email: z.string().email().optional(),
});

export const PatientUpdateSchema = z.object({
  name: z.string().min(2).optional(),
  documentType: DocumentTypeEnum.optional(),
  documentId: z.string().min(5).optional(),
  phone: z.string().min(10).optional(),
  birthDate: z.string().optional(),
  email: z.string().email().optional(),
});
