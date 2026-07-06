-- ============================================================
-- GoRolli — STRIPE CHECKOUT MIGRATSIOON (Adaptive Pricing)
-- 2026-07-06. Käivita Supabase SQL Editoris. Additiivne + idempotentne.
-- Klient maksab Checkoutis OMA valuutas (Adaptive Pricing); baashind,
-- settlement ja GoRolli ledger jäävad EUR-i (bookings.total_price/currency
-- EI muutu). payments-authorize EUR-guard jääb fallback-voole alles.
-- ============================================================
alter table public.bookings
  add column if not exists stripe_checkout_session_id text;

create index if not exists idx_bookings_checkout_session
  on public.bookings (stripe_checkout_session_id);

comment on column public.bookings.stripe_checkout_session_id is
  'Stripe Checkout Session id (payments-checkout loob; payments-webhook verifitseerib kahesuunaliselt)';

-- KASUTUSELEVÕTT (järjekorras):
-- 1) SEE FAIL (lisab veeru)
-- 2) supabase functions deploy payments-checkout
-- 3) supabase functions deploy payments-webhook --no-verify-jwt
-- 4) Supabase Edge secrets: STRIPE_WEBHOOK_SECRET (webhook endpointi signing secret)
-- 5) Stripe Dashboard → Developers → Webhooks → Add endpoint:
--    https://xuyoyaoxesnxxspixvdv.supabase.co/functions/v1/payments-webhook
--    events: checkout.session.completed, checkout.session.async_payment_succeeded,
--            checkout.session.async_payment_failed
-- 6) Stripe Dashboard → Adaptive Pricing → ENABLE (muidu kuvab Checkout EUR-i)
