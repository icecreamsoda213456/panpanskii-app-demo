import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type PushRequest = {
  type?: unknown;
  title?: unknown;
  body?: unknown;
  planId?: unknown;
  action?: unknown;
};

type CoupleDateRow = {
  id: string;
  user_id: string;
  username: string;
  mascot: string;
  title: string;
  category: string;
  visibility: string;
  starts_at: string;
  reminder_minutes: number | null;
  created_at: string;
  updated_at: string;
};

const coupleDateSyncType = 'couple_date_alarm_sync';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed.' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization) {
    return json({ error: 'Authentication is required.' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const firebaseProjectId = Deno.env.get('FIREBASE_PROJECT_ID');
  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !serviceRoleKey ||
    !firebaseProjectId
  ) {
    console.error('STEP env_check failed: missing one of SUPABASE_URL/ANON/SERVICE_ROLE/FIREBASE_PROJECT_ID');
    return json({ error: 'Push configuration is incomplete.' }, 500);
  }

  let payload: PushRequest;
  try {
    payload = await request.json() as PushRequest;
  } catch (_) {
    return json({ error: 'A JSON request body is required.' }, 400);
  }
  const type = cleanString(payload.type);

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();
  if (userError || !user) {
    return json({ error: 'Your session has expired.' }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: approvedSender, error: approvedSenderError } = await admin
    .from('panpanskii_approved_users')
    .select('user_id')
    .eq('user_id', user.id)
    .maybeSingle();
  if (approvedSenderError || !approvedSender) {
    return json({ error: 'This account is not approved for Panpanskii.' }, 403);
  }

  let recipientTokens: string[];
  try {
    recipientTokens = await loadRecipientTokens(admin, user.id);
  } catch (error) {
    console.error(`STEP load_recipient_tokens failed: ${String(error)}`);
    return json({ error: `STEP load_recipient_tokens failed: ${String(error)}` }, 500);
  }

  let accessToken: string;
  try {
    accessToken = await createFirebaseAccessToken();
  } catch (error) {
    console.error(`STEP firebase_auth failed: ${String(error)}`);
    return json({ error: `STEP firebase_auth failed: ${String(error)}` }, 500);
  }

  try {
    if (type === coupleDateSyncType) {
      return await handleCoupleDateSync({
        admin,
        payload,
        senderUserId: user.id,
        recipientTokens,
        accessToken,
        firebaseProjectId,
      });
    }

    const title = cleanString(payload.title);
    const body = cleanString(payload.body);
    if (!title || !body) {
      return json({ error: 'A title and body are required.' }, 400);
    }

    // Widget notes must be DATA-ONLY: Android only wakes the app's
    // background isolate for data-only messages. If a `notification` block
    // were included, the system tray would swallow it while the app is
    // closed and the widget would never refresh on its own.
    const isWidgetNote = type === 'widget_note';
    const result = await sendToTokens(
      recipientTokens,
      (token) =>
        sendFcmMessage({
          accessToken,
          firebaseProjectId,
          token,
          admin,
          notification: isWidgetNote ? undefined : { title, body },
          data: { type, title, body },
        }),
    );
    return json(result);
  } catch (error) {
    console.error(`STEP send failed: ${String(error)}`);
    return json({ error: String(error) }, 500);
  }
});

async function handleCoupleDateSync({
  admin,
  payload,
  senderUserId,
  recipientTokens,
  accessToken,
  firebaseProjectId,
}: {
  admin: ReturnType<typeof createClient>;
  payload: PushRequest;
  senderUserId: string;
  recipientTokens: string[];
  accessToken: string;
  firebaseProjectId: string;
}) {
  const planId = cleanString(payload.planId);
  const action = cleanString(payload.action);
  if (!isUuid(planId) || !['upsert', 'cancel'].includes(action)) {
    return json({ error: 'A valid planId and action are required.' }, 400);
  }

  const { data: plan, error: planError } = await admin
    .from('couple_dates')
    .select(
      'id, user_id, username, mascot, title, category, visibility, starts_at, reminder_minutes, created_at, updated_at',
    )
    .eq('id', planId)
    .maybeSingle<CoupleDateRow>();
  if (planError || !plan) {
    return json({ error: 'Date plan not found.' }, 404);
  }
  if (plan.user_id !== senderUserId) {
    return json({ error: 'Only the plan owner can synchronize its alarm.' }, 403);
  }
  if (action === 'upsert' && plan.visibility !== 'shared') {
    return json({ error: 'Personal plans cannot be sent to the partner.' }, 409);
  }

  const data: Record<string, string> = {
    type: coupleDateSyncType,
    action,
    plan_id: plan.id,
    sync_version: new Date().toISOString(),
  };
  if (action === 'upsert') {
    Object.assign(data, {
      user_id: plan.user_id,
      username: plan.username,
      mascot: plan.mascot,
      title: plan.title,
      category: plan.category,
      visibility: plan.visibility,
      starts_at: plan.starts_at,
      reminder_minutes: plan.reminder_minutes?.toString() ?? '',
      created_at: plan.created_at,
      updated_at: plan.updated_at,
    });
  }

  const result = await sendToTokens(
    recipientTokens,
    (token) =>
      sendFcmMessage({
        admin,
        accessToken,
        firebaseProjectId,
        token,
        data,
      }),
  );
  return json(result);
}

async function loadRecipientTokens(
  admin: ReturnType<typeof createClient>,
  senderUserId: string,
) {
  const { data: approvedRecipients, error: recipientsError } = await admin
    .from('panpanskii_approved_users')
    .select('user_id')
    .neq('user_id', senderUserId);
  if (recipientsError) {
    throw new Error(`Could not load the approved partner: ${recipientsError.message}`);
  }

  const recipientIds = (approvedRecipients ?? [])
    .map((row) => cleanString(row.user_id))
    .filter(Boolean);
  if (recipientIds.length === 0) {
    return [];
  }

  const { data: rows, error: tokensError } = await admin
    .from('push_tokens')
    .select('token')
    .in('user_id', recipientIds);
  if (tokensError) {
    throw new Error(`Could not load push tokens: ${tokensError.message}`);
  }

  return [...new Set(
    (rows ?? []).map((row) => cleanString(row.token)).filter(Boolean),
  )];
}

async function sendToTokens(
  tokens: string[],
  sender: (token: string) => Promise<void>,
) {
  if (tokens.length === 0) {
    console.error('STEP send skipped: recipient has 0 push tokens (partner never opened the app on this APK)');
    return { sent: 0, failed: 0 };
  }
  console.log(`STEP send starting: ${tokens.length} token(s)`);
  const results = await Promise.allSettled(tokens.map(sender));
  const summary = {
    sent: results.filter((result) => result.status === 'fulfilled').length,
    failed: results.filter((result) => result.status === 'rejected').length,
  };
  console.log(`STEP send done: sent=${summary.sent} failed=${summary.failed}`);
  for (const result of results) {
    if (result.status === 'rejected') {
      console.error(`STEP send per-token failure: ${String(result.reason)}`);
    }
  }
  return summary;
}

async function sendFcmMessage({
  admin,
  accessToken,
  firebaseProjectId,
  token,
  notification,
  data,
}: {
  admin: ReturnType<typeof createClient>;
  accessToken: string;
  firebaseProjectId: string;
  token: string;
  notification?: { title: string; body: string };
  data: Record<string, string>;
}) {
  const message: Record<string, unknown> = {
    token,
    data,
    android: {
      priority: 'HIGH',
      ttl: '86400s',
    },
  };
  if (notification) {
    message.notification = notification;
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ message }),
    },
  );
  if (!response.ok) {
    const detail = await response.text();
    console.error(`STEP fcm_send failed (HTTP ${response.status}): ${detail}`);
    if (response.status === 404 && /NotRegistered|UNREGISTERED/.test(detail)) {
      try {
        await admin.from('push_tokens').delete().eq('token', token);
        console.error(`STEP removed stale push token (NotRegistered): ${token.slice(0, 18)}…`);
      } catch (deleteError) {
        console.error(`STEP could not remove stale token: ${String(deleteError)}`);
      }
    }
    throw new Error(`FCM failed: ${detail}`);
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

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion: jwt,
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });
  if (!response.ok) {
    const detail = await response.text();
    console.error(`STEP google_token exchange failed (HTTP ${response.status}): ${detail}`);
    console.error(`DEBUG jwt_length=${jwt.length} jwt_prefix=${jwt.slice(0,40)}`);
    throw new Error(`Google auth failed: ${detail}`);
  }

  const result = await response.json() as { access_token?: string };
  if (!result.access_token) {
    throw new Error('Google auth response did not include access_token.');
  }
  return result.access_token;
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

function cleanString(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function mustEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing env var: ${name}`);
  }
  return value;
}

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'content-type': 'application/json',
    },
  });
}
