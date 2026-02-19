
-- Create invoice status enum
CREATE TYPE public.invoice_status AS ENUM ('pending', 'paid', 'rejected');

-- Create invoices table
CREATE TABLE public.invoices (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES public.bookings(id),
  student_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  lesson_id UUID NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  payment_method TEXT,
  payment_receipt_url TEXT,
  status public.invoice_status NOT NULL DEFAULT 'pending',
  admin_notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(booking_id)
);

-- Enable RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Admin can do everything
CREATE POLICY "Admin manages invoices"
  ON public.invoices FOR ALL
  USING (has_role(auth.uid(), 'admin'));

-- Students can view their own invoices
CREATE POLICY "Students view own invoices"
  ON public.invoices FOR SELECT
  USING (auth.uid() = student_id);

-- Teachers can view invoices for their bookings (only paid ones)
CREATE POLICY "Teachers view paid invoices"
  ON public.invoices FOR SELECT
  USING (auth.uid() = teacher_id AND status = 'paid');

-- Trigger for updated_at
CREATE TRIGGER update_invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();
