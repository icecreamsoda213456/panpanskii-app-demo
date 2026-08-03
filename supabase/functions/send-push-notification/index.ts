git commit -m "Initial Panpanskii source code"type PushRequest = {
  senderUserId?: string;
  type?: string;
  title?: string;
  body?: string;
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await request.json() as PushRequest;
    const senderUserId = payload.senderUserId?.trim();
    const title = payload.title?.trim();
    const body = payload.body?.trim();

    if (!senderUserId || !title || !body) {
      return json({ error: 'Missing senderUserId, title, or body.' }, 400);
    }

    const supabaseUrl = mustEnv('SUPABASE_URL');
    const serviceRoleKey = mustEnv('SUPABASE_SERVICE_ROLE_KEY');
    const firebaseProjectId = mustEnv('FIREBASE_PROJECT_ID');

    const tokens = await loadRecipientTokens({
      supabaseUrl,
      serviceRoleKey,
      senderUserId,
    });

    if (tokens.length === 0) {
      return json({ sent: 0 });
    }

    const accessToken = await createFirebaseAccessToken();
    const results = await Promise.allSettled(
      tokens.map((token) =>
        sendFcmMessage({
          accessToken,
          firebaseProjectId,
          token,
          title,
          body,
          type: payload.type ?? 'panpanskii',
        }),
      ),
    );

    return json({
      sent: results.filter((result) => result.status === 'fulfilled').length,
      failed: results.filter((result) => result.status === 'rejected').length,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});

async function loadRecipientTokens({
  supabaseUrl,
  serviceRoleKey,
  senderUserId,
}: {
  supabaseUrl: string;
  serviceRoleKey: string;
  senderUserId: string;
}) {
  const url = new URL('/rest/v1/push_tokens', supabaseUrl);
  url.searchParams.set('select', 'token');
  url.searchParams.set('user_id', `neq.${senderUserId}`);

  const response = await fetch(url, {
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Could not load push tokens: ${await response.text()}`);
  }

  const rows = await response.json() as Array<{ token?: string }>;
  return rows
    .map((row) => row.token)
    .filter((token): token is string => Boolean(token));
}

async function sendFcmMessage({
  accessToken,
  firebaseProjectId,
  token,
  title,
  body,
  type,
}: {
  accessToken: string;
  firebaseProjectId: string;
  token: string;
  title: string;
  body: string;
  type: string;
}) {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: { type, title, body },
          android: {
            priority: 'HIGH',
          },
        },
      }),
    },
  );

  if (!response.ok) {
    throw new Error(`FCM failed: ${await response.text()}`);
  }
}

async function createFirebaseAccessToken() {
  const clientEmail = mustEnv('FIREBASE_CLIENT_EMAIL');
  const privateKey = mustEnv('FIREBASE_PRIVATE_KEY').replaceAll('\\n', '\n');
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const unsignedJwt = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedJwt),
  );
  const jwt = `${unsignedJwt}.${base64Url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google auth failed: ${await response.text()}`);
  }

  const data = await response.json() as { access_token?: string };
  if (!data.access_token) {
    throw new Error('Google auth response did not include access_token.');
  }
  return data.access_token;
}

function pemToArrayBuffer(pem: string) {
  const clean = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function base64Url(input: string | ArrayBuffer) {
  const bytes = typeof input === 'string'
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function mustEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}
