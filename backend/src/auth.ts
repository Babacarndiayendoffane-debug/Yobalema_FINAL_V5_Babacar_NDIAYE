import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { Request, Response, NextFunction } from 'express';
import { config } from './config';

export type AuthUser = { id: string; role: 'PASSENGER' | 'DRIVER' | 'ADMIN' };

declare global { namespace Express { interface Request { user?: AuthUser } } }

export async function hashPassword(password: string) { return bcrypt.hash(password, 12); }
export async function verifyPassword(password: string, hash: string) { return bcrypt.compare(password, hash); }
export function signToken(user: AuthUser) { return jwt.sign(user, config.jwtSecret, { expiresIn: '7d' }); }
export function verifyToken(token: string) { return jwt.verify(token, config.jwtSecret) as AuthUser; }

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) return res.status(401).json({ error: 'Authentification requise' });
  try {
    req.user = jwt.verify(header.slice(7), config.jwtSecret) as AuthUser;
    next();
  } catch { return res.status(401).json({ error: 'Token invalide ou expiré' }); }
}

export function requireRole(...roles: AuthUser['role'][]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) return res.status(403).json({ error: 'Accès interdit' });
    next();
  };
}
