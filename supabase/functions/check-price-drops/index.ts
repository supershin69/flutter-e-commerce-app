// Follow Deno style for Supabase Edge Functions
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

console.log("Hello from check-price-drops function!")

interface DatabaseAlert {
  id: string
  user_id: string
  product_id: string
  target_price: number
  products: {
    name: string
    min_price: number
  }
  profiles: {
    fcm_token: string | null
  }
}

serve(async (req) => {
  try {
    // Create a Supabase client with the Auth context of the logged in user
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    )

    // Get the service role client for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    )

    // Fetch all active price alerts
    const { data: alerts, error: alertsError } = await supabaseAdmin
      .from("price_alerts")
      .select(`
        id,
        user_id,
        product_id,
        target_price,
        products:product_id (
          name,
          min_price
        ),
        profiles!inner (
          fcm_token
        )
      `)
      .eq("is_active", true)
      .eq("profiles.price_alerts_enabled", true)

    if (alertsError) {
      console.error("Error fetching alerts:", alertsError)
      return new Response(
        JSON.stringify({ error: alertsError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    console.log(`Found ${alerts?.length || 0} active alerts`)
    
    if (!alerts || alerts.length === 0) {
      return new Response(
        JSON.stringify({ message: "No alerts to process" }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    let notificationsCreated = 0
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY")

    // Process each alert
    for (const alert of alerts as unknown as DatabaseAlert[]) {
      const currentPrice = alert.products.min_price
      
      if (currentPrice <= alert.target_price) {
        console.log(`Price drop detected for ${alert.products.name}`)

        // Create notification in database
        const { error: notifError } = await supabaseAdmin
          .from("notifications")
          .insert({
            user_id: alert.user_id,
            title: "Price Drop Alert! 🏷️",
            body: `${alert.products.name} is now ${currentPrice.toLocaleString()} MMK`,
            data: {
              type: "price_drop",
              product_id: alert.product_id,
              target_price: alert.target_price,
              current_price: currentPrice,
            }
          })

        if (notifError) {
          console.error("Error creating notification:", notifError)
          continue
        }

        notificationsCreated++

        // Send FCM push if token exists and we have server key
        if (alert.profiles.fcm_token && fcmServerKey) {
          try {
            const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                "Authorization": `key=${fcmServerKey}`,
              },
              body: JSON.stringify({
                to: alert.profiles.fcm_token,
                notification: {
                  title: "Price Drop Alert! 🏷️",
                  body: `${alert.products.name} is now ${currentPrice.toLocaleString()} MMK`,
                  sound: "default",
                },
                data: {
                  type: "price_drop",
                  product_id: alert.product_id,
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
                priority: "high",
              }),
            })

            if (!fcmResponse.ok) {
              const errorText = await fcmResponse.text()
              console.error("FCM send error:", errorText)
            }
          } catch (fcmError) {
            console.error("FCM exception:", fcmError)
          }
        }

        // Update alert with notified_at
        await supabaseAdmin
          .from("price_alerts")
          .update({ notified_at: new Date().toISOString() })
          .eq("id", alert.id)
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processed: alerts.length,
        notificationsCreated 
      }),
      { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    )
  } catch (error) {
    console.error("Function error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
})