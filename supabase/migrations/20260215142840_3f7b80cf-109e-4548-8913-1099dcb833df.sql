-- Drop the unique constraint on (student_id, teacher_id) to allow multiple conversations per booking
ALTER TABLE public.conversations DROP CONSTRAINT conversations_student_id_teacher_id_key;