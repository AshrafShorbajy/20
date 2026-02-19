
-- Add 'group' to lesson_type enum
ALTER TYPE public.lesson_type ADD VALUE IF NOT EXISTS 'group';

-- Add group-specific columns to lessons table
ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS expected_students integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS course_start_date timestamp with time zone DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS total_sessions integer DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS course_topic_type text DEFAULT NULL;

-- Create table for group lesson session schedules
CREATE TABLE IF NOT EXISTS public.group_session_schedules (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  session_number integer NOT NULL,
  scheduled_at timestamp with time zone DEFAULT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.group_session_schedules ENABLE ROW LEVEL SECURITY;

-- Everyone can view schedules
CREATE POLICY "Session schedules viewable"
  ON public.group_session_schedules FOR SELECT
  USING (true);

-- Teachers manage their lesson schedules
CREATE POLICY "Teachers manage own session schedules"
  ON public.group_session_schedules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.lessons WHERE lessons.id = group_session_schedules.lesson_id AND lessons.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Teachers update own session schedules"
  ON public.group_session_schedules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.lessons WHERE lessons.id = group_session_schedules.lesson_id AND lessons.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Teachers delete own session schedules"
  ON public.group_session_schedules FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.lessons WHERE lessons.id = group_session_schedules.lesson_id AND lessons.teacher_id = auth.uid()
    )
  );

-- Enable realtime for group_session_schedules
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_session_schedules;
