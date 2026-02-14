import { BaseEntity } from "./base";
export type Bed = BaseEntity & {
  code: string;
  sector: string;
  status: "VACANT" | "OCCUPIED";
  patientId?: string | null;
  expectedReleaseAt?: number | null;
};
