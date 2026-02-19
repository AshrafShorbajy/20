
-- Table to store push notification subscriptions
CREATE TABLE public.push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  endpoint text NOT NULL,
  p256dh text NOT NULL,
  auth text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(user_id, endpoint)
);

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own subscriptions"
ON public.push_subscriptions
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can read all subscriptions"
ON public.push_subscriptions
FOR SELECT
USING (true);

-- Enable pg_net extension for calling edge functions from triggers
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Function to send push notification via edge function
CREATE OR REPLACE FUNCTION public.notify_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _payload jsonb;
  _supabase_url text;
  _anon_key text;
BEGIN
  _supabase_url := current_setting('app.settings.supabase_url', true);
  _anon_key := current_setting('app.settings.supabase_anon_key', true);

  -- Build payload based on table and event
  IF TG_TABLE_NAME = 'bookings' THEN
    IF TG_OP = 'INSERT' THEN
      -- New booking: notify teacher
      _payload := jsonb_build_object(
        'type', 'new_booking',
        'user_id', NEW.teacher_id,
        'title', 'طلب حصة جديد',
        'body', 'لديك طلب حصة جديد في انتظار الموافقة'
      );
    ELSIF TG_OP = 'UPDATE' THEN
      -- Booking accepted: notify student
      IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted' THEN
        _payload := jsonb_build_object(
          'type', 'booking_accepted',
          'user_id', NEW.student_id,
          'title', 'تم قبول حصتك',
          'body', 'تم قبول طلب الحصة الخاص بك'
        );
      ELSIF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'scheduled' THEN
        _payload := jsonb_build_object(
          'type', 'booking_scheduled',
          'user_id', NEW.student_id,
          'title', 'تم جدولة حصتك',
          'body', 'تم تحديد موعد الحصة، تحقق من جدولك'
        );
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'messages' THEN
    IF TG_OP = 'INSERT' THEN
      -- New message: notify the other participant
      _payload := jsonb_build_object(
        'type', 'new_message',
        'sender_id', NEW.sender_id,
        'conversation_id', NEW.conversation_id,
        'title', 'رسالة جديدة',
        'body', LEFT(NEW.content, 50)
      );
    END IF;
  ELSIF TG_TABLE_NAME = 'invoices' THEN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'paid' THEN
      -- Invoice approved: notify student and teacher
      _payload := jsonb_build_object(
        'type', 'invoice_approved',
        'student_id', NEW.student_id,
        'teacher_id', NEW.teacher_id,
        'title', 'تم اعتماد الدفع',
        'body', 'تم اعتماد الفاتورة من الإدارة'
      );
    END IF;
  END IF;

  -- Only proceed if we have a payload
  IF _payload IS NOT NULL THEN
    PERFORM extensions.http((
      'POST',
      'https://osclbwdiaulpswftonkz.supabase.co/functions/v1/send-push-notification',
      ARRAY[
        extensions.http_header('Content-Type', 'application/json'),
        extensions.http_header('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9zY2xid2RpYXVscHN3ZnRvbmt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4MDU2MTcsImV4cCI6MjA4NjM4MTYxN30.3UAy64Mv3U5Z3ugjCnBDDPFPPLikRVTMZVMYfvLTgqY')
      ],
      'application/json',
      _payload::text
    )::extensions.http_request);
  END IF;

  RETURN NEW;
END;
$$;

-- Triggers
CREATE TRIGGER push_notify_booking
AFTER INSERT OR UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.notify_push();

CREATE TRIGGER push_notify_message
AFTER INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.notify_push();

CREATE TRIGGER push_notify_invoice
AFTER UPDATE ON public.invoices
FOR EACH ROW EXECUTE FUNCTION public.notify_push();
