import { BaseEntity } from "./base";
import { Role } from "@/domain/enums/roles";

export type Employee = BaseEntity & {
  employeeNumber: string;
  name: string;
  phone: string;
  email: string;

  role: Role;
  jobTitle: string;
  sector: string;

  passwordHash: string;

  mfaEnabled: 0 | 1;
  mfaPhoneVerified: 0 | 1;
  mfaEmailVerified: 0 | 1;
  mfaImageToken?: string | null;
};
