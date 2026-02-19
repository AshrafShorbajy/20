
-- Add recording_url column to bookings table
ALTER TABLE public.bookings ADD COLUMN recording_url text DEFAULT NULL;
