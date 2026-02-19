
-- Create notifications table
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  type text NOT NULL,
  title text NOT NULL,
  body text,
  is_read boolean NOT NULL DEFAULT false,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Users can view their own notifications
CREATE POLICY "Users view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update (mark read) their own notifications
CREATE POLICY "Users update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- System/triggers insert notifications (via security definer function)
CREATE POLICY "System inserts notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

-- Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- Create function to insert notifications
CREATE OR REPLACE FUNCTION public.create_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_TABLE_NAME = 'bookings' THEN
    IF TG_OP = 'INSERT' THEN
      -- Notify teacher about new booking
      INSERT INTO public.notifications (user_id, type, title, body, metadata)
      VALUES (NEW.teacher_id, 'booking', 'طلب حصة جديد', 'لديك طلب حصة جديد في انتظار الموافقة',
        jsonb_build_object('booking_id', NEW.id));
    ELSIF TG_OP = 'UPDATE' THEN
      IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'accepted' THEN
          INSERT INTO public.notifications (user_id, type, title, body, metadata)
          VALUES (NEW.student_id, 'booking', 'تم قبول حصتك', 'تم قبول طلب الحصة الخاص بك، يمكنك بدء المحادثة مع المعلم',
            jsonb_build_object('booking_id', NEW.id));
        ELSIF NEW.status = 'scheduled' THEN
          INSERT INTO public.notifications (user_id, type, title, body, metadata)
          VALUES (NEW.student_id, 'booking', 'تم جدولة حصتك', 'تم تحديد موعد الحصة، تحقق من جدولك',
            jsonb_build_object('booking_id', NEW.id));
        ELSIF NEW.status = 'completed' THEN
          INSERT INTO public.notifications (user_id, type, title, body, metadata)
          VALUES (NEW.student_id, 'booking', 'تم إكمال الحصة', 'تم إكمال الحصة بنجاح',
            jsonb_build_object('booking_id', NEW.id));
        ELSIF NEW.status = 'cancelled' THEN
          INSERT INTO public.notifications (user_id, type, title, body, metadata)
          VALUES (NEW.student_id, 'booking', 'تم إلغاء الحصة', 'تم إلغاء الحصة',
            jsonb_build_object('booking_id', NEW.id));
        END IF;
      END IF;
    END IF;
  ELSIF TG_TABLE_NAME = 'messages' THEN
    IF TG_OP = 'INSERT' THEN
      -- Find the other participant in the conversation
      DECLARE
        _conv record;
        _recipient_id uuid;
      BEGIN
        SELECT student_id, teacher_id INTO _conv
        FROM public.conversations WHERE id = NEW.conversation_id;
        
        IF _conv.student_id = NEW.sender_id THEN
          _recipient_id := _conv.teacher_id;
        ELSE
          _recipient_id := _conv.student_id;
        END IF;
        
        INSERT INTO public.notifications (user_id, type, title, body, metadata)
        VALUES (_recipient_id, 'message', 'رسالة جديدة', LEFT(NEW.content, 50),
          jsonb_build_object('conversation_id', NEW.conversation_id));
      END;
    END IF;
  ELSIF TG_TABLE_NAME = 'invoices' THEN
    IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'paid' THEN
      INSERT INTO public.notifications (user_id, type, title, body, metadata)
      VALUES (NEW.student_id, 'booking', 'تم اعتماد الدفع', 'تم اعتماد الفاتورة من الإدارة',
        jsonb_build_object('invoice_id', NEW.id));
      INSERT INTO public.notifications (user_id, type, title, body, metadata)
      VALUES (NEW.teacher_id, 'booking', 'تم اعتماد الدفع', 'تم اعتماد فاتورة جديدة',
        jsonb_build_object('invoice_id', NEW.id));
    END IF;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'create_notification failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Create triggers using the new function
CREATE TRIGGER notif_on_booking_insert
  AFTER INSERT ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

CREATE TRIGGER notif_on_booking_update
  AFTER UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

CREATE TRIGGER notif_on_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();

CREATE TRIGGER notif_on_invoice_update
  AFTER UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.create_notification();
