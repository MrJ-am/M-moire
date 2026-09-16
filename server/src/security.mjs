import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { digest } from './database.mjs';
const scrypt = promisify(scryptCallback);
export const token = () => randomBytes(32).toString('hex');
export function sameSecret(left, right) {
  return typeof left === 'string' && typeof right === 'string' && timingSafeEqual(Buffer.from(digest(left), 'hex'), Buffer.from(digest(right), 'hex'));
}
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = await scrypt(password, salt, 64, { N: 131072, r: 8, p: 1, maxmem: 256 * 1024 * 1024 });
  return `scrypt:${salt}:${hash.toString('hex')}`;
}
export async function checkPassword(password, stored) {
  const [scheme, salt, expected] = stored.split(':');
  if (scheme !== 'scrypt' || !salt || !expected) return false;
  const hash = await scrypt(password, salt, 64, { N: 131072, r: 8, p: 1, maxmem: 256 * 1024 * 1024 });
  const bytes = Buffer.from(expected, 'hex');
  return bytes.length === hash.length && timingSafeEqual(bytes, hash);
}
export function cookie(req, name) {
  return (req.headers.cookie || '').split(';').map(s => s.trim()).find(s => s.startsWith(`${name}=`))?.slice(name.length + 1);
}
