-- Drop the unique constraint on booking_id to allow multiple invoices per booking (for installment payments)
ALTER TABLE public.invoices DROP CONSTRAINT IF EXISTS invoices_booking_id_key;