
ALTER TABLE public.group_session_schedules
  ADD COLUMN status text NOT NULL DEFAULT 'pending',
  ADD COLUMN zoom_meeting_id text,
  ADD COLUMN zoom_join_url text,
  ADD COLUMN zoom_start_url text,
  ADD COLUMN recording_url text;
