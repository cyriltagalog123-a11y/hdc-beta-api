import { closeDb, openDb } from './_lib/db.mjs';
import { corsPreflightResponse, withCors } from './_lib/cors.mjs';
import { handleRegistrationWithDb } from './_lib/registration.mjs';

export default async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return corsPreflightResponse(req);
  const sql = openDb();
  try {
    const response = await handleRegistrationWithDb(
      req,
      sql,
      'public_registration_v2_compat',
    );
    const headers = new Headers(response.headers);
    headers.set('deprecation', 'true');
    headers.set('link', '</api/auth/register>; rel="successor-version"');
    return withCors(req, new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    }));
  } finally {
    await closeDb(sql);
  }
};

export const config = {
  path: '/api/auth/register-v2',
};
