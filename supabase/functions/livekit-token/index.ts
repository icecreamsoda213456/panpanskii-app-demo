import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  AccessToken,
  RoomServiceClient,
  TrackSource,
} from 'npm:livekit-server-sdk@2.17.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

type PhotoBoothSession = {
  id: string;
  room_name: string;
  status: string;
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function liveKitHttpUrl(serverUrl: string) {
  return serverUrl
    .replace(/^wss:/i, 'https:')
    .replace(/^ws:/i, 'http:')
    .replace(/\/$/, '');
}

async function ensureTwoPersonRoom({
  serverUrl,
  apiKey,
  apiSecret,
  roomName,
}: {
  serverUrl: string;
  apiKey: string;
  apiSecret: string;
  roomName: string;
}) {
  const roomService = new RoomServiceClient(
    liveKitHttpUrl(serverUrl),
    apiKey,
    apiSecret,
  );
  const existingRooms = await roomService.listRooms([roomName]);
  if (existingRooms.length > 0) return;

  try {
    await roomService.createRoom({
      name: roomName,
      maxParticipants: 2,
      emptyTimeout: 60,
    });
  } catch (error) {
    // Both participants can request their token at once. If the other request
    // created the room first, it is safe to proceed with that two-person room.
    const roomsAfterCreateRace = await roomService.listRooms([roomName]);
    if (roomsAfterCreateRace.length === 0) throw error;
  }
}

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
  const liveKitUrl = Deno.env.get('LIVEKIT_URL');
  const liveKitApiKey = Deno.env.get('LIVEKIT_API_KEY');
  const liveKitApiSecret = Deno.env.get('LIVEKIT_API_SECRET');
  if (
    !supabaseUrl ||
    !supabaseAnonKey ||
    !liveKitUrl ||
    !liveKitApiKey ||
    !liveKitApiSecret
  ) {
    return json({ error: 'Live camera server configuration is incomplete.' }, 500);
  }

  let body: { session_id?: unknown };
  try {
    body = await request.json();
  } catch (_) {
    return json({ error: 'A Photo Booth session is required.' }, 400);
  }
  const sessionId = typeof body.session_id === 'string' ? body.session_id : '';
  if (!sessionId) {
    return json({ error: 'A Photo Booth session is required.' }, 400);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authorization } },
  });
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();
  if (userError || !user) {
    return json({ error: 'Your session has expired.' }, 401);
  }

  const { data: participant, error: participantError } = await supabase
    .from('photobooth_participants')
    .select('session_id')
    .eq('session_id', sessionId)
    .eq('user_id', user.id)
    .maybeSingle();
  if (participantError || !participant) {
    return json({ error: 'You are not in this Photo Booth session.' }, 403);
  }

  const { data: session, error: sessionError } = await supabase
    .from('photobooth_sessions')
    .select('id, room_name, status')
    .eq('id', sessionId)
    .maybeSingle<PhotoBoothSession>();
  if (sessionError || !session) {
    return json({ error: 'Photo Booth session not found.' }, 404);
  }
  if (!['lobby', 'countdown', 'capturing'].includes(session.status)) {
    return json({ error: 'This Photo Booth session is no longer live.' }, 409);
  }
  const expectedRoomName = `photobooth-${sessionId}`;
  if (session.room_name !== expectedRoomName) {
    return json({ error: 'This Photo Booth has an invalid LiveKit room.' }, 409);
  }

  const { count, error: countError } = await supabase
    .from('photobooth_participants')
    .select('*', { count: 'exact', head: true })
    .eq('session_id', sessionId);
  if (countError || count == null || count < 1 || count > 2) {
    return json({ error: 'This Photo Booth has an invalid participant count.' }, 409);
  }

  try {
    await ensureTwoPersonRoom({
      serverUrl: liveKitUrl,
      apiKey: liveKitApiKey,
      apiSecret: liveKitApiSecret,
      roomName: expectedRoomName,
    });

    const token = new AccessToken(liveKitApiKey, liveKitApiSecret, {
      // `user.id` is verified from the bearer JWT and is the Edge Function
      // equivalent of PostgreSQL's auth.uid().
      identity: user.id,
      ttl: '1h',
    });
    token.addGrant({
      roomJoin: true,
      room: expectedRoomName,
      canPublish: true,
      canPublishData: false,
      canPublishSources: [TrackSource.CAMERA],
      canSubscribe: true,
    });

    return json({
      server_url: liveKitUrl,
      participant_token: await token.toJwt(),
    });
  } catch (error) {
    console.error('Unable to prepare LiveKit room', error);
    return json({ error: 'The live camera room could not be prepared.' }, 503);
  }
});
