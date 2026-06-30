-- GoRolli — PARANDUS: klient ei saa enam pilte kerida (galerii näitas ainult 1 pilti).
-- PÕHJUS: avalik view `public_trailers_map` loodi uuesti failist
--         `public_trailers_map_feed.sql`, kus PUUDUS veerg `t.photos`
--         (ja ka `main_category`, `subtype`). Ilma `photos`-massiivita langeb
--         klient tagasi ühele `thumbnail`-pildile → PageView'l on 1 element →
--         keramiseks pole midagi (sellepärast kadusid ka punktid pildi all).
--
-- LAHENDUS: loo view uuesti TÄPSELT senise käitumisega (privaatsus-hägu ~1 km +
--           Bolt-stiilis "peida praegu rendil olev haagis"), LISADES tagasi
--           AINULT 3 kliendi vajatud veergu: photos, main_category, subtype.
--           Dart-koodi EI muudeta — see on korras.
--
-- Jooksuta Supabase SQL Editoris. EI kustuta ühtegi haagist ega broneeringut.
-- ----------------------------------------------------------------------------

drop view if exists public.public_trailers_map;

create view public.public_trailers_map as
select
  t.id,
  t.trailername,
  t.model,
  t.trailer_type,
  t.thumbnail,                              -- kaanepilt (avalik)
  t.photos,                                 -- <<< TAGASI: galerii pildid (4 vaikimisi) — keramiseks
  t.main_category,                          -- <<< TAGASI: kliendi kategooria-filter
  t.subtype,                                -- <<< TAGASI: kliendi alamkategooria-filter
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

-- Anon (guest) ja sisselogitud tohivad lugeda AINULT seda view'd.
grant select on public.public_trailers_map to anon, authenticated;

-- ----------------------------------------------------------------------------
-- KONTROLL 1 — veerg `photos` on nüüd feed'is olemas:
--   select column_name from information_schema.columns
--   where table_name = 'public_trailers_map' and column_name = 'photos';
--
-- KONTROLL 2 — mitmel live-haagisel on >1 pilt (peaks kerima):
--   select id, trailername, jsonb_array_length(to_jsonb(photos)) as pilte
--   from public.public_trailers_map
--   order by pilte desc nulls last;
-- ----------------------------------------------------------------------------
