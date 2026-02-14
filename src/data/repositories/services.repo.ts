import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { ServiceType } from "@/domain/entities/serviceType";
import { id } from "@/utils/id";

export const ServicesRepo = {
  list(): Promise<ServiceType[]> {
    return getAllAsync<ServiceType>("SELECT * FROM service_types WHERE isDeleted=0 ORDER BY name");
  },
  getById(sid: string): Promise<ServiceType | null> {
    return getFirstAsync<ServiceType>("SELECT * FROM service_types WHERE id=? AND isDeleted=0", [sid]);
  },
  async create(s: Omit<ServiceType, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<ServiceType> {
    const now = Date.now();
    const row: ServiceType = { ...s, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO service_types (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        name, treatment, priceCents
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?)`,
      [row.id, row.createdAt, row.updatedAt, row.name, row.treatment, row.priceCents]
    );
    return row;
  },
  async update(sid: string, patch: Partial<ServiceType>): Promise<ServiceType | null> {
    const cur = await this.getById(sid);
    if (!cur) return null;
    const next: ServiceType = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE service_types SET updatedAt=?, name=?, treatment=?, priceCents=? WHERE id=?`,
      [next.updatedAt, next.name, next.treatment, next.priceCents, sid]
    );
    return next;
  },
  softDelete(sid: string) {
    const now = Date.now();
    return runAsync("UPDATE service_types SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, sid]);
  },
};
