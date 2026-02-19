
-- Drop the overly permissive public SELECT policy
DROP POLICY IF EXISTS "Public profiles viewable" ON public.profiles;

-- Allow users to view their own profile
CREATE POLICY "Users view own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = user_id);

-- Allow authenticated users to view teacher profiles (needed for lesson listings)
CREATE POLICY "View teacher profiles"
ON public.profiles
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_roles.user_id = profiles.user_id
      AND user_roles.role = 'teacher'
  )
);

-- Allow admins/supervisors to view all profiles
CREATE POLICY "Admins view all profiles"
ON public.profiles
FOR SELECT
USING (
  has_role(auth.uid(), 'admin') OR has_role(auth.uid(), 'supervisor')
);
