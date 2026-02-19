
-- Allow students to insert their own invoices (auto-created on booking)
CREATE POLICY "Students create own invoices"
  ON public.invoices FOR INSERT
  WITH CHECK (auth.uid() = student_id);
