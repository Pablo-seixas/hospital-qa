import { format } from "date-fns";
export function formatDateTime(ts: number): string {
  return format(new Date(ts), "dd/MM/yyyy HH:mm");
}
