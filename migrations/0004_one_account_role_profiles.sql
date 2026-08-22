-- HDC Sprint 6.4G
-- One HDC account owns one shared member profile plus one independently
-- editable profile for every active platform role. Apply after migration 0003.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_users') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_users is missing';
  END IF;

  IF to_regclass('public.hdc_user_roles') IS NULL THEN
    RAISE EXCEPTION 'HDC auth prerequisite public.hdc_user_roles is missing';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_member_profiles (
  user_id uuid PRIMARY KEY REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  bio text NOT NULL DEFAULT '',
  location text NOT NULL DEFAULT '',
  avatar_url text NOT NULL DEFAULT '',
  contact_preference text NOT NULL DEFAULT 'in_app',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_member_profile_bio_length
    CHECK (char_length(bio) <= 1200),
  CONSTRAINT hdc_member_profile_location_length
    CHECK (char_length(location) <= 200),
  CONSTRAINT hdc_member_profile_avatar_url_length
    CHECK (char_length(avatar_url) <= 500),
  CONSTRAINT hdc_member_profile_contact_preference
    CHECK (contact_preference IN ('in_app', 'email', 'phone')),
  CONSTRAINT hdc_member_profile_version CHECK (version > 0)
);

CREATE TABLE IF NOT EXISTS public.hdc_platform_role_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  role text NOT NULL,
  public_name text NOT NULL,
  headline text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  location text NOT NULL DEFAULT '',
  contact_email text NOT NULL DEFAULT '',
  contact_phone text NOT NULL DEFAULT '',
  website text NOT NULL DEFAULT '',
  is_public boolean NOT NULL DEFAULT false,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  version bigint NOT NULL DEFAULT 1,
  CONSTRAINT hdc_platform_role_profile_unique UNIQUE (user_id, role),
  CONSTRAINT hdc_platform_role_profile_role
    CHECK (role IN (
      'customer', 'technician', 'business', 'seller', 'supplier', 'store'
    )),
  CONSTRAINT hdc_platform_role_profile_public_name_length
    CHECK (char_length(public_name) BETWEEN 2 AND 120),
  CONSTRAINT hdc_platform_role_profile_headline_length
    CHECK (char_length(headline) <= 160),
  CONSTRAINT hdc_platform_role_profile_description_length
    CHECK (char_length(description) <= 2000),
  CONSTRAINT hdc_platform_role_profile_location_length
    CHECK (char_length(location) <= 200),
  CONSTRAINT hdc_platform_role_profile_contact_email_length
    CHECK (char_length(contact_email) <= 254),
  CONSTRAINT hdc_platform_role_profile_contact_phone_length
    CHECK (char_length(contact_phone) <= 30),
  CONSTRAINT hdc_platform_role_profile_website_length
    CHECK (char_length(website) <= 500),
  CONSTRAINT hdc_platform_role_profile_details_object
    CHECK (jsonb_typeof(details) = 'object'),
  CONSTRAINT hdc_platform_role_profile_version CHECK (version > 0)
);

CREATE INDEX IF NOT EXISTS hdc_platform_role_profiles_public_idx
  ON public.hdc_platform_role_profiles (role, updated_at DESC)
  WHERE is_public = true;

CREATE OR REPLACE FUNCTION public.hdc_touch_profile_row()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  NEW.version := OLD.version + 1;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_touch_profile_row() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_member_profiles_touch
  ON public.hdc_member_profiles;
CREATE TRIGGER hdc_member_profiles_touch
BEFORE UPDATE ON public.hdc_member_profiles
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_profile_row();

DROP TRIGGER IF EXISTS hdc_platform_role_profiles_touch
  ON public.hdc_platform_role_profiles;
CREATE TRIGGER hdc_platform_role_profiles_touch
BEFORE UPDATE ON public.hdc_platform_role_profiles
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_profile_row();

CREATE OR REPLACE FUNCTION public.hdc_seed_member_profile()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.hdc_member_profiles (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_seed_member_profile() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_users_seed_member_profile
  ON public.hdc_users;
CREATE TRIGGER hdc_users_seed_member_profile
AFTER INSERT ON public.hdc_users
FOR EACH ROW EXECUTE FUNCTION public.hdc_seed_member_profile();

CREATE OR REPLACE FUNCTION public.hdc_seed_platform_role_profile()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.is_active = true
     AND NEW.role::text IN (
       'customer', 'technician', 'business', 'seller', 'supplier', 'store'
     ) THEN
    INSERT INTO public.hdc_platform_role_profiles (
      user_id, role, public_name
    )
    SELECT NEW.user_id, NEW.role::text, member.display_name
    FROM public.hdc_users member
    WHERE member.id = NEW.user_id
    ON CONFLICT (user_id, role) DO NOTHING;
  END IF;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.hdc_seed_platform_role_profile() FROM PUBLIC;

DROP TRIGGER IF EXISTS hdc_user_roles_seed_profile
  ON public.hdc_user_roles;
CREATE TRIGGER hdc_user_roles_seed_profile
AFTER INSERT OR UPDATE OF role, is_active ON public.hdc_user_roles
FOR EACH ROW EXECUTE FUNCTION public.hdc_seed_platform_role_profile();

INSERT INTO public.hdc_member_profiles (user_id)
SELECT user_record.id
FROM public.hdc_users user_record
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.hdc_platform_role_profiles (
  user_id, role, public_name
)
SELECT
  assignment.user_id,
  assignment.role::text,
  member.display_name
FROM public.hdc_user_roles assignment
JOIN public.hdc_users member ON member.id = assignment.user_id
WHERE assignment.is_active = true
  AND assignment.role::text IN (
    'customer', 'technician', 'business', 'seller', 'supplier', 'store'
  )
ON CONFLICT (user_id, role) DO NOTHING;

ALTER TABLE public.hdc_member_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hdc_platform_role_profiles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.hdc_member_profiles FROM PUBLIC;
REVOKE ALL ON public.hdc_platform_role_profiles FROM PUBLIC;

COMMIT;
