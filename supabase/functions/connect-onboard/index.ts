// GoRolli — Stripe Connect host onboarding (Express).
// Loob hostile ühendatud Stripe-konto (kui pole) ja tagastab onboarding-URL-i.
// Deploy: supabase functions deploy connect-onboard
// Vajab secret'e: STRIPE_SECRET_KEY (Supabase Edge Function secrets).
import Stripe from 'https://esm.sh/stripe@14?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
});
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// CORS — veebist (brauserist) kutsudes KOHUSTUSLIK. Ilma selleta blokeerib
// brauser POST-i ja host.gorolli.com "hangub" + viskab vea. Natiivis (mobiil)
// CORS-i pole, seepärast seal töötab ka ilma.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  // Brauser saadab enne POST-i OPTIONS preflight'i — vasta sellele CORS-iga.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const {
      host_uid, host_email, host_name, host_phone, return_url, refresh_url,
      country: bodyCountry,
    } = await req.json();
    if (!host_uid) return json({ error: 'host_uid required' }, 400);

    const { data: host } = await supabase
      .from('hosts')
      .select('id, host_uid, stripe_account_id, full_name, phone_number, country_code')
      .eq('host_uid', host_uid)
      .maybeSingle();
    if (!host) return json({ error: 'host not found' }, 404);

    // Riik tuleb hostilt / päringust — MITTE kõvakodeeritud 'EE'.
    const country = ((bodyCountry ?? host.country_code ?? '') as string)
      .trim().toUpperCase();
    if (!country) {
      return json({ error: 'country required (host has no country_code)' }, 400);
    }
    // OPEN ALL (2026-07-06): default ALLOW. Blokeerime ainult admini selge
    // keeluga riigi (DISABLED / host_enabled=false / connect=false).
    // Tundmatu riik -> proovime; Stripe ise lükkab toetuseta riigi tagasi
    // konto loomisel (see ongi päris tehniline piir).
    const { data: cfg } = await supabase
      .from('country_config')
      .select('stripe_connect_supported, country_status, host_enabled')
      .eq('country_code', country)
      .maybeSingle();
    if (cfg && (cfg.country_status === 'DISABLED' || cfg.host_enabled === false ||
        cfg.stripe_connect_supported === false)) {
      return json({ error: `Country ${country} is disabled for payouts by admin` }, 400);
    }
    // Persisti hosti riik kui veel puudub.
    if (!host.country_code) {
      await supabase.from('hosts')
        .update({ country_code: country }).eq('host_uid', host_uid);
    }

    const email = (host_email ?? '').toString().trim() || undefined;
    const fullName = ((host_name ?? host.full_name ?? '') as string).trim();
    const firstName = fullName ? fullName.split(' ')[0] : undefined;
    const lastName = fullName && fullName.includes(' ')
      ? fullName.substring(fullName.indexOf(' ') + 1)
      : undefined;
    const phone = ((host_phone ?? host.phone_number ?? '') as string).trim() || undefined;

    let accountId = host.stripe_account_id as string | null;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        country,
        email,
        business_type: 'individual',
        capabilities: { transfers: { requested: true } },
        business_profile: {
          product_description: 'Haagise rent GoRolli platvormil',
          url: 'https://gorolli.app',
        },
        individual: {
          email,
          first_name: firstName,
          last_name: lastName,
          phone,
        },
        metadata: { host_uid },
      });
      accountId = account.id;
      await supabase
        .from('hosts')
        .update({ stripe_account_id: accountId })
        .eq('host_uid', host_uid);
    }

    // Kontrolli, kas konto on JUBA onboarditud — siis ära ava uuesti (loop).
    const acct = await stripe.accounts.retrieve(accountId);
    await supabase
      .from('hosts')
      .update({ payouts_enabled: acct.payouts_enabled ?? false })
      .eq('host_uid', host_uid);

    const reqDue =
      ((acct.requirements?.currently_due?.length ?? 0) > 0) ||
      ((acct.requirements?.past_due?.length ?? 0) > 0);

    // JUBA ÜHENDATUD: payouts lubatud VÕI andmed esitatud ja midagi pole puudu.
    // Sel juhul EI loo uut kontot ega onboarding-linki.
    if (acct.payouts_enabled === true ||
        (acct.details_submitted === true && !reqDue)) {
      return json({
        already_onboarded: true,
        payouts_enabled: acct.payouts_enabled ?? false,
        account_id: accountId,
      });
    }

    // Konto on OLEMAS, aga nõuded puudu → uus onboarding-link SAMALE kontole
    // (accountId ei muutu; uut kontot ei looda).
    const link = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: refresh_url ?? 'https://gorolli.app/payouts/refresh',
      return_url: return_url ?? 'https://gorolli.app/payouts/done',
      type: 'account_onboarding',
    });

    return json({
      url: link.url,
      account_id: accountId,
      payouts_enabled: acct.payouts_enabled ?? false,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
