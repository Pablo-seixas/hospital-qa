import { BaseEntity } from "./base";
export type Patient = BaseEntity & {
  name: string;
  documentId: string;
  phone: string;
  email?: string | null;
  birthDate?: string | null;
  notes?: string | null;
};
