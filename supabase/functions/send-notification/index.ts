import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import { JWT } from "https://esm.sh/google-auth-library@9.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Ensure method is POST
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed. Use POST." }),
        { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey || !serviceAccountJson) {
      throw new Error("Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or FIREBASE_SERVICE_ACCOUNT");
    }

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (e) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT is not a valid JSON string");
    }

    // Use service role to bypass RLS and fetch fcm_token
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    // 2. Safely parse request body
    let body;
    try {
      body = await req.json();
      console.log("🔍 Step 4: Received request body:", JSON.stringify(body));
    } catch (e) {
      console.error("❌ Step 4: Error parsing request body:", e.message);
      return new Response(
        JSON.stringify({ error: "Invalid JSON body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { user_id, notification } = body;

    if (!user_id || !notification?.title || !notification?.body) {
      console.error("❌ Step 5: Missing required fields (user_id, title, or body)");
      return new Response(
        JSON.stringify({ error: "user_id and notification(title, body) are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Query profiles for fcm_token
    console.log(`🔍 Step 6: Querying fcm_token for user_id: ${user_id}`);
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("fcm_token")
      .eq("user_id", user_id)
      .maybeSingle();

    if (profileError) {
      console.error("❌ Step 6: Database error:", profileError.message);
      throw profileError;
    }

    if (!profile?.fcm_token) {
      console.warn(`⚠️ Step 6: No fcm_token found for user ${user_id}`);
      return new Response(
        JSON.stringify({ success: false, message: "No fcm_token found for user" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    console.log("✅ Step 6: Found fcm_token:", profile.fcm_token.substring(0, 10) + "...");

    // 4. Generate Google OAuth2 Access Token using Service Account
    console.log("🔍 Step 7: Generating Google OAuth2 Access Token...");
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    const accessTokenResponse = await jwtClient.getAccessToken();
    const accessToken = accessTokenResponse.token;

    if (!accessToken) {
      console.error("❌ Step 7: Failed to generate access token");
      throw new Error("Failed to generate Google OAuth2 access token");
    }
    console.log("✅ Step 7: Access token generated successfully");

    // 5. Send FCM notification using HTTP v1 API
    const projectId = serviceAccount.project_id;
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    console.log(`🔍 Step 8: Sending FCM message to project: ${projectId}`);

    const fcmResponse = await fetch(fcmEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: profile.fcm_token,
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: notification.data || {},
          android: {
            priority: "high",
            notification: {
              sound: "default",
            },
          },
        },
      }),
    });

    const fcmResult = await fcmResponse.json();
    
    // 6. Log the result for debugging in Supabase dashboard
    console.log("✅ Step 9: FCM API Response:", JSON.stringify(fcmResult, null, 2));

    if (!fcmResponse.ok) {
      console.error("❌ Step 9: FCM API returned an error");
      return new Response(
        JSON.stringify({ success: false, fcm_error: fcmResult }),
        { status: fcmResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, fcm_result: fcmResult }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Edge Function Error:", error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
