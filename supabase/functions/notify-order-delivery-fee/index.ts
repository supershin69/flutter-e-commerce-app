import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

serve(async (req) => {
  try {
    // ✅ Use proper environment variable names
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      throw new Error("Missing Supabase environment variables");
    }

    // Create two clients: one for authentication (using anon key) and one for admin operations (using service role)
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 1. Authenticate the user
    const { data: authData, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !authData?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. Parse request body
    let body: { order_id?: string };
    try {
      body = await req.json();
    } catch {
      return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const orderId = body.order_id?.trim();
    if (!orderId) {
      return new Response(JSON.stringify({ error: "order_id is required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 3. Check if the authenticated user is an admin or moderator
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("user_id", authData.user.id)
      .maybeSingle();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: "Unable to verify user role" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    const role = profile.role?.toString().toLowerCase();
    const isStaff = role === "admin" || role === "moderator";
    if (!isStaff) {
      return new Response(JSON.stringify({ error: "Admin or moderator access required" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Fetch the order
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

    // 5. Get the customer's FCM token
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
    if (!fcmToken || !fcmServerKey) {
      return new Response(
        JSON.stringify({
          success: true,
          pushed: false,
          reason: !fcmToken ? "Customer has no FCM token" : "FCM server key not configured",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const deliveryFee = order.delivery_fee ?? 0;
    const title = "Delivery Fee Confirmed";
    const bodyText = `Delivery fee is ${deliveryFee.toLocaleString?.() ?? deliveryFee} MMK. Tap to approve or cancel.`;

    // 6. Send FCM notification
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
    console.error("Unexpected error:", error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});