// DEMO ONLY: não é seguro para produção.
// Para produção: bcrypt/argon2 no backend.
export function simpleHash(input: string): string {
  let h = 0;
  for (let i = 0; i < input.length; i++) h = (h * 31 + input.charCodeAt(i)) >>> 0;
  return `h_${h.toString(16)}`;
}
