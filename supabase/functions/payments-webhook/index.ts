// GoRolli — Stripe webhook: kinnitab Checkout-makse, seob booking_id
// metadata kaudu ja märgib bookingu makstuks. GoRolli ledger jääb EUR-i:
// bookings.total_price/currency EI muutu, ka siis kui klient maksis
// kohalikus valuutas (Adaptive Pricing: presentment != settlement).
// Deploy: supabase functions deploy payments-webhook --no-verify-jwt
//         (Stripe ei saada Supabase JWT-d — ilma lipuputa tuleb 401!)
// Secrets: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET.
// Stripe Dashboard → Developers → Webhooks → Add endpoint:
//   https://xuyoyaoxesnxxspixvdv.supabase.co/functions/v1/payments-webhook
//   events: checkout.session.completed,
//           checkout.session.async_payment_succeeded,
//           checkout.session.async_payment_failed
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@18?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);
const cryptoProvider = Stripe.createSubtleCryptoProvider();
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET")!;
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  const sig = req.headers.get("stripe-signature");
  const raw = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      raw,
      sig ?? "",
      WEBHOOK_SECRET,
      undefined,
      cryptoProvider,
    );
  } catch (e) {
    console.error("[WEBHOOK] Bad signature:", String(e));
    return new Response("Bad signature", { status: 400 });
  }

  try {
    if (
      event.type === "checkout.session.completed" ||
      event.type === "checkout.session.async_payment_succeeded"
    ) {
      const s = event.data.object as Stripe.Checkout.Session;
      const bookingId = Number(s.metadata?.booking_id);
      if (!Number.isInteger(bookingId) || bookingId <= 0) {
        console.error(`[WEBHOOK] ${event.type}: booking_id metadata puudub`);
      } else if (s.payment_status !== "paid") {
        // async makseviis alles pooleli — ootame *_succeeded eventi
        console.log(
          `[WEBHOOK] booking=${bookingId} payment_status=${s.payment_status} — ootan`,
        );
      } else {
        const { data: b } = await supabase
          .from("bookings")
          .select("id,payment_status,stripe_checkout_session_id")
          .eq("id", bookingId)
          .maybeSingle();
        if (!b) {
          console.error(`[WEBHOOK] Tundmatu booking_id=${bookingId}`);
        } else if (
          b.stripe_checkout_session_id &&
          b.stripe_checkout_session_id !== s.id
        ) {
          console.error(`[WEBHOOK] Session mismatch: booking=${bookingId}`);
        } else if (b.payment_status !== "paid") { // idempotentne
          const pi = typeof s.payment_intent === "string"
            ? s.payment_intent
            : (s.payment_intent?.id ?? null);
          const { error } = await supabase
            .from("bookings")
            .update({
              payment_status: "paid",
              status: "paid_confirmed",
              stripe_payment_intent_id: pi,
              stripe_checkout_session_id: s.id,
              updated_at: new Date().toISOString(),
            })
            .eq("id", bookingId);
          if (error) throw error;
          console.log(
            `[WEBHOOK] booking ${bookingId} PAID (presented=${s.currency}, settled EUR)`,
          );
        }
      }
    } else if (event.type === "checkout.session.async_payment_failed") {
      const s = event.data.object as Stripe.Checkout.Session;
      console.error(
        `[WEBHOOK] Async makse ebaõnnestus: booking=${s.metadata?.booking_id}`,
      );
    }
    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[WEBHOOK] ERR:", String(e));
    return new Response("Internal error", { status: 500 }); // Stripe kordab
  }
});
