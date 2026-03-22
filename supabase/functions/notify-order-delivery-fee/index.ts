import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

serve(async (req) => {
  try {
    const supabaseUrl = Deno.env.get("https://mxngcloeolzkfnauioln.supabase.co") ?? "";
    const supabaseAnonKey = Deno.env.get("sb_secret_-Rfkp-sQcn-cYWnb-p6drQ_MuTJzwrI") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("AIzaSyD8IQYYmpQvg0NdjfnhcTUOknQbbBx0xIw") ?? "";

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data: authData, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !authData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const body = await req.json().catch(() => ({}));
    const orderId = body?.order_id?.toString();
    if (!orderId) {
      return new Response(JSON.stringify({ error: "order_id is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("user_id", authData.user.id)
      .maybeSingle();

    const role = profile?.role?.toString();
    const isStaff = role === "admin" || role === "moderator";

    if (profileError || !isStaff) {
      return new Response(JSON.stringify({ error: "Admin access required" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: order, error: orderError } = await supabaseAdmin
      .from("orders")
      .select("id, user_id, delivery_fee, delivery_fee_status, status")
      .eq("id", orderId)
      .single();

    if (orderError || !order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: customerProfile, error: customerProfileError } = await supabaseAdmin
      .from("profiles")
      .select("fcm_token")
      .eq("user_id", order.user_id)
      .maybeSingle();

    if (customerProfileError) {
      return new Response(JSON.stringify({ error: "Failed to load customer profile" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const fcmToken = customerProfile?.fcm_token;
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmToken || !fcmServerKey) {
      return new Response(
        JSON.stringify({
          success: true,
          pushed: false,
          reason: !fcmToken ? "Missing fcm_token" : "Missing FCM_SERVER_KEY",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const deliveryFee = order.delivery_fee ?? 0;
    const title = "Delivery fee confirmed";
    const bodyText = `Delivery fee is ${deliveryFee.toLocaleString()} MMK. Tap to approve or cancel.`;

    const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `key=${fcmServerKey}`,
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: {
          title,
          body: bodyText,
          sound: "default",
        },
        data: {
          type: "delivery_fee_set",
          order_id: order.id,
          delivery_fee: String(deliveryFee),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        priority: "high",
      }),
    });

    if (!fcmResponse.ok) {
      const errorText = await fcmResponse.text();
      return new Response(JSON.stringify({ success: false, error: errorText }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ success: true, pushed: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error?.message ?? String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
