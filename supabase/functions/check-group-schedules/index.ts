import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Find group lessons where not all sessions have schedules filled
    const { data: groupLessons } = await supabase
      .from("lessons")
      .select("id, title, teacher_id, total_sessions")
      .eq("lesson_type", "group")
      .eq("is_active", true)
      .not("total_sessions", "is", null);

    if (!groupLessons || groupLessons.length === 0) {
      return new Response(JSON.stringify({ checked: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let notified = 0;

    for (const lesson of groupLessons) {
      // Count filled schedules
      const { count: filledCount } = await supabase
        .from("group_session_schedules")
        .select("id", { count: "exact", head: true })
        .eq("lesson_id", lesson.id)
        .not("scheduled_at", "is", null);

      const totalSessions = lesson.total_sessions || 0;
      const filled = filledCount || 0;

      if (filled < totalSessions) {
        // Check if we already sent a notification today
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const { data: existingNotif } = await supabase
          .from("notifications")
          .select("id")
          .eq("user_id", lesson.teacher_id)
          .eq("type", "group_schedule_reminder")
          .gte("created_at", today.toISOString())
          .maybeSingle();

        if (!existingNotif) {
          // Create notification
          await supabase.from("notifications").insert({
            user_id: lesson.teacher_id,
            type: "group_schedule_reminder",
            title: "تنبيه: أكمل مواعيد الحصص",
            body: `الرجاء إتمام مواعيد الحصص لكورس "${lesson.title}" (${filled}/${totalSessions} مكتمل)`,
            metadata: { lesson_id: lesson.id },
          });

          // Send push notification
          try {
            await fetch(`${supabaseUrl}/functions/v1/send-push-notification`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${Deno.env.get("SUPABASE_ANON_KEY")}`,
              },
              body: JSON.stringify({
                type: "group_schedule_reminder",
                user_id: lesson.teacher_id,
                title: "تنبيه: أكمل مواعيد الحصص",
                body: `الرجاء إتمام مواعيد الحصص لكورس "${lesson.title}"`,
              }),
            });
          } catch (e) {
            console.error("Push failed:", e);
          }

          notified++;
        }
      }
    }

    return new Response(JSON.stringify({ checked: groupLessons.length, notified }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
