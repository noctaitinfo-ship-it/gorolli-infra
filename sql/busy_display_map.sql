-- ============================================================
-- GoRolli — HÕIVATUD-KUVA (busy display) avalikul kaardil
-- 2026-07-06. Käivita Supabase SQL Editoris PÄRAST kliendi deploy'd!
-- (vana klient näitaks busy-ridu broneeritavana — deploy järjekord oluline)
-- * trailers.busy_display=true rida PAISTAB kaardil, is_busy=true,
--   klient kuvab '· Hõivatud' ja broneerimine on blokeeritud (kliendi guard).
-- * Senine käitumine vabadele haagistele EI muutu (päris rendil olev
--   haagis peitub endiselt oma rendiaja ajaks — Bolt-stiil).
-- ============================================================
alter table public.trailers
  add column if not exists busy_display       boolean not null default false,
  add column if not exists starter_expires_at timestamptz;

drop view if exists public.public_trailers_map;

create view public.public_trailers_map as
select
  t.id,
  t.trailername,
  t.model,
  t.trailer_type,
  t.thumbnail,
  t.photos,
  t.main_category,
  t.subtype,
  t.is_available,
  t.delivery_available,
  t.verified,
  t.insurance_status,
  t.description,
  t.capacity_kg,
  t.dimensions_m,
  round(t.latitude::numeric, 2)::float8  as latitude,
  round(t.longitude::numeric, 2)::float8 as longitude,
  coalesce(pp.currency, t.currency, 'EUR') as currency,
  pp.short_rental_price,
  pp.daily_rate,
  pp.weekly_rate,
  pp.monthly_rate,
  t.price_per_hr,
  -- HÕIVATUD-lipp kliendile: busy_display rida, mis pole saadaval
  (coalesce(t.busy_display,false) and not coalesce(t.is_available,false)) as is_busy
from public.trailers t
left join public.pricing_profiles pp
       on pp.trailer_id = t.id and pp.is_active = true
where lower(coalesce(t.status, '')) = 'active'
  and (
    ( coalesce(t.is_available, false) = true
      and not exists (
        select 1 from public.bookings b
        where b.trailer_id = t.id
          and lower(coalesce(b.status, '')) in ('paid_confirmed', 'in_progress')
          and b.start_at <= now()
          and b.end_at   >  now())
    )
    or (coalesce(t.busy_display,false) = true and coalesce(t.is_available,false) = false)
  );

grant select on public.public_trailers_map to anon, authenticated;

-- KONTROLL:
-- select column_name from information_schema.columns
--  where table_name='public_trailers_map' and column_name='is_busy';   -- 1 rida
-- select count(*) filter (where is_busy) as hoivatud, count(*) as kokku
--   from public.public_trailers_map;
