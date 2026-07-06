// GoRolli — Stripe Checkout Session broneeringu maksele (Adaptive Pricing).
// Klient saadab AINULT booking_id. Summa ja valuuta tulevad SERVERIST:
// bookings.total_price (EUR). Checkout baashind on ALATI EUR; Adaptive
// Pricing (Stripe Dashboard seadistus + adaptive_pricing param) esitab
// kliendile KOHALIKU valuuta (NOK/JPY/PHP jne); settlement ja GoRolli
// ledger jäävad EUR-i.
// NB: capture on AUTOMAATNE — Adaptive Pricing EI toeta manual capture'i
// (Stripe docs: Adaptive Pricing limitations). Seetõttu toimub makse
// pickup-hetkel täies mahus; hilisem tühistus = refund.
// Deploy: supabase functions deploy payments-checkout
// Secrets: STRIPE_SECRET_KEY; valikuline CHECKOUT_RETURN_BASE
//          (vaikimisi https://client.gorolli.com).
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@18?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);
const RETURN_BASE =
  Deno.env.get("CHECKOUT_RETURN_BASE") ?? "https://client.gorolli.com";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }
  try {
    // KLIENDILT võetakse AINULT booking_id — amounti/currencyt EI usaldata.
    const { booking_id } = await req.json();
    const id = Number(booking_id);
    if (!Number.isInteger(id) || id <= 0) {
      return json({ status: "ERR", error: "Invalid booking_id" }, 400);
    }

    const { data: b, error } = await supabase
      .from("bookings")
      .select(
        "id,total_price,currency,payment_status,status,stripe_customer_id,trailer_type,trailer_id",
      )
      .eq("id", id)
      .maybeSingle();
    if (error) throw error;
    if (!b) return json({ status: "ERR", error: "Booking not found" }, 404);
    if (String(b.currency ?? "EUR").toUpperCase() !== "EUR") {
      console.error(
        `[CHECKOUT] Non-EUR booking blocked: id=${id} cur=${b.currency}`,
      );
      return json({ status: "ERR", error: "GoRolli ledger is EUR-only." }, 400);
    }
    if (b.payment_status === "paid") {
      return json({ status: "ERR", error: "Booking is already paid." }, 400);
    }

    // Summa arvutab SERVER booking-realt (FAAS0 piirid: 0.50–10 000 EUR).
    const amount = Math.round(Number(b.total_price) * 100);
    if (!Number.isInteger(amount) || amount < 50 || amount > 1000000) {
      console.error(
        `[CHECKOUT] Invalid amount: id=${id} total=${b.total_price}`,
      );
      return json({ status: "ERR", error: "Invalid payment amount." }, 400);
    }

    const name =
      `GoRolli rent — ${b.trailer_type || "trailer"} #${b.trailer_id ?? id}`;
    const params: Record<string, unknown> = {
      mode: "payment",
      line_items: [{
        quantity: 1,
        price_data: {
          currency: "eur", // baas ALATI EUR — Adaptive Pricing teisendab kuval
          unit_amount: amount,
          product_data: { name },
        },
      }],
      // booking_id seotakse NII sessiooni KUI PaymentIntenti metadata'sse.
      metadata: { booking_id: String(id) },
      payment_intent_data: { metadata: { booking_id: String(id) } },
      success_url:
        `${RETURN_BASE}/find?checkout=success&booking_id=${id}&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${RETURN_BASE}/find?checkout=cancel&booking_id=${id}`,
      // Kohalik valuuta kliendile; kui konto pole veel eligible -> retry ilma.
      adaptive_pricing: { enabled: true },
    };
    if (b.stripe_customer_id) params.customer = b.stripe_customer_id;

    let session;
    try {
      session = await stripe.checkout.sessions.create(
        params as unknown as Stripe.Checkout.SessionCreateParams,
      );
    } catch (e) {
      if (String(e).toLowerCase().includes("adaptive_pricing")) {
        delete params.adaptive_pricing; // fallback: kuva EUR-is
        session = await stripe.checkout.sessions.create(
          params as unknown as Stripe.Checkout.SessionCreateParams,
        );
      } else {
        throw e;
      }
    }

    // Kahesuunaline sidumine webhooki kontrolliks.
    await supabase
      .from("bookings")
      .update({
        stripe_checkout_session_id: session.id,
        updated_at: new Date().toISOString(),
      })
      .eq("id", id);

    return json({ status: "OK", url: session.url, session_id: session.id });
  } catch (e) {
    console.error("[CHECKOUT] ERR", String(e));
    return json({ status: "ERR", message: String(e) }, 500);
  }
});
