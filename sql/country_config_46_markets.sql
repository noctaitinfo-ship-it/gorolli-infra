-- ============================================================
-- GoRolli — COUNTRY_CONFIG 46+ MARKETS (kontrollitud rahvusvaheline valmisolek)
-- 2026-07-03. Käivita Supabase SQL Editoris ÜHE plokina, PÄRAST sql/country_config.sql.
-- Additiivne + idempotentne (võib korduvalt jooksutada).
--
-- POLIITIKA MUUDATUS: see fail ASENDAB varasema "GLOBAL LAUNCH = kõik ACTIVE"
-- seemne nende 51 riigi osas. Uus mudel: kontrollitud valmisolek —
--   live    (21 EUR-riiki)  = kõik lahti, currency 'eur'
--   beta    (23 Stripe direct mitte-EUR) = klient näeb, AGA host/booking/
--           makse/payout KINNI kuni valuuta+payout testid on tehtud
--   blocked (7 extended/preview)         = ainult nimekirjas, kõik kinni
--
-- ÜHILDUVUS (mitte midagi olemasolevat ei purune):
--   * release-payout loeb: currency, payouts_enabled, country_status  — säilivad
--   * gate-funktsioonid loevad: country_status/booking_enabled/payments_enabled/
--     stripe_supported — säilivad; staatuste vastendus:
--       live -> ACTIVE, beta -> WAITLIST, blocked -> DISABLED
--     beta blokeerub BOOLEAN-lülititest (booking/payments/payouts=false),
--     mitte WAITLIST-staatusest (WAITLIST ei blokeeri disainiti).
--   * kasutaja nõutud veerunimed payment_enabled / payout_enabled /
--     default_currency on GENERATED-peeglid (ei saa kunagi lahku minna
--     payments_enabled / payouts_enabled / currency väärtustest).
--
-- MIDA SEE FAIL EI TEE (teadlikult):
--   * ei muuda payments-authorize EUR-guardi, Stripe Checkouti, Adaptive
--     Pricingut, loginit, verifyEmaili, Cloudflare'i, pubspeci
--   * ei ava ühtegi uut valuutat maksevoogu (beta-ridade currency on
--     informatiivne KUNI admin lülitab payments_enabled=true)
-- ============================================================

-- 1) Uued veerud (additiivselt) ------------------------------------------------
alter table public.country_config
  add column if not exists market_status  text not null default 'blocked',
  add column if not exists client_enabled boolean not null default true,
  add column if not exists host_enabled   boolean not null default false,
  add column if not exists stripe_mode    text not null default 'none',
  add column if not exists notes          text;

-- Nõutud nimedega peeglid (loetavad, alati sünkroonis; kirjutada tuleb
-- endiselt payments_enabled/payouts_enabled/currency kaudu):
alter table public.country_config
  add column if not exists payment_enabled  boolean generated always as (payments_enabled) stored,
  add column if not exists payout_enabled   boolean generated always as (payouts_enabled)  stored,
  add column if not exists default_currency text    generated always as (currency)          stored;

-- CHECK-piirangud (idempotentselt)
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

-- 2) 51 riigi seeme/korrastus ----------------------------------------------------
-- LIVE — 21 EUR-riiki: kõik lahti, valuuta eur (NB: BG on alates 2026-01-01 EUR!)
insert into public.country_config
  (country_code, country_name, currency, market_status, country_status,
   client_enabled, host_enabled, booking_enabled, payments_enabled, payouts_enabled,
   stripe_supported, stripe_connect_supported, stripe_mode, notes)
values
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
-- BETA — 23 Stripe direct mitte-EUR riiki: klient näeb; host/booking/makse/payout KINNI
  ('AU','Australia','aud','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('BR','Brazil','brl','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('CA','Canada','cad','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('CH','Switzerland','chf','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('CZ','Czechia','czk','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('DK','Denmark','dkk','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('GB','United Kingdom','gbp','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('GI','Gibraltar','gip','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('HK','Hong Kong','hkd','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('HU','Hungary','huf','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('JP','Japan','jpy','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live; ZERO-DECIMAL currency'),
  ('LI','Liechtenstein','chf','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('MY','Malaysia','myr','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('MX','Mexico','mxn','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('NO','Norway','nok','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('NZ','New Zealand','nzd','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('PL','Poland','pln','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('RO','Romania','ron','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('SE','Sweden','sek','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('SG','Singapore','sgd','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('TH','Thailand','thb','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('AE','United Arab Emirates','aed','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
  ('US','United States','usd','beta','WAITLIST',true,false,false,false,false,true,true,'direct','Currency/payout tests required before live'),
-- BLOCKED/LATER — 7 extended/preview riiki: kõik kinni
  ('CI','Cote d''Ivoire','xof','blocked','DISABLED',true,false,false,false,false,false,false,'extended','Extended network — not opened; ZERO-DECIMAL currency'),
  ('GH','Ghana','ghs','blocked','DISABLED',true,false,false,false,false,false,false,'extended','Extended network — not opened'),
  ('IN','India','inr','blocked','DISABLED',true,false,false,false,false,false,false,'preview','Preview/eritingimused (ekspordipiirangud) — not opened'),
  ('ID','Indonesia','idr','blocked','DISABLED',true,false,false,false,false,false,false,'preview','Preview — not opened'),
  ('KE','Kenya','kes','blocked','DISABLED',true,false,false,false,false,false,false,'extended','Extended network — not opened'),
  ('NG','Nigeria','ngn','blocked','DISABLED',true,false,false,false,false,false,false,'extended','Extended network — not opened'),
  ('ZA','South Africa','zar','blocked','DISABLED',true,false,false,false,false,false,false,'extended','Extended network — not opened')
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

-- 3) Readiness-vaade uuendatud veergudega ---------------------------------------
-- NB: DROP on vajalik — CREATE OR REPLACE VIEW ei luba veergude järjekorda/nimesid
-- muuta (42P16). Vaade on ainult admin-dashboardi jaoks, drop on ohutu.
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

-- 4) JÕUSTAMINE (mis juba töötab / mis vajab hiljem ühendamist) -------------------
-- payment_enabled=false  -> blokeerib JUBA: gorolli_country_can_take_paid_booking()
--                           + bookings BEFORE INSERT trigger (country_gates.sql)
--                           loevad payments_enabled=false -> broneering/makse ei käivitu.
-- booking_enabled=false  -> sama gate/trigger blokeerib JUBA.
-- payout_enabled=false   -> release-payout Edge Function blokeerib JUBA
--                           (payouts_enabled=false vōi country_status='DISABLED').
-- host_enabled=false     -> UUS lipp; ühenda connect-onboard Edge Functionis ja
--                           hosti-äpi aktiveerimises (EI tehtud siin — host-äppi ei puututa).
-- client_enabled         -> informatiivne (avalik sirvimine on globaalne disainiti).
--
-- TEADLIK JÄÄKAUK (poliitika, mitte viga): gate-funktsioonid on "no row -> ALLOW".
-- Kui tahad range default-deny (tundmatu riik = blokeeritud), käivita ERALDI otsusena:
-- -- create or replace function public.gorolli_country_can_take_paid_booking(p_country text)
-- -- returns boolean language sql stable as $$
-- --   select coalesce((select not (c.country_status='DISABLED' or not c.booking_enabled
-- --     or not c.payments_enabled or not c.stripe_supported)
-- --     from public.country_config c where c.country_code=upper(p_country)), false); $$;

-- 5) KONTROLL (raporti päringud) --------------------------------------------------
-- select market_status, count(*) from public.country_config group by market_status;
--   -- oodatud: live=21, beta=23, blocked=7 (kokku 51)
-- select count(*) from public.country_config where market_status='live' and currency='eur';
--   -- oodatud: 21
-- select country_code from public.country_config
--   where market_status<>'live' and (payments_enabled or booking