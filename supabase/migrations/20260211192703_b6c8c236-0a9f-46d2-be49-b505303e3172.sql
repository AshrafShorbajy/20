-- Allow participants to update is_read on messages they received
CREATE POLICY "Participants mark messages read"
ON public.messages FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.id = messages.conversation_id
    AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())
  )
);