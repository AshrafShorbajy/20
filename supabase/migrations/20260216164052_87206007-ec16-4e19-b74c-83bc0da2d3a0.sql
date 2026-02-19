
-- Add image_url column to messages table for image attachments
ALTER TABLE public.messages ADD COLUMN image_url text DEFAULT NULL;
