import { getAllAsync, getFirstAsync, runAsync } from "@/data/db/sqlite";
import { Bed } from "@/domain/entities/bed";
import { id } from "@/utils/id";

export const BedsRepo = {
  list(): Promise<Bed[]> {
    return getAllAsync<Bed>("SELECT * FROM beds WHERE isDeleted=0 ORDER BY sector, code");
  },
  getById(bid: string): Promise<Bed | null> {
    return getFirstAsync<Bed>("SELECT * FROM beds WHERE id=? AND isDeleted=0", [bid]);
  },
  async create(b: Omit<Bed, "id" | "createdAt" | "updatedAt" | "isDeleted">): Promise<Bed> {
    const now = Date.now();
    const row: Bed = { ...b, id: id(), createdAt: now, updatedAt: now, isDeleted: 0 };
    await runAsync(
      `INSERT INTO beds (
        id, createdAt, updatedAt, isDeleted, deletedAt,
        code, sector, status, patientId, expectedReleaseAt
      ) VALUES (?, ?, ?, 0, NULL, ?, ?, ?, ?, ?)`,
      [row.id, row.createdAt, row.updatedAt, row.code, row.sector, row.status, row.patientId ?? null, row.expectedReleaseAt ?? null]
    );
    return row;
  },
  async update(bid: string, patch: Partial<Bed>): Promise<Bed | null> {
    const cur = await this.getById(bid);
    if (!cur) return null;
    const next: Bed = { ...cur, ...patch, updatedAt: Date.now() };
    await runAsync(
      `UPDATE beds SET updatedAt=?, code=?, sector=?, status=?, patientId=?, expectedReleaseAt=? WHERE id=?`,
      [next.updatedAt, next.code, next.sector, next.status, next.patientId ?? null, next.expectedReleaseAt ?? null, bid]
    );
    return next;
  },
  softDelete(bid: string) {
    const now = Date.now();
    return runAsync("UPDATE beds SET isDeleted=1, deletedAt=?, updatedAt=? WHERE id=?", [now, now, bid]);
  },
};
