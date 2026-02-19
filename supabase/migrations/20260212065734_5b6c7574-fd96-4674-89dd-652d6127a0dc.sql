
-- Create accounting_records table to track profit splits
CREATE TABLE public.accounting_records (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES public.bookings(id),
  lesson_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  student_id UUID NOT NULL,
  total_amount NUMERIC NOT NULL DEFAULT 0,
  commission_rate NUMERIC NOT NULL DEFAULT 0,
  platform_share NUMERIC NOT NULL DEFAULT 0,
  teacher_share NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(booking_id)
);

-- Enable RLS
ALTER TABLE public.accounting_records ENABLE ROW LEVEL SECURITY;

-- Teachers can view their own records
CREATE POLICY "Teachers view own accounting" ON public.accounting_records
FOR SELECT USING (auth.uid() = teacher_id);

-- Admins can view all records
CREATE POLICY "Admins manage accounting" ON public.accounting_records
FOR ALL USING (has_role(auth.uid(), 'admin'));

-- Admins can insert records (when completing bookings)
CREATE POLICY "System inserts accounting" ON public.accounting_records
FOR INSERT WITH CHECK (
  has_role(auth.uid(), 'admin') OR auth.uid() = teacher_id
);

-- Trigger for updated_at
CREATE TRIGGER update_accounting_records_updated_at
  BEFORE UPDATE ON public.accounting_records
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();
