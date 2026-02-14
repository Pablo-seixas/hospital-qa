import * as SQLite from "expo-sqlite";

let _db: SQLite.SQLiteDatabase | null = null;

export async function getDb() {
  if (_db) return _db;
  _db = await SQLite.openDatabaseAsync("hospital.db");
  return _db;
}

export async function execAsync(sql: string): Promise<void> {
  const db = await getDb();
  await db.execAsync(sql);
}

export async function runAsync(sql: string, args: any[] = []): Promise<void> {
  const db = await getDb();
  await db.runAsync(sql, args);
}

export async function getFirstAsync<T>(sql: string, args: any[] = []): Promise<T | null> {
  const db = await getDb();
  const row = await db.getFirstAsync<T>(sql, args);
  return row ?? null;
}

export async function getAllAsync<T>(sql: string, args: any[] = []): Promise<T[]> {
  const db = await getDb();
  const rows = await db.getAllAsync<T>(sql, args);
  return rows ?? [];
}
