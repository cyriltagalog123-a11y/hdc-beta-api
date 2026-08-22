-- HDC Sprint 6.4F
-- Separate user-facing platform capabilities from private HDC internal
-- authority. Apply only after migrations 0001 (active auth contract) and 0002
-- (workflow).
-- Test on an isolated Neon branch before any production promotion.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_users is missing';
  END IF;

  IF to_regclass('public.hdc_user_roles') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_user_roles is missing';
  END IF;

  IF to_regtype('public.hdc_account_role') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_account_role is missing';
  END IF;
END
$$;

ALTER TYPE public.hdc_account_role ADD VALUE IF NOT EXISTS 'supplier';

DO $$
BEGIN
  CREATE TYPE public.hdc_internal_role AS ENUM (
    'owner', 'super_admin', 'admin', 'moderator'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_internal_role_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  role public.hdc_internal_role NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  assigned_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  assignment_note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_internal_role_assignment_unique UNIQUE (user_id, role),
  CONSTRAINT hdc_internal_role_assignment_note_length
    CHECK (char_length(assignment_note) <= 1000)
);

CREATE TABLE IF NOT EXISTS public.hdc_platform_role_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  role text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  applicant_note text NOT NULL DEFAULT '',
  review_note text NOT NULL DEFAULT '',
  reviewed_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_platform_role_application_role
    CHECK (role IN ('technician', 'business', 'seller', 'supplier', 'store')),
  CONSTRAINT hdc_platform_role_application_status
    CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn')),
  CONSTRAINT hdc_platform_role_application_note_length
    CHECK (char_length(applicant_note) <= 1000),
  CONSTRAINT hdc_platform_role_review_note_length
    CHECK (char_length(review_note) <= 1000),
  CONSTRAINT hdc_platform_role_review_state
    CHECK (
      (status = 'pending' AND reviewed_by IS NULL AND reviewed_at IS NULL)
      OR (status = 'withdrawn' AND reviewed_by IS NULL)
      OR (status IN ('approved', 'rejected')
          AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS hdc_platform_role_application_pending_unique
  ON public.hdc_platform_role_applications (user_id, role)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS hdc_platform_role_application_review_idx
  ON public.hdc_platform_role_applications (status, created_at DESC);

CREATE TABLE IF NOT EXISTS public.hdc_internal_departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_internal_department_code
    CHECK (code ~ '^[a-z][a-z0-9_]{1,49}$'),
  CONSTRAINT hdc_internal_department_name_length
    CHECK (char_length(name) BETWEEN 2 AND 100),
  CONSTRAINT hdc_internal_department_description_length
    CHECK (char_length(description) <= 1000)
);

CREATE TABLE IF NOT EXISTS public.hdc_internal_department_sections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL
    REFERENCES public.hdc_internal_departments(id) ON DELETE CASCADE,
  code text NOT NULL,
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_internal_department_section_unique
    UNIQUE (department_id, code),
  CONSTRAINT hdc_internal_department_section_code
    CHECK (code ~ '^[a-z][a-z0-9_]{1,49}$'),
  CONSTRAINT hdc_internal_department_section_name_length
    CHECK (char_length(name) BETWEEN 2 AND 100),
  CONSTRAINT hdc_internal_department_section_description_length
    CHECK (char_length(description) <= 1000)
);

CREATE TABLE IF NOT EXISTS public.hdc_internal_staff_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  department_id uuid NOT NULL
    REFERENCES public.hdc_internal_departments(id) ON DELETE CASCADE,
  section_id uuid
    REFERENCES public.hdc_internal_department_sections(id) ON DELETE SET NULL,
  title text NOT NULL DEFAULT '',
  is_active boolean NOT NULL DEFAULT true,
  assigned_by uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_internal_staff_assignment_unique
    UNIQUE (user_id, department_id, section_id),
  CONSTRAINT hdc_internal_staff_assignment_title_length
    CHECK (char_length(title) <= 100)
);

CREATE TABLE IF NOT EXISTS public.hdc_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  priority text NOT NULL DEFAULT 'normal',
  title text NOT NULL,
  message text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_notification_priority
    CHECK (priority IN ('normal', 'high', 'critical')),
  CONSTRAINT hdc_notification_event_type_length
    CHECK (char_length(event_type) BETWEEN 3 AND 100),
  CONSTRAINT hdc_notification_title_length
    CHECK (char_length(title) BETWEEN 2 AND 160),
  CONSTRAINT hdc_notification_message_length
    CHECK (char_length(message) BETWEEN 2 AND 2000)
);

CREATE INDEX IF NOT EXISTS hdc_notifications_user_created_idx
  ON public.hdc_notifications (user_id, created_at DESC);

-- Preserve existing administrators while removing them from the platform-role
-- namespace. Owner and Moderator are intentionally never inferred.
INSERT INTO public.hdc_internal_role_assignments (
  user_id, role, is_active, assignment_note
)
SELECT
  user_id,
  CASE role::text
    WHEN 'super_admin' THEN 'super_admin'::public.hdc_internal_role
    ELSE 'admin'::public.hdc_internal_role
  END,
  is_active,
  'Migrated from legacy mixed HDC role storage.'
FROM public.hdc_user_roles
WHERE role::text IN ('admin', 'super_admin')
ON CONFLICT (user_id, role) DO UPDATE
SET is_active = EXCLUDED.is_active,
    updated_at = now();

DELETE FROM public.hdc_user_roles
WHERE role::text IN ('admin', 'super_admin');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'hdc_user_roles_platform_only'
      AND conrelid = 'public.hdc_user_roles'::regclass
  ) THEN
    ALTER TABLE public.hdc_user_roles
      ADD CONSTRAINT hdc_user_roles_platform_only
      CHECK (role::text IN (
        'customer', 'technician', 'seller', 'business', 'supplier', 'store'
      ));
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION public.hdc_touch_role_row()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_role_row() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_internal_roles_touch
  ON public.hdc_internal_role_assignments;
CREATE TRIGGER hdc_internal_roles_touch
BEFORE UPDATE ON public.hdc_internal_role_assignments
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_role_row();

DROP TRIGGER IF EXISTS hdc_platform_role_applications_touch
  ON public.hdc_platform_role_applications;
CREATE TRIGGER hdc_platform_role_applications_touch
BEFORE UPDATE ON public.hdc_platform_role_applications
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_role_row();

DROP TRIGGER IF EXISTS hdc_internal_departments_touch
  ON public.hdc_internal_departments;
CREATE TRIGGER hdc_internal_departments_touch
BEFORE UPDATE ON public.hdc_internal_departments
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_role_row();

DROP TRIGGER IF EXISTS hdc_internal_department_sections_touch
  ON public.hdc_internal_department_sections;
CREATE TRIGGER hdc_internal_department_sections_touch
BEFORE UPDATE ON public.hdc_internal_department_sections
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_role_row();

DROP TRIGGER IF EXISTS hdc_internal_staff_assignments_touch
  ON public.hdc_internal_staff_assignments;
CREATE TRIGGER hdc_internal_staff_assignments_touch
BEFORE UPDATE ON public.hdc_internal_staff_assignments
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_role_row();

ALTER TABLE public.hdc_internal_role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_platform_role_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_internal_departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_internal_department_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_internal_staff_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_notifications ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_internal_role_assignments FROM PUBLIC;
REVOKE ALL ON public.hdc_platform_role_applications FROM PUBLIC;
REVOKE ALL ON public.hdc_internal_departments FROM PUBLIC;
REVOKE ALL ON public.hdc_internal_department_sections FROM PUBLIC;
REVOKE ALL ON public.hdc_internal_staff_assignments FROM PUBLIC;
REVOKE ALL ON public.hdc_notifications FROM PUBLIC;

COMMIT;
