CREATE OR REPLACE FUNCTION public.notify_push()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _payload jsonb;
BEGIN
  -- Build payload based on table and event
  IF TG_TABLE_NAME = 'bookings' THEN
    IF TG_OP = 'INSERT' THEN
      _payload := jsonb_build_object(
        'type', 'new_booking',
        'user_id', NEW.teacher_id,
        'title', 'طلب حصة جديد',
        'body', 'لديك طلب حصة جديد في انتظار الموافقة'
      );
    ELSIF TG_OP = 'UPDATE' THEN
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
    BEGIN
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
    EXCEPTION WHEN OTHERS THEN
      -- Log but don't fail the transaction
      RAISE WARNING 'Push notification failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
END;
$function$;