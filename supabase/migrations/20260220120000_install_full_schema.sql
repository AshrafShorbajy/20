-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin', 'supervisor', 'teacher', 'student');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.booking_status AS ENUM ('pending', 'accepted', 'scheduled', 'completed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.invoice_status AS ENUM ('pending', 'paid', 'rejected');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.lesson_type AS ENUM ('tutoring', 'bag_review', 'skills', 'group');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE public.payment_method AS ENUM ('paypal', 'bank_transfer');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Core tables
CREATE TABLE IF NOT EXISTS public.curricula (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.grade_levels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  curriculum_id UUID REFERENCES public.curricula(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  grade_level_id UUID REFERENCES public.grade_levels(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.skills_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  full_name TEXT NOT NULL DEFAULT '',
  phone TEXT,
  avatar_url TEXT,
  bio TEXT,
  curriculum_id UUID REFERENCES public.curricula(id) ON DELETE SET NULL,
  grade_level_id UUID REFERENCES public.grade_levels(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  role public.app_role NOT NULL,
  admin_notes TEXT,
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS public.lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  lesson_type public.lesson_type NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 60,
  price NUMERIC NOT NULL DEFAULT 0,
  curriculum_id UUID REFERENCES public.curricula(id) ON DELETE SET NULL,
  grade_level_id UUID REFERENCES public.grade_levels(id) ON DELETE SET NULL,
  subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
  skill_category_id UUID REFERENCES public.skills_categories(id) ON DELETE SET NULL,
  min_age INTEGER,
  max_age INTEGER,
  is_online BOOLEAN NOT NULL DEFAULT true,
  is_active BOOLEAN NOT NULL DEFAULT true,
  image_url TEXT,
  notes TEXT,
  expected_students INTEGER,
  course_start_date TIMESTAMPTZ,
  total_sessions INTEGER,
  course_topic_type TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  status public.booking_status NOT NULL DEFAULT 'pending',
  payment_method public.payment_method,
  amount NUMERIC NOT NULL DEFAULT 0,
  notes TEXT,
  scheduled_at TIMESTAMPTZ,
  zoom_meeting_id TEXT,
  zoom_join_url TEXT,
  zoom_start_url TEXT,
  payment_receipt_url TEXT,
  recording_url TEXT,
  is_installment BOOLEAN NOT NULL DEFAULT false,
  total_installments INTEGER DEFAULT 0,
  paid_sessions INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  student_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  lesson_id UUID NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  status public.invoice_status NOT NULL DEFAULT 'pending',
  payment_method TEXT,
  payment_receipt_url TEXT,
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  student_id UUID NOT NULL,
  rating INTEGER NOT NULL,
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.site_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, endpoint)
);

CREATE TABLE IF NOT EXISTS public.accounting_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL,
  teacher_id UUID NOT NULL,
  student_id UUID NOT NULL,
  total_amount NUMERIC NOT NULL DEFAULT 0,
  commission_rate NUMERIC NOT NULL DEFAULT 0,
  teacher_share NUMERIC NOT NULL DEFAULT 0,
  platform_share NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'completed',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL,
  amount NUMERIC NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  notes TEXT,
  receipt_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.course_installments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  installment_number INTEGER NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  sessions_unlocked INTEGER NOT NULL DEFAULT 0,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.group_session_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  session_number INTEGER NOT NULL,
  title TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  scheduled_at TIMESTAMPTZ,
  zoom_meeting_id TEXT,
  zoom_join_url TEXT,
  zoom_start_url TEXT,
  recording_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Functions
CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role
  )
$$;

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public
AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', ''));
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'student');
  RETURN NEW;
END;
$$;

-- Triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS update_bookings_updated_at ON public.bookings;
CREATE TRIGGER update_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

DROP TRIGGER IF EXISTS update_invoices_updated_at ON public.invoices;
CREATE TRIGGER update_invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Enable RLS
ALTER TABLE public.curricula ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.skills_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounting_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_session_schedules ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Curricula viewable by all" ON public.curricula FOR SELECT USING (true);
CREATE POLICY "Admin manages curricula" ON public.curricula FOR ALL USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'supervisor'));

CREATE POLICY "Grade levels viewable" ON public.grade_levels FOR SELECT USING (true);
CREATE POLICY "Admin manages grades" ON public.grade_levels FOR ALL USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'supervisor'));

CREATE POLICY "Subjects viewable" ON public.subjects FOR SELECT USING (true);
CREATE POLICY "Admin manages subjects" ON public.subjects FOR ALL USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'supervisor'));

CREATE POLICY "Skills viewable" ON public.skills_categories FOR SELECT USING (true);
CREATE POLICY "Admin manages skills" ON public.skills_categories FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users view own profile" ON public.profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins view all profiles" ON public.profiles FOR SELECT USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'supervisor'));
CREATE POLICY "View teacher profiles" ON public.profiles FOR SELECT USING (EXISTS (SELECT 1 FROM public.user_roles WHERE public.user_roles.user_id = public.profiles.user_id AND public.user_roles.role = 'teacher'));

CREATE POLICY "Roles viewable by all" ON public.user_roles FOR SELECT USING (true);
CREATE POLICY "Admin manages roles" ON public.user_roles FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Lessons viewable" ON public.lessons FOR SELECT USING (true);
CREATE POLICY "Teachers manage own lessons" ON public.lessons FOR INSERT WITH CHECK (auth.uid() = teacher_id);
CREATE POLICY "Teachers update own lessons" ON public.lessons FOR UPDATE USING (auth.uid() = teacher_id);
CREATE POLICY "Teachers delete own lessons" ON public.lessons FOR DELETE USING (auth.uid() = teacher_id);

CREATE POLICY "Students create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Students view own bookings" ON public.bookings FOR SELECT USING (auth.uid() = student_id OR auth.uid() = teacher_id OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Teacher/admin update bookings" ON public.bookings FOR UPDATE USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Students create own invoices" ON public.invoices FOR INSERT WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Students view own invoices" ON public.invoices FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY "Teachers view paid invoices" ON public.invoices FOR SELECT USING (auth.uid() = teacher_id AND status = 'paid');
CREATE POLICY "Admin manages invoices" ON public.invoices FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Participants view conversations" ON public.conversations FOR SELECT USING (auth.uid() = student_id OR auth.uid() = teacher_id);
CREATE POLICY "Users create conversations" ON public.conversations FOR INSERT WITH CHECK (auth.uid() = student_id OR auth.uid() = teacher_id);

CREATE POLICY "Participants view messages" ON public.messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = public.messages.conversation_id AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())));
CREATE POLICY "Participants send messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Participants mark messages read" ON public.messages FOR UPDATE USING (EXISTS (SELECT 1 FROM public.conversations c WHERE c.id = public.messages.conversation_id AND (c.student_id = auth.uid() OR c.teacher_id = auth.uid())));

CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Reviews viewable" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Students create reviews" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Users manage own favorites" ON public.favorites FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Announcements viewable" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "Admin manages announcements" ON public.announcements FOR ALL USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'supervisor'));

CREATE POLICY "Settings viewable" ON public.site_settings FOR SELECT USING (true);
CREATE POLICY "Admin manages settings" ON public.site_settings FOR ALL USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Users manage own subscriptions" ON public.push_subscriptions FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role can read all subscriptions" ON public.push_subscriptions FOR SELECT USING (true);

CREATE POLICY "Teachers view own accounting" ON public.accounting_records FOR SELECT USING (auth.uid() = teacher_id);
CREATE POLICY "Admins manage accounting" ON public.accounting_records FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "System inserts accounting" ON public.accounting_records FOR INSERT WITH CHECK (public.has_role(auth.uid(), 'admin') OR auth.uid() = teacher_id);

CREATE POLICY "Teachers create requests" ON public.withdrawal_requests FOR INSERT WITH CHECK (auth.uid() = teacher_id);
CREATE POLICY "Teachers view own requests" ON public.withdrawal_requests FOR SELECT USING (auth.uid() = teacher_id OR public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Admin update requests" ON public.withdrawal_requests FOR UPDATE USING (public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admin manages installments" ON public.course_installments FOR ALL USING (public.has_role(auth.uid(), 'admin'));
CREATE POLICY "Students view own installments" ON public.course_installments FOR SELECT USING (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = public.course_installments.booking_id AND b.student_id = auth.uid()));
CREATE POLICY "Students create own installments" ON public.course_installments FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = public.course_installments.booking_id AND b.student_id = auth.uid()));

CREATE POLICY "Session schedules viewable" ON public.group_session_schedules FOR SELECT USING (true);
CREATE POLICY "Teachers manage own session schedules" ON public.group_session_schedules FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.lessons WHERE public.lessons.id = public.group_session_schedules.lesson_id AND public.lessons.teacher_id = auth.uid()));
CREATE POLICY "Teachers update own session schedules" ON public.group_session_schedules FOR UPDATE USING (EXISTS (SELECT 1 FROM public.lessons WHERE public.lessons.id = public.group_session_schedules.lesson_id AND public.lessons.teacher_id = auth.uid()));
CREATE POLICY "Teachers delete own session schedules" ON public.group_session_schedules FOR DELETE USING (EXISTS (SELECT 1 FROM public.lessons WHERE public.lessons.id = public.group_session_schedules.lesson_id AND public.lessons.teacher_id = auth.uid()));
