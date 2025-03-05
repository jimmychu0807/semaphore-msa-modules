export function generateRandomHex(byteLen: number = 32) {
  const array = new Uint8Array(byteLen);
  crypto.getRandomValues(array);
  return Array.from(array, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
