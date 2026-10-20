
import {
  SignJWT,
  jwtVerify,
} from "npm:jose@5";

const jwtSecret = Deno.env.get("APP_JWT_SECRET");

if (!jwtSecret || jwtSecret.length < 32) {
  throw new Error(
    "APP_JWT_SECRET belum diatur atau terlalu pendek.",
  );
}

const secretKey = new TextEncoder().encode(jwtSecret);

export interface SessionUser {
  id: string;
  username: string;
  email: string;
}

export async function createSessionToken(
  user: SessionUser,
): Promise<string> {
  return await new SignJWT({
    username: user.username,
    email: user.email,
  })
    .setProtectedHeader({
      alg: "HS256",
      typ: "JWT",
    })
    .setSubject(user.id)
    .setIssuedAt()
    .setExpirationTime("7d")
    .setIssuer("gerak-in")
    .setAudience("gerak-in-app")
    .sign(secretKey);
}

export async function verifySessionToken(
  token: string,
): Promise<SessionUser | null> {
  try {
    const { payload } = await jwtVerify(
      token,
      secretKey,
      {
        issuer: "gerak-in",
        audience: "gerak-in-app",
        algorithms: ["HS256"],
      },
    );

    if (
      typeof payload.sub !== "string" ||
      typeof payload.username !== "string" ||
      typeof payload.email !== "string"
    ) {
      return null;
    }

    return {
      id: payload.sub,
      username: payload.username,
      email: payload.email,
    };
  } catch {
    return null;
  }
}

export async function getSessionUser(
  request: Request,
): Promise<SessionUser | null> {
  const authorization =
    request.headers.get("Authorization");

  if (!authorization) {
    return null;
  }

  const match = authorization.match(
    /^Bearer\s+(.+)$/i,
  );

  if (!match) {
    return null;
  }

  return await verifySessionToken(match[1]);
}
