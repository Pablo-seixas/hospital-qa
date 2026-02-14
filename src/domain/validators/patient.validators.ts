export type DocumentType = "CPF" | "RG" | "CNH";

export function normalizeDigits(s: string) {
  return (s ?? "").replace(/\D/g, "");
}

export function validateCPF(raw: string): boolean {
  const cpf = normalizeDigits(raw);
  if (cpf.length !== 11) return false;
  if (/^(\d)\1+$/.test(cpf)) return false;

  // checksum
  let sum = 0;
  for (let i = 0; i < 9; i++) sum += Number(cpf[i]) * (10 - i);
  let d1 = (sum * 10) % 11;
  if (d1 === 10) d1 = 0;
  if (d1 !== Number(cpf[9])) return false;

  sum = 0;
  for (let i = 0; i < 10; i++) sum += Number(cpf[i]) * (11 - i);
  let d2 = (sum * 10) % 11;
  if (d2 === 10) d2 = 0;
  return d2 === Number(cpf[10]);
}

export function validateRG(raw: string): boolean {
  // RG varia por estado; regra mínima: 7 a 12 caracteres/dígitos
  const v = raw.trim();
  const digits = normalizeDigits(v);
  return digits.length >= 7 && digits.length <= 12;
}

export function validateCNH(raw: string): boolean {
  const d = normalizeDigits(raw);
  return d.length === 11;
}

export function validateDocument(docType: DocumentType, docValue: string): boolean {
  if (!docValue.trim()) return false;
  if (docType === "CPF") return validateCPF(docValue);
  if (docType === "RG") return validateRG(docValue);
  return validateCNH(docValue);
}

export function validatePhone(raw: string): boolean {
  const d = normalizeDigits(raw);
  // BR: 10 ou 11 dígitos (DDD + número)
  return d.length === 10 || d.length === 11;
}

export function validateBirthDate(birthDateYYYYMMDD: string, nowYear: number): { ok: boolean; reason?: string } {
  const v = birthDateYYYYMMDD.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) return { ok: false, reason: "Formato deve ser YYYY-MM-DD" };

  const [yS, mS, dS] = v.split("-");
  const y = Number(yS), m = Number(mS), d = Number(dS);
  if (y > nowYear) return { ok: false, reason: `Ano máximo é ${nowYear}` };
  if (y < nowYear - 126) return { ok: false, reason: `Ano mínimo é ${nowYear - 126}` };
  if (m < 1 || m > 12) return { ok: false, reason: "Mês inválido" };
  if (d < 1 || d > 31) return { ok: false, reason: "Dia inválido" };

  return { ok: true };
}
