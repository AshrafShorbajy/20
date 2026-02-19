-- Create recordings storage bucket (public for streaming, RLS controls access)
INSERT INTO storage.buckets (id, name, public) VALUES ('recordings', 'recordings', true)
ON CONFLICT (id) DO NOTHING;

-- Teachers can upload recordings to their own folder
CREATE POLICY "Teachers upload recordings"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'recordings' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND has_role(auth.uid(), 'teacher'::app_role)
);

-- Teachers can update their own recordings
CREATE POLICY "Teachers update recordings"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'recordings' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND has_role(auth.uid(), 'teacher'::app_role)
);

-- Anyone authenticated can view recordings (streaming)
CREATE POLICY "Authenticated users view recordings"
ON storage.objects FOR SELECT
USING (bucket_id = 'recordings' AND auth.role() = 'authenticated');

-- Teachers can delete their own recordings
CREATE POLICY "Teachers delete recordings"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'recordings' 
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND has_role(auth.uid(), 'teacher'::app_role)
);