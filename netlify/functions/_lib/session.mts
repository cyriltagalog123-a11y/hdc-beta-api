import { SignJWT, jwtVerify } from 'jose';
import { sessionSecret } from './env.mjs';

const ISSUER = 'hdc-beta-api';
const AUDIENCE = 'hdc-client';

export interface VerifiedSessionToken {
  userId: string;
  jti: string;
  expiresAt: Date;
}

export async function signSessionToken(userId: string, jti: string, expiresAt: Date): Promise<string> {
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setSubject(userId)
    .setJti(jti)
    .setIssuedAt()
    .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
    .sign(sessionSecret());
}

export async function verifySessionToken(token: string): Promise<VerifiedSessionToken | null> {
  try {
    const { payload } = await jwtVerify(token, sessionSecret(), {
      issuer: ISSUER,
      audience: AUDIENCE,
      algorithms: ['HS256'],
    });

    if (!payload.sub || !payload.jti || !payload.exp) return null;
    return {
      userId: payload.sub,
      jti: payload.jti,
      expiresAt: new Date(payload.exp * 1000),
    };
  } catch {
    return null;
  }
}
