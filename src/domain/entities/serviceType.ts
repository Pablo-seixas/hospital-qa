import { BaseEntity } from "./base";
export type ServiceType = BaseEntity & {
  name: string;
  treatment: string;
  priceCents: number;
};
