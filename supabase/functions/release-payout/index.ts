// GoRolli — Host väljamakse (Stripe Connect Transfer).
// Kutsutakse pg_cron'iga {run_due:true} (kõik maksevalmis broneeringud) VÕI
// käsitsi {booking_id: N}. Kannab host_payout_amount hosti ühendatud kontole.
// Deploy: supabase functions deploy release-payout
// Vajab secret'e: STRIPE_SECRET_KEY.
import Stripe from 'https://esm.sh/stripe@14?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2024-06-20',
});
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}));
    let bookings: any[] = [];

    if (body.run_due) {
      const { data } = await supabase
        .from('bookings')
        .select('id, host_uid, host_payout_amount, payout_status, status, currency')
        .eq('status', 'completed')
        .eq('payout_status', 'pending')
        .lte('payout_due_at', new Date().toISOString());
      bookings = data ?? [];
    } else if (body.booking_id) {
      const { data } = await supabase
        .from('bookings')
        .select('id, host_uid, host_payout_amount, payout_status, status, currency')
        .eq('id', body.booking_id)
        .maybeSingle();
      if (data) bookings = [data];
    }

    const results: any[] = [];
    for (const b of bookings) {
      if (b.payout_status === 'paid') {
        results.push({ id: b.id, skipped: 'already paid' });
        continue;
      }
      const amount = Math.round(Number(b.host_payout_amount ?? 0) * 100);
      if (amount <= 0) {
        results.push({ id: b.id, skipped: 'no amount' });
        continue;
      }
      const { data: host } = await supabase
        .from('hosts')
        .select('stripe_account_id, payouts_enabled, country_code')
        .eq('host_uid', b.host_uid)
        .maybeSingle();
      if (!host?.stripe_account_id) {
        results.push({ id: b.id, error: 'host has no connected account' });
        continue;
      }
      // OPEN ALL (2026-07-06): default ALLOW — automaatne arveldus igal pool.
      // Blokeerime AINULT admini selge keeluga riigi (DISABLED / payouts off).
      // Tundmatu riik -> proovime; päris võimekuse otsustab host.stripe_account_id
      // kontroll üleval + Stripe ise transfer-hetkel.
      // Currency: country_config -> booking currency -> platform default 'eur'.
      const country = (host.country_code ?? '').toString().toUpperCase();
      const { data: cfg } = await supabase
        .from('country_config')
        .select('currency, payouts_enabled, country_status')
        .eq('country_code', country)
        .maybeSingle();
      if (cfg && (cfg.country_status === 'DISABLED' || cfg.payouts_enabled === false)) {
        results.push({ id: b.id, error: `payouts disabled by admin for country ${country}` });
        continue;
      }
      const payoutCurrency = (cfg?.currency ?? b.currency ?? 'eur').toString().toLowerCase();
      try {
        const transfer = await stripe.transfers.create({
          amount,
          currency: payoutCurrency,
          destination: host.stripe_account_id,
          transfer_group: `booking_${b.id}`,
          metadata: { booking_id: String(b.id), host_uid: b.host_uid },
        });
        await supabase
          .from('bookings')
          .update({ payout_status: 'paid', payout_transfer_id: transfer.id })
          .eq('id', b.id);
        // host_payouts logi (kui tabel/veerud sobivad; ei katkesta vea korral)
        await supabase.from('host_payouts').insert({
          host_uid: b.host_uid,
          booking_id: b.id,
          amount: Number(b.host_payout_amount),
          status: 'paid',
          transfer_id: transfer.id,
          created_at: new Date().toISOString(),
        });
        results.push({ id: b.id, transfer: transfer.id });
      } catch (e) {
        await supabase
          .from('bookings')
          .update({ payout_status: 'failed' })
          .eq('id', b.id);
        results.push({ id: b.id, error: String(e) });
      }
    }
    return json({ processed: results.length, results });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
