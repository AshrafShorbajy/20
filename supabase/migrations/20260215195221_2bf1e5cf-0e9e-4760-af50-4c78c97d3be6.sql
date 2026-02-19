
ALTER TABLE public.profiles ADD COLUMN curriculum_id uuid REFERENCES public.curricula(id) DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN grade_level_id uuid REFERENCES public.grade_levels(id) DEFAULT NULL;
