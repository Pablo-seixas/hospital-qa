export type BaseEntity = {
  id: string;
  createdAt: number;
  updatedAt: number;
  isDeleted: 0 | 1;
  deletedAt?: number | null;
};
