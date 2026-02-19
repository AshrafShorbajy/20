// Zoom webhook receiver: stores attendance events into attendance_events
// Expected to be deployed as a Supabase Edge Function
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ZOOM_WEBHOOK_SECRET = Deno.env.get("ZOOM_WEBHOOK_SECRET") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

function verifyZoom(req: Request): boolean {
  if (!ZOOM_WEBHOOK_SECRET) return true;
  const sig = req.headers.get("x-zm-signature") || "";
  return sig === ZOOM_WEBHOOK_SECRET;
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method Not Allowed", { status: 405 });
    }
    if (!verifyZoom(req)) {
      return new Response("Unauthorized", { status: 401 });
    }
    const body = await req.json();
    const event = body?.event as string | undefined;
    const payload = body?.payload || {};
    const meeting = payload?.object || {};
    const participant = meeting?.participant || payload?.participant || {};

    // Common fields
    const meeting_id = String(meeting?.id ?? meeting?.uuid ?? payload?.object?.uuid ?? "");
    const schedule_id = (payload?.schedule_id ?? null) as string | null; // optional injection if available
    const booking_id = (payload?.booking_id ?? null) as string | null;
    const lesson_id = (payload?.lesson_id ?? null) as string | null;

    // Participant data
    const participant_id = participant?.id ? String(participant.id) : null;
    const participant_name = participant?.user_name || participant?.name || null;
    const participant_email = participant?.email || null;
    const participant_role = participant?.role || null;

    // Map event types to joined/left/started/ended
    let event_type = "joined";
    if ((event || "").includes("participant_left")) event_type = "left";
    else if ((event || "").includes("meeting_started")) event_type = "started";
    else if ((event || "").includes("meeting_ended")) event_type = "ended";
    else if ((event || "").includes("participant_joined")) event_type = "joined";

    const { error } = await supabase.from("attendance_events").insert({
      meeting_id,
      schedule_id,
      booking_id,
      lesson_id,
      participant_id,
      participant_name,
      participant_email,
      participant_role,
      event_type,
      metadata: body,
    } as any);
    if (error) {
      console.error("Insert attendance error:", error);
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
    }
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (e) {
    console.error("Zoom webhook error:", e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
