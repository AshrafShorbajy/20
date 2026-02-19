import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { type, user_id, sender_id, conversation_id, student_id, teacher_id, title, body, broadcast_target } =
      await req.json();

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY")!;
    const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY")!;

    // Configure web-push with VAPID details
    webpush.setVapidDetails(
      "mailto:admin@sudtutor.com",
      vapidPublicKey,
      vapidPrivateKey
    );

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Determine target user IDs
    let targetUserIds: string[] = [];

    if (type === "broadcast" && broadcast_target) {
      // Broadcast announcement to users by role
      if (broadcast_target === "all") {
        const { data: allRoles } = await supabase.from("user_roles").select("user_id");
        targetUserIds = [...new Set((allRoles ?? []).map((r: any) => r.user_id))];
      } else if (broadcast_target === "students") {
        const { data: studentRoles } = await supabase.from("user_roles").select("user_id").eq("role", "student");
        targetUserIds = (studentRoles ?? []).map((r: any) => r.user_id);
      } else if (broadcast_target === "teachers") {
        const { data: teacherRoles } = await supabase.from("user_roles").select("user_id").eq("role", "teacher");
        targetUserIds = (teacherRoles ?? []).map((r: any) => r.user_id);
      }
    } else if (type === "new_message" && sender_id && conversation_id) {
      const { data: conv } = await supabase
        .from("conversations")
        .select("student_id, teacher_id")
        .eq("id", conversation_id)
        .single();

      if (conv) {
        const recipientId =
          conv.student_id === sender_id ? conv.teacher_id : conv.student_id;
        targetUserIds = [recipientId];
      }
    } else if (type === "invoice_approved" && student_id && teacher_id) {
      targetUserIds = [student_id, teacher_id];
    } else if (user_id) {
      targetUserIds = [user_id];
    }

    if (targetUserIds.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // For broadcast, also insert in-app notifications
    if (type === "broadcast" && targetUserIds.length > 0) {
      const notifRows = targetUserIds.map((uid) => ({
        user_id: uid,
        type: "announcement",
        title: title || "إعلان جديد",
        body: body || "",
        metadata: { broadcast_target },
      }));
      // Insert in batches of 500
      for (let i = 0; i < notifRows.length; i += 500) {
        const batch = notifRows.slice(i, i + 500);
        await supabase.from("notifications").insert(batch);
      }
    }

    // Get push subscriptions for target users
    const { data: subscriptions } = await supabase
      .from("push_subscriptions")
      .select("*")
      .in("user_id", targetUserIds);

    // Load OneSignal settings
    const { data: osSettings } = await supabase
      .from("site_settings")
      .select("value")
      .eq("key", "onesignal_settings")
      .maybeSingle();

    const onesignal = osSettings?.value as { enabled?: boolean; app_id?: string; rest_api_key?: string } | null;

    const payload = JSON.stringify({
      title: title || "إشعار جديد",
      body: body || "",
      icon: "/favicon.ico",
      badge: "/favicon.ico",
      data: { type, url: "/" },
    });

    let webPushSent = 0;
    const expiredIds: string[] = [];

    // Send Web Push notifications
    if (subscriptions && subscriptions.length > 0) {
      for (const sub of subscriptions) {
        try {
          const pushSubscription = {
            endpoint: sub.endpoint,
            keys: {
              p256dh: sub.p256dh,
              auth: sub.auth,
            },
          };

          await webpush.sendNotification(pushSubscription, payload);
          webPushSent++;
          console.log(`Push sent successfully to ${sub.endpoint.slice(0, 50)}...`);
        } catch (error: any) {
          console.error(`Push failed for sub ${sub.id}:`, error.statusCode, error.body);
          if (error.statusCode === 410 || error.statusCode === 404) {
            expiredIds.push(sub.id);
          }
        }
      }

      // Clean up expired subscriptions
      if (expiredIds.length > 0) {
        await supabase.from("push_subscriptions").delete().in("id", expiredIds);
      }
    }

    // Send OneSignal notifications
    let onesignalSent = 0;
    if (onesignal?.enabled && onesignal.app_id && onesignal.rest_api_key) {
      try {
        let osPayload: any;
        if (type === "broadcast") {
          // For all broadcast types, use "Subscribed Users" segment
          // OneSignal doesn't know about our role system, so we broadcast to all
          // Role-based filtering is handled by in-app notifications
          osPayload = {
            app_id: onesignal.app_id,
            included_segments: ["Subscribed Users"],
            headings: { en: title || "إعلان جديد", ar: title || "إعلان جديد" },
            contents: { en: body || "", ar: body || "" },
            data: { type, url: "/" },
          };
        } else if (targetUserIds.length > 0) {
          osPayload = {
            app_id: onesignal.app_id,
            include_aliases: {
              external_id: targetUserIds,
            },
            target_channel: "push",
            headings: { en: title || "إشعار جديد", ar: title || "إشعار جديد" },
            contents: { en: body || "", ar: body || "" },
            data: { type, url: "/" },
          };
        }

        const osResponse = await fetch("https://onesignal.com/api/v1/notifications", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Basic ${onesignal.rest_api_key}`,
          },
          body: JSON.stringify(osPayload),
        });

        const osResult = await osResponse.json();
        if (osResponse.ok) {
          onesignalSent = osResult.recipients || 0;
          console.log("OneSignal sent:", osResult);
        } else {
          console.error("OneSignal error:", osResult);
        }
      } catch (osError) {
        console.error("OneSignal request failed:", osError);
      }
    }

    return new Response(JSON.stringify({ sent: webPushSent, onesignal_sent: onesignalSent, expired: expiredIds.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Push notification error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
