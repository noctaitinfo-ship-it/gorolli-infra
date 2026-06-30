-- GoRolli — Avalik (guest) kaardi-feed. Anon näeb AINULT seda view'd,
-- mitte kogu trailers-tabelit. Ei lekita hosti kontakte/aadressi/dokumente.
-- Koordinaadid HÄGUSTATUD (~1 km), et täpset parkimiskohta ei näeks.
-- Jooksuta Supabase SQL Editoris.
-- ----------------------------------------------------------------------------

drop view if exists public.public_trailers_map;

create view public.public_trailers_map as
select
  t.id,
  t.trailername,
  t.model,
  t.trailer_type,
  t.thumbnail,                              -- kaanepilt (avalik)
  t.photos,                                 -- galerii pildid (klient kerib) — ÄRA EEMALDA
  t.main_category,                          -- kliendi kategooria-filter — ÄRA EEMALDA
  t.subtype,                                -- kliendi alamkategooria-filter — ÄRA EEMALDA
  t.is_available,
  t.delivery_available,
  t.verified,                               -- turvaline-märk
  t.insurance_status,                       -- kindlustus (approved = roheline)
  t.description,                            -- host'i sõnum/selgitus (info-ikoon)
  t.capacity_kg,                            -- lubatud kaal (spets)
  t.dimensions_m,                           -- mõõt (spets)
  -- HÄGUSTAMINE: ümarda 2 kohani (~1.1 km) — täpne koht jääb varjatuks
  round(t.latitude::numeric, 2)::float8  as latitude,
  round(t.longitude::numeric, 2)::float8 as longitude,
  -- hind "alates" (avalik, pricing_profiles-st)
  coalesce(pp.currency, t.currency, 'EUR') as currency,
  pp.short_rental_price,
  pp.daily_rate,
  pp.weekly_rate,
  pp.monthly_rate,
  t.price_per_hr
from public.trailers t
left join public.pricing_profiles pp
       on pp.trailer_id = t.id and pp.is_active = true
where lower(coalesce(t.status, '')) = 'active'
  and coalesce(t.is_available, false) = true
  -- BOLT-STIIL: näita AINULT praegu vabu. Peida haagis, kui tal käib PRAEGU
  -- rent (kinnitatud/töös broneering, mille aken sisaldab praegust hetke).
  -- Tuleviku-broneeringud EI peida — haagis kaob ainult oma rendiaja ajaks.
  and not exists (
    select 1
    from public.bookings b
    where b.trailer_id = t.id
      and lower(coalesce(b.status, '')) in ('paid_confirmed', 'in_progress')
      and b.start_at <= now()
      and b.end_at   >  now()
  );

-- Anon (guest) ja sisselogi