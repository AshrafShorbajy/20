
-- 1. Remove duplicate triggers (keep only the specific ones)
DROP TRIGGER IF EXISTS push_notify_booking ON public.bookings;
DROP TRIGGER IF EXISTS push_notify_message ON public.messages;
DROP TRIGGER IF EXISTS push_notify_invoice ON public.invoices;

-- 2. Clean up duplicate push subscriptions (keep only the latest per endpoint)
DELETE FROM public.push_subscriptions a
USING public.push_subscriptions b
WHERE a.endpoint = b.endpoint
  AND a.created_at < b.created_at;

-- 3. Add unique constraint on endpoint to prevent future duplicates
ALTER TABLE public.push_subscriptions 
  DROP CONSTRAINT IF EXISTS push_subscriptions_endpoint_key;
ALTER TABLE public.push_subscriptions 
  ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);
