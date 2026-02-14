import { BaseEntity } from "./base";
export type Appointment = BaseEntity & {
  patientId: string;
  doctorEmployeeId: string;
  serviceTypeId: string;
  scheduledAt: number;
  durationMin: number;
  status: "SCHEDULED" | "DONE" | "CANCELED";
  notes?: string | null;
};
