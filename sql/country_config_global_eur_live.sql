-- ============================================================
-- GoRolli — GLOBAL EUR LIVE (kõik 51 riiki live, AINULT EUR-maksega)
-- 2026-07-06. Käivita Supabase SQL Editoris ÜHE plokina.
-- ASENDAB country_config_46_markets.sql turustaatuse otsused (21/23/7 mudel).
-- Idempotentne + iseseisev: sisaldab samu additiivseid veerulisandusi,
-- st töötab nii pärast 46_markets faili kui ka ilma selleta
-- (eeldus on ainult sql/country_config.sql baastabel).
--
-- UUS ÄRIMUDEL:
--   * KÕIK 51 riiki: market_status='live', country_status='ACTIVE',
--     currency='eur' (=> generated default_currency='eur'),
--     client/host/booking/payments = true, stripe_supported = true
--   * 21 EUR-riiki: payouts_enabled=true (automaatne Connect payout)
--   * 30 mitte-EUR/kaugemat riiki: payouts_enabled=false
--     (=> generated payout_enabled=false) — host teenib ledgerisse,
--     payout käsitsi/eraldi kontrolliga; stripe_connect_supported:
--     true ainult seal, kus see JUBA teadaolevalt oli (Stripe direct);
--     false 7 extended/preview riigis (pole kindel)
--   * TUNDMATU riik = endiselt BLOCKED (default-deny) — seda jõustab
--     sql/country_gates_default_deny.sql; SEE fail EI lõdvenda seda.
--
-- MIDA SEE FAIL EI TEE (teadlikult):
--   * ei lisa kohalikke valuutasid, ei tee Stripe Checkouti ega Adaptive Pricingut
--   * ei muuda payments-authorize EUR-guardi (PaymentIntent jääb alati 'eur',
--     clienti currencyt ei usaldata — guard on juba serveris)
--   * ei muuda logineid, verifyEmaili, Cloudflare'i, pubspeci
--
-- KÄIVITUSJÄRJEKORD: 1) country_config.sql  2) SEE FAIL
--   3) country_gates_default_deny.sql  4) supabase functions deploy
--      release-payout connect-onboard
-- ============================================================

-- 1) Veerud (additiivselt; sama mis 46_markets — ohutu topelt) -------------------
alter table public.country_config
  add column if not exists market_status  text not null default 'blocked',
  add column if not exists client_enabled boolean not null default true,
  add column if not exists host_enabled   boolean not null default false,
  add column if not exists stripe_mode    text not null default 'none',
  add column if not exists notes          text;

alter table public.country_config
  add column if not exists payment_enabled  boolean generated always as (payments_enabled) stored,
  add column if not exists payout_enabled   boolean generated always as (payouts_enabled)  stored,
  add column if not exists default_currency text    generated always as (currency)          stored;

do $$ begin
  if not exists (select 1 from pg_constraint where conname='country_config_market_status_chk') then
    alter table public.country_config add constraint country_config_market_status_chk
      check (market_status in ('live','beta','blocked'));
  end if;
  if not exists (select 1 from pg_constraint where conname='country_config_stripe_mode_chk') then
    alter table public.country_config add constraint country_config_stripe_mode_chk
      check (stripe_mode in ('direct','preview','extended','none'));
  end if;
end $$;

-- 2) 51 riiki — KÕIK LIVE, KÕIK EUR ----------------------------------------------
-- Veerud: code, name, currency, market, status, client, host, booking, payments,
--         payouts, stripe_supported, connect, stripe_mode, notes
insert into public.country_config
  (country_code, country_name, currency, market_status, country_status,
   client_enabled, host_enabled, booking_enabled, payments_enabled, payouts_enabled,
   stripe_supported, stripe_connect_supported, stripe_mode, notes)
values
-- A) 21 EUR-riiki: kõik lahti, ka automaatne payout
  ('EE','Estonia','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('FI','Finland','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('LV','Latvia','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('LT','Lithuania','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('DE','Germany','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('FR','France','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('ES','Spain','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('IT','Italy','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('NL','Netherlands','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('BE','Belgium','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('AT','Austria','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('IE','Ireland','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('PT','Portugal','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('GR','Greece','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('SK','Slovakia','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('SI','Slovenia','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('HR','Croatia','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('CY','Cyprus','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('MT','Malta','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('LU','Luxembourg','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market'),
  ('BG','Bulgaria','eur','live','ACTIVE',true,true,true,true,true,true,true,'direct','EUR live market (euro alates 2026-01-01)'),
-- B) 23 Stripe-direct mitte-EUR riiki: live EUR-maksega; automaatne payout KINNI
  ('AU','Australia','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('BR','Brazil','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('CA','Canada','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('CH','Switzerland','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('CZ','Czechia','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('DK','Denmark','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('GB','United Kingdom','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('GI','Gibraltar','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('HK','Hong Kong','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('HU','Hungary','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('JP','Japan','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('LI','Liechtenstein','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('MY','Malaysia','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('MX','Mexico','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('NO','Norway','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('NZ','New Zealand','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('PL','Poland','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('RO','Romania','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('SE','Sweden','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('SG','Singapore','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('TH','Thailand','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('AE','United Arab Emirates','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('US','United States','eur','live','ACTIVE',true,true,true,true,false,true,true,'direct','Global EUR live market. Host payout requires separate verification/manual payout.'),
-- C) 7 extended/preview riiki: live EUR-maksega; payout KINNI; Connect pole kindel -> false
  ('CI','Cote d''Ivoire','eur','live','ACTIVE',true,true,true,true,false,true,false,'extended','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('GH','Ghana','eur','live','ACTIVE',true,true,true,true,false,true,false,'extended','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('IN','India','eur','live','ACTIVE',true,true,true,true,false,true,false,'preview','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('ID','Indonesia','eur','live','ACTIVE',true,true,true,true,false,true,false,'preview','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('KE','Kenya','eur','live','ACTIVE',true,true,true,true,false,true,false,'extended','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('NG','Nigeria','eur','live','ACTIVE',true,true,true,true,false,true,false,'extended','Global EUR live market. Host payout requires separate verification/manual payout.'),
  ('ZA','South Africa','eur','live','ACTIVE',true,true,true,true,false,true,false,'extended','Global EUR live market. Host payout requires separate verification/manual payout.')
on conflict (country_code) do update set
  country_name             = excluded.country_name,
  currency                 = excluded.currency,
  market_status            = excluded.market_status,
  country_status           = excluded.country_status,
  client_enabled           = excluded.client_enabled,
  host_enabled             = excluded.host_enabled,
  booking_enabled          = excluded.booking_enabled,
  payments_enabled         = excluded.payments_enabled,
  payouts_enabled          = excluded.payouts_enabled,
  stripe_supported         = excluded.stripe_supported,
  stripe_connect_supported = excluded.stripe_connect_supported,
  stripe_mode              = excluded.stripe_mode,
  notes                    = excluded.notes,
  updated_at               = now();

-- 3) Readiness-vaade (drop enne — 42P16 kaitse) -----------------------------------
drop view if exists public.country_payment_readiness;
create view public.country_payment_readiness as
select
  country_code, country_name, currency, default_currency,
  market_status, country_status, stripe_mode,
  client_enabled, host_enabled, booking_enabled,
  payments_enabled, payment_enabled, payouts_enabled, payout_enabled,
  stripe_supported, stripe_connect_supported, stripe_tax_supported,
  public.gorolli_country_can_take_paid_booking(country_code) as can_take_paid_booking,
  public.gorolli_country_can_payout(country_code)            as can_payout,
  tax_mode, platform_fee_percent, invoice_legal_note, legal_entity, notes, updated_at
from public.country_config
order by market_status, country_code;

-- 4) MIS SELLEST JÄRELDUB (koos default-deny gate'idega) ---------------------------
-- * Booking/makse: kõik 51 riiki läbivad gate'i (ACTIVE + booking + payments +
--   stripe_supported = true); makse on ALATI EUR (payments-authorize guard).
-- * Payout: release-payout laseb läbi AINULT 21 EUR-riiki (payouts_enabled=true);
--   30 riigis blokeerib -> tulu koguneb ledgerisse, payout käsitsi/eraldi kontroll.
-- * Host Stripe-onboarding (connect-onboard): vajab ACTIVE + host_enabled +
--   stripe_connect_supported -> 44 riiki saavad Connect-konto luua; 7 extended/
--   preview riigis Stripe-onboarding kinni (ainult käsitsi payout).
-- * TUNDMATU riik: country_gates_default_deny.sql blokeerib kõik
--   ("Country is not enabled yet") — käivita see fail KOHE pärast käesolevat.

-- 5) KONTROLL ----------------------------------------------------------------------
-- select count(*) from public.country_config where market_status='live';          -- 51
-- select count(*) from public.country_config where currency <> 'eur';             -- 0
-- select count(*) from public.country_payment_readiness where can_take_paid_booking; -- 51
-- select count(*) from public.country_config where payouts_enabled;               -- 21
-- select public.gorolli_country_can_take_paid_booking('US');                      -- true
-- select public.gorolli_country_can_payout('US');                                 -- false
-- select public.gorolli_country_can_take_paid_booking('XX');                      -- false (unknown -> deny)
