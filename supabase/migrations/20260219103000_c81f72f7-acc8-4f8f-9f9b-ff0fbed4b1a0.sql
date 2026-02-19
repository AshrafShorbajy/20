-- Monthly expenses tracking for platform accounting
CREATE TABLE public.monthly_expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_month TEXT NOT NULL, -- YYYY-MM
  name TEXT NOT NULL,
  status TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_monthly_expenses_period_month ON public.monthly_expenses(period_month);

ALTER TABLE public.monthly_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage monthly expenses" ON public.monthly_expenses
FOR ALL USING (has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins insert monthly expenses" ON public.monthly_expenses
FOR INSERT WITH CHECK (has_role(auth.uid(), 'admin'));

CREATE TRIGGER update_monthly_expenses_updated_at
  BEFORE UPDATE ON public.monthly_expenses
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();
