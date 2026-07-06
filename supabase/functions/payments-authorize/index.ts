import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@16.0.0?target=deno";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// LOEB SECRET'IST (mitte kõvakodeeritud). Supabase: STRIPE_SECRET_KEY = sk_live_51SInYb...
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY")!;

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", {
        status: 405,
        headers: corsHeaders,
      });
    }

    const { booking_id, amount, currency, customer_id, payment_method_id } =
      await req.json();

    const requestedCurrency = String(currency ?? "eur").toLowerCase();
    if (requestedCurrency !== "eur") {
      console.error("[FAAS0] Blocked non-EUR payment authorize", {
        booking_id,
        requestedCurrency,
      });

      return new Response(
        JSON.stringify({ error: "Only EUR payments are currently allowed" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const amountInt = Number(amount);
    if (!Number.isInteger(amountInt) || amountInt < 50 || amountInt > 1000000) {
      console.error("[FAAS0] Blocked invalid payment amount", {
        booking_id,
        amount,
      });

      return new Response(
        JSON.stringify({ error: "Invalid payment amount" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const pi = await stripe.paymentIntents.create({
      amount: amountInt,
      currency: "eur",
      customer: customer_id,
      payment_method: payment_method_id,
      capture_method: "manual",
      confirm: true,
      off_session: true,
      metadata: { booking_id: String(booking_id) },
    });

    return new Response(
      JSON.stringify({
        status: "OK",
        payment_intent_id: pi.id,
        stripe_status: pi.status,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ status: "ERR", message: String(e) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});