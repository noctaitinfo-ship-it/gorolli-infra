-- ============================================================
-- GoRolli — COUNTRY CONFIG (GLOBAL LAUNCH = ACTIVE by default)
-- Policy: GoRolli is LIVE GLOBALLY. country_config is an ADMIN OPT-OUT control,
-- NOT a default blocker. Default mode for every country = ACTIVE.
-- A paid booking is blocked ONLY by a REAL blocker:
--   * admin explicitly DISABLED the country / switched it off
--   * admin explicitly marked stripe_supported = false
--   * (payout only) missing Connect capability / host onboarding — enforced by Stripe
-- WAITLIST is informational and DOES NOT block paid bookings.
-- Run in Supabase SQL Editor as a single block. Additive + idempotent.
-- ============================================================

-- 1) Config table (admin control) --------------------------------------------
create table if not exists public.country_config (
  country_code              text primary key,                 -- ISO-3166-1 alpha-2
  country_name              text,
  currency                  text not null default 'eur',      -- ISO-4217 settlement currency

  tax_mode                  text not null default 'NONE'
    check (tax_mode in ('STRIPE_TAX','MANUAL_RATE','REVERSE_CHARGE','NONE')),
  vat_rate                  numeric(5,2) not null default 0,  -- only when tax_mode='MANUAL_RATE'

  -- Capability flags. Default TRUE (global launch). Admin sets false only on a real fail.
  stripe_supported          boolean not null default true,
  stripe_connect_supported  boolean not null default true,
  stripe_tax_supported      boolean not null default false,

  platform_fee_percent      numeric(5,2) not null default 10,

  -- Admin kill switches — DEFAULT ON (live). Admin turns OFF to disable a country.
  payments_enabled          boolean not null default true,
  payouts_enabled           boolean not null default true,
  booking_enabled           boolean not null default true,
  country_status            text not null default 'ACTIVE'
    check (country_status in ('ACTIVE','WAITLIST','DISABLED')),

  invoice_legal_note        text,
  legal_entity              text,
  updated_at                timestamptz not null default now()
);

comment on table public.country_config is
  'GoRolli per-country admin control. Default ACTIVE (global launch). Only DISABLED / switch-off / stripe_supported=false blocks paid bookings. WAITLIST does NOT block.';

-- If the table already existed with old (blocking) defaults, realign defaults:
alter table public.country_config alter column currency        set default 'eur';
alter table public.country_config alter column stripe_supported         set default true;
alter table public.country_config alter column stripe_connect_supported set default true;
alter table public.country_config alter column platform_fee_percent     set default 10;
alter table public.country_config alter column payments_enabled set default true;
alter table public.country_config alter column payouts_enabled  set default true;
alter table public.country_config alter column booking_enabled  set default true;
alter table public.country_config alter column country_status   set default 'ACTIVE';

-- keep updated_at fresh
create or replace function public.gorolli_country_config_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_country_config_touch on public.country_config;
create trigger trg_country_config_touch
  before update on public.country_config
  for each row execute function public.gorolli_country_config_touch();

-- 2) Booking gate — DEFAULT ALLOW (block only on real/admin blockers) ---------
-- No config row  -> ALLOWED (global default ACTIVE).
-- Row present     -> blocked ONLY if DISABLED / booking|payments off / stripe_supported=false.
-- WAITLIST is NOT a blocker.
create or replace function public.gorolli_country_can_take_paid_booking(p_country text)
returns boolean language sql stable as $$
  select case
    when p_country is null or btrim(p_country) = '' then true   -- unknown -> allow
    else coalesce((
      select not (
            c.country_status = 'DISABLED'
         or c.booking_enabled  = false
         or c.payments_enabled = false
         or c.stripe_supported = false
      )
      from public.country_config c
      where c.country_code = upper(p_country)
    ), true)                                                    -- no row -> allow
  end;
$$;

-- Payout gate — DEFAULT ALLOW. Block only if admin DISABLED / payouts off.
-- Real Connect capability + host onboarding is enforced by Stripe at transfer time
-- and by the host.stripe_account_id check in release-payout.
create or replace function public.gorolli_country_can_payout(p_country text)
returns boolean language sql stable as $$
  select case
    when p_country is null or btrim(p_country) = '' then true
    else coalesce((
      select not (
            c.country_status = 'DISABLED'
         or c.payouts_enabled = false
      )
      from public.country_config c
      where c.country_code = upper(p_country)
    ), true)
  end;
$$;

-- 3) Readiness view (admin dashboard) ----------------------------------------
-- NB: drop first — CREATE OR REPLACE VIEW cannot reorder/rename columns (42P16).
drop view if exists public.country_payment_readiness;
create view public.country_payment_readiness as
select
  country_code, country_name, currency, country_status, tax_mode, platform_fee_percent,
  public.gorolli_country_can_take_paid_booking(country_code) as can_take_paid_booking,
  public.gorolli_country_can_payout(country_code)            as can_payout,
  payments_enabled, payouts_enabled, booking_enabled,
  stripe_supported, stripe_connect_supported, stripe_tax_supported,
  invoice_legal_note, legal_entity, updated_at
from public.country_config
order by country_status, country_code;

-- 4) RLS — public read; writes via service role / admin only ------------------
alter table public.country_config enable row level security;
drop policy if exists country_config_read on public.country_config;
create policy country_config_read on public.country_config for select using (true);

-- 5) Launch seed — ALL ACTIVE (idempotent; re-running fixes DE etc. to ACTIVE)
-- Currencies are ISO-4217 facts. Capability flags default true; admin opts out per fail.
insert into public.country_config (country_code, country_name, currency) values
  ('EE','Estonia','eur'),       ('DE','Germany','eur'),       ('FR','France','eur'),
  ('IT','Italy','eur'),         ('ES','Spain','eur'),         ('NL','Netherlands','eur'),
  ('BE','Belgium','eur'),       ('AT','Austria','eur'),       ('IE','Ireland','eur'),
  ('PT','Portugal','eur'),      ('FI','Finland','eur'),       ('LU','Luxembourg','eur'),
  ('GR','Greece','eur'),        ('SK','Slovakia','eur'),      ('SI','Slovenia','eur'),
  ('LV','Latvia','eur'),        ('LT','Lithuania','eur'),     ('CY','Cyprus','eur'),
  ('MT','Malta','eur'),         ('HR','Croatia','eur'),
  ('GB','United Kingdom','gbp'),('SE','Sweden','sek'),        ('DK','Denmark','dkk'),
  ('NO','Norway','nok'),        ('PL','Poland','pln'),        ('CZ','Czechia','czk'),
  ('HU','Hungary','huf'),       ('RO','Romania','ron'),       ('BG','Bulgaria','bgn'),
  ('CH','Switzerland','chf'),
  ('US','United States','usd'), ('CA','Canada','cad'),        ('MX','Mexico','mxn'),
  ('BR','Brazil','brl'),
  ('AU','Australia','aud'),     ('NZ','New Zealand','nzd'),    ('JP','Japan','jpy'),
  ('SG','Singapore','sgd'),     ('HK','Hong Kong','hkd'),      ('MY','Malaysia','myr'),
  ('TH','Thailand','thb'),      ('IN','India','inr'),         ('AE','United Arab Emirates','aed')
on conflict (country_code) do update
  set country_name   = excluded.country_name,
      currency       = excluded.currency,
      country_status = 'ACTIVE',          -- force ACTIVE (removes any prior WAITLIST/DISABLED)
      booking_enabled  = true,
      payments_enabled = true,
      payouts_enabled  = true,
      stripe_supported = true,
      stripe_connect_supported = true,
      updated_at = now();

-- CHECK:
-- select * from public.country_payment_readiness order by country_code;
-- select public.gorolli_country_c