
-- Fix the overly permissive INSERT policy - only allow the trigger function (security definer) to insert
DROP POLICY "System inserts notifications" ON public.notifications;

-- No direct INSERT policy needed since create_notification() is SECURITY DEFINER
-- Users should not be able to insert notifications directly
