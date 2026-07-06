-- GoRolli — poe-lingid versiooniväravale (täidab android_url'id)
-- Eeldus: sql/app_version_config.sql on käivitatud (tabel olemas).
-- min_build/force_update EI muudeta — kedagi ei sunnita enne, kui sina tõstad.
insert into public.app_version_config
  (app, min_build, latest_build, force_update, android_url)
values
  ('client', 0, 0, false,
   'https://play.google.com/store/apps/details?id=com.mycompany.Hotelio'),
  ('host', 0, 16, false,
   'https://play.google.com/store/apps/details?id=com.mycompany.gorollihostapp')
on conflict (app) do update set
  android_url = excluded.android_url,
  updated_at  = now();

-- iOS: täida siis, kui äpp on App Store'is live (numbriline id!):
-- update public.app_version_config set ios_url='https://apps.apple.com/app/id123456789' where app='client';
-- update public.app_version_config set ios_url='https://apps.apple.com/app/id987654321' where app='host';

-- KASUTUS TULEVIKUS (iga uue väljalaske järel):
--   pehme soovitus:  update public.app_version_config set min_build=<uus>, latest_build=<uus>, force_update=false where app='client';
--   KOHUSTUSLIK:     update public.app_version_config set min_build=<uus>, latest_build=<uus>, force_update=true  where app='client';
-- (min_build tõstmine saadab automaatselt ka push-teate — broadcast-update trigger)
select app, min_build, force_update, android_url, ios_url from public.app_version_config;
