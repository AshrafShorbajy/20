
-- Add installment columns to bookings
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS is_installment boolean NOT NULL DEFAULT false;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS total_installments integer DEFAULT 0;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS paid_sessions integer DEFAULT 0;

-- Create course_installments table
CREATE TABLE IF NOT EXISTS public.course_installments (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.bookings(id),
  installment_number integer NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  sessions_unlocked integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  paid_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.course_installments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students view own installments" ON public.course_installments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM bookings b WHERE b.id = course_installments.booking_id AND b.student_id = auth.uid())
  );

CREATE POLICY "Students create own installments" ON public.course_installments
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM bookings b WHERE b.id = course_installments.booking_id AND b.student_id = auth.uid())
  );

CREATE POLICY "Admin manages installments" ON public.course_installments
  FOR ALL USING (has_role(auth.uid(), 'admin'::app_role));
