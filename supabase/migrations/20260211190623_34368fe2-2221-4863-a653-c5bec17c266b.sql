
-- Add booking_id to conversations to link chat to specific bookings
ALTER TABLE public.conversations ADD COLUMN booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX idx_conversations_booking_id ON public.conversations(booking_id);
