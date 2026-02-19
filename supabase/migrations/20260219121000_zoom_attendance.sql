-- Create attendance_events table to store realtime presence from Zoom webhooks
create table if not exists public.attendance_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamp with time zone default now(),
  meeting_id text not null,
  schedule_id uuid null,
  booking_id uuid null,
  lesson_id uuid null,
  participant_id text null,
  participant_name text null,
  participant_email text null,
  participant_role text null, -- host|cohost|attendee|panelist|guest
  event_type text not null, -- joined|left|started|ended
  metadata jsonb null
);

alter table public.attendance_events enable row level security;

-- Allow anon to insert via Edge Function (service role recommended), and read for admins/supervisors
create policy if not exists "attendance insert via service role" on public.attendance_events
  as permissive for insert
  to service_role
  using (true)
  with check (true);

create policy if not exists "attendance read for authenticated" on public.attendance_events
  as permissive for select
  to authenticated
  using (true);

-- Helpful index for meeting_id and recency
create index if not exists attendance_events_meeting_created_idx on public.attendance_events (meeting_id, created_at desc);

-- Foreign keys (optional, soft constraints)
-- alter table public.attendance_events add constraint attendance_events_schedule_fk foreign key (schedule_id) references public.group_session_schedules (id) on delete set null;
-- alter table public.attendance_events add constraint attendance_events_booking_fk foreign key (booking_id) references public.bookings (id) on delete set null;
-- alter table public.attendance_events add constraint attendance_events_lesson_fk foreign key (lesson_id) references public.lessons (id) on delete set null;
