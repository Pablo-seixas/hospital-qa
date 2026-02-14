export function centsToBRL(cents: number): string {
  const v = (cents / 100).toFixed(2).replace(".", ",");
  return `R$ ${v}`;
}
