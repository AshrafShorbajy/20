
-- The previous migration partially succeeded. 
-- group_session_schedules already has the new columns and course_installments table exists.
-- Just need to remove the realtime line that failed. Nothing more needed.
-- Verify by selecting: this is a no-op migration
SELECT 1;
