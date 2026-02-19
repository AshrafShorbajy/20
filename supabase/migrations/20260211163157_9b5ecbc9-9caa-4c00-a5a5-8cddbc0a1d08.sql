
-- Drop existing restrictive SELECT policy and recreate as permissive
DROP POLICY IF EXISTS "Students view own bookings" ON public.bookings;
CREATE POLICY "Students view own bookings" 
ON public.bookings 
FOR SELECT 
TO authenticated
USING ((auth.uid() = student_id) OR (auth.uid() = teacher_id) OR has_role(auth.uid(), 'admin'::app_role));

-- Drop and recreate INSERT policy as permissive
DROP POLICY IF EXISTS "Students create bookings" ON public.bookings;
CREATE POLICY "Students create bookings" 
ON public.bookings 
FOR INSERT 
TO authenticated
WITH CHECK (auth.uid() = student_id);

-- Drop and recreate UPDATE policy as permissive
DROP POLICY IF EXISTS "Teacher/admin update bookings" ON public.bookings;
CREATE POLICY "Teacher/admin update bookings" 
ON public.bookings 
FOR UPDATE 
TO authenticated
USING ((auth.uid() = teacher_id) OR has_role(auth.uid(), 'admin'::app_role));
