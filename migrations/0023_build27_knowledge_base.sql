-- Build 27: public Knowledge Base, immutable article versions, and feedback.
-- Published knowledge is versioned so review/draft edits never silently replace
-- the last public version. Nexus retrieval may only read published snapshots.

BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0022'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0022 must be applied first';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hdc_app') THEN
    RAISE EXCEPTION 'HDC restricted application role is required';
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.hdc_knowledge_articles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_article_id text NOT NULL UNIQUE,
  slug text NOT NULL UNIQUE,
  category text NOT NULL,
  title text NOT NULL,
  summary text NOT NULL,
  body text NOT NULL,
  steps jsonb NOT NULL DEFAULT '[]'::jsonb,
  tags text[] NOT NULL DEFAULT '{}'::text[],
  safety_level text NOT NULL DEFAULT 'low',
  safety_notice text NOT NULL DEFAULT '',
  escalation_text text NOT NULL DEFAULT '',
  nexus_ready boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'draft',
  version integer NOT NULL DEFAULT 1,
  published_version integer,
  ever_published boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  created_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_knowledge_article_id_format
    CHECK (public_article_id ~ '^KB-[A-Z0-9-]{3,32}$'),
  CONSTRAINT hdc_knowledge_category_allowed
    CHECK (category IN (
      'pc_laptop',
      'phones_mobile',
      'pos_business_tech',
      'network_internet',
      'printers_peripherals',
      'security_accounts'
    )),
  CONSTRAINT hdc_knowledge_safety_allowed
    CHECK (safety_level IN ('low', 'moderate', 'high')),
  CONSTRAINT hdc_knowledge_status_allowed
    CHECK (status IN ('draft', 'review', 'published', 'archived')),
  CONSTRAINT hdc_knowledge_version_positive
    CHECK (version > 0),
  CONSTRAINT hdc_knowledge_published_version_valid
    CHECK (published_version IS NULL OR published_version > 0),
  CONSTRAINT hdc_knowledge_steps_array
    CHECK (jsonb_typeof(steps) = 'array')
);

CREATE TABLE IF NOT EXISTS public.hdc_knowledge_article_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id uuid NOT NULL REFERENCES public.hdc_knowledge_articles(id) ON DELETE CASCADE,
  version integer NOT NULL,
  slug text NOT NULL,
  category text NOT NULL,
  title text NOT NULL,
  summary text NOT NULL,
  body text NOT NULL,
  steps jsonb NOT NULL,
  tags text[] NOT NULL DEFAULT '{}'::text[],
  safety_level text NOT NULL,
  safety_notice text NOT NULL DEFAULT '',
  escalation_text text NOT NULL DEFAULT '',
  nexus_ready boolean NOT NULL DEFAULT true,
  is_featured boolean NOT NULL DEFAULT false,
  workflow_status text NOT NULL,
  change_note text NOT NULL DEFAULT '',
  created_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  CONSTRAINT hdc_knowledge_version_unique UNIQUE (article_id, version),
  CONSTRAINT hdc_knowledge_version_positive_snapshot CHECK (version > 0),
  CONSTRAINT hdc_knowledge_version_category_allowed
    CHECK (category IN (
      'pc_laptop',
      'phones_mobile',
      'pos_business_tech',
      'network_internet',
      'printers_peripherals',
      'security_accounts'
    )),
  CONSTRAINT hdc_knowledge_version_safety_allowed
    CHECK (safety_level IN ('low', 'moderate', 'high')),
  CONSTRAINT hdc_knowledge_version_status_allowed
    CHECK (workflow_status IN ('draft', 'review', 'published', 'archived')),
  CONSTRAINT hdc_knowledge_version_steps_array
    CHECK (jsonb_typeof(steps) = 'array')
);

ALTER TABLE public.hdc_knowledge_articles
  DROP CONSTRAINT IF EXISTS hdc_knowledge_published_version_fk;

ALTER TABLE public.hdc_knowledge_articles
  ADD CONSTRAINT hdc_knowledge_published_version_fk
  FOREIGN KEY (id, published_version)
  REFERENCES public.hdc_knowledge_article_versions(article_id, version)
  DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE IF NOT EXISTS public.hdc_knowledge_feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_feedback_id text NOT NULL UNIQUE,
  article_id uuid NOT NULL,
  article_version integer NOT NULL,
  user_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE CASCADE,
  helpful boolean NOT NULL,
  note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_knowledge_feedback_article_version_fk
    FOREIGN KEY (article_id, article_version)
    REFERENCES public.hdc_knowledge_article_versions(article_id, version)
    ON DELETE CASCADE,
  CONSTRAINT hdc_knowledge_feedback_member_version_unique
    UNIQUE (article_id, user_id, article_version)
);

CREATE INDEX IF NOT EXISTS idx_hdc_knowledge_articles_status
  ON public.hdc_knowledge_articles(status, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_hdc_knowledge_versions_category
  ON public.hdc_knowledge_article_versions(category, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hdc_knowledge_versions_search
  ON public.hdc_knowledge_article_versions
  USING GIN (
    to_tsvector(
      'english',
      coalesce(title, '') || ' ' ||
      coalesce(summary, '') || ' ' ||
      coalesce(body, '')
    )
  );

CREATE INDEX IF NOT EXISTS idx_hdc_knowledge_feedback_article
  ON public.hdc_knowledge_feedback(article_id, article_version);

-- Seed a deliberately small set of reviewed, low-risk guides so Build 27 can
-- be tested immediately without pretending the Knowledge Base is already large.
INSERT INTO public.hdc_knowledge_articles (
  public_article_id, slug, category, title, summary, body, steps, tags,
  safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
  status, version, published_version, ever_published, published_at
) VALUES
(
  'KB-NET-001',
  'windows-connected-no-internet',
  'network_internet',
  'Windows shows connected but websites do not load',
  'Check the local connection, gateway reachability, DNS, and adapter state before changing router settings.',
  'Use these checks to separate a local Windows problem from a router or internet-provider problem. Do not reset shared network equipment unless you are authorized to do so.',
  '[
    "Confirm whether other devices on the same network can reach the internet.",
    "In Windows, disconnect and reconnect Wi-Fi or unplug and reconnect the Ethernet cable.",
    "Open Command Prompt and run ipconfig. Confirm the adapter has an IPv4 address and a Default Gateway.",
    "Test the Default Gateway first. If the gateway responds but websites do not load, test a known domain and then DNS resolution.",
    "Disable and re-enable the affected network adapter once, then test again."
  ]'::jsonb,
  ARRAY['windows','internet','wifi','ethernet','dns'],
  'low',
  'These steps do not require opening network equipment or changing shared router configuration.',
  'If multiple devices are offline, the gateway cannot be reached, or the network is business-critical, stop changing settings and escalate to the network owner or a qualified technician.',
  true,
  true,
  'published',
  1,
  NULL,
  true,
  now()
),
(
  'KB-PRN-001',
  'usb-printer-not-detected',
  'printers_peripherals',
  'USB printer is not detected by Windows',
  'Check power, cable, USB detection, queue state, and the correct printer driver without opening the printer.',
  'This guide covers common external checks for a USB printer that does not appear or cannot print from Windows.',
  '[
    "Confirm the printer is powered on and shows no hardware error on its own panel.",
    "Reconnect the USB cable at both ends and try another known-good USB port on the computer.",
    "Open Settings > Bluetooth & devices > Printers & scanners and check whether the printer appears.",
    "If it appears, open the print queue and clear obviously stuck jobs before testing one new page.",
    "If Windows detects an unknown device or the model is missing, install the manufacturer driver that matches the exact printer model and Windows version."
  ]'::jsonb,
  ARRAY['printer','usb','windows','driver','queue'],
  'low',
  'Do not open the printer, bypass covers, or touch internal power components.',
  'If the printer reports a mechanical, burning, electrical, or repeated hardware fault, stop and use an authorized repair technician.',
  true,
  true,
  'published',
  1,
  NULL,
  true,
  now()
),
(
  'KB-POS-001',
  'pos-unable-to-locate-server',
  'pos_business_tech',
  'POS terminal reports that it cannot locate the server',
  'Verify the terminal network path and store-server availability before restarting shared services or changing configuration.',
  'Use this guide for a POS workstation that cannot reach its configured store server. The goal is to identify whether the problem affects one terminal, the local network, or the server.',
  '[
    "Check whether only one POS terminal is affected or whether multiple terminals show the same server error.",
    "Confirm the affected terminal has a physical or wireless network connection and a valid local IP address.",
    "If your support procedure permits it, test reachability to the configured store-server address without changing the server address.",
    "Compare the affected terminal with a working terminal on the same store network.",
    "Restart only the affected POS application or workstation if store procedure allows it. Do not restart the shared server during active trading without authorization."
  ]'::jsonb,
  ARRAY['pos','server','store-network','connectivity','terminal'],
  'moderate',
  'A store server may support multiple tills, kitchen displays, payment flows, or other business systems. Avoid unapproved server restarts or configuration changes.',
  'If multiple terminals are affected, the store server is unreachable, payments are impacted, or a restart would affect live operations, escalate through the store support procedure.',
  true,
  true,
  'published',
  1,
  NULL,
  true,
  now()
),
(
  'KB-HST-001',
  'usb-headset-microphone-not-detected',
  'printers_peripherals',
  'USB headset microphone is not detected',
  'Check the USB connection, Windows input device, privacy permission, and application input selection.',
  'These steps cover a USB headset that plays audio but does not provide microphone input, or is missing from the application input list.',
  '[
    "Reconnect the headset and try another known-good USB port.",
    "Open Windows Sound settings and confirm the headset microphone appears under Input.",
    "Check microphone privacy permissions and allow access for the application you are testing.",
    "Inside the calling or support application, select the headset microphone explicitly instead of relying on Default.",
    "Test the microphone in Windows Sound settings before troubleshooting the application further."
  ]'::jsonb,
  ARRAY['headset','microphone','usb','windows','audio'],
  'low',
  'Do not dismantle the headset or USB controller while it is connected.',
  'If the microphone is physically damaged, the cable is torn, or the device repeatedly disconnects across multiple computers, replace or repair the hardware.',
  true,
  false,
  'published',
  1,
  NULL,
  true,
  now()
)
ON CONFLICT (public_article_id) DO NOTHING;

INSERT INTO public.hdc_knowledge_article_versions (
  article_id, version, slug, category, title, summary, body, steps, tags,
  safety_level, safety_notice, escalation_text, nexus_ready, is_featured,
  workflow_status, change_note, published_at
)
SELECT
  article.id,
  1,
  article.slug,
  article.category,
  article.title,
  article.summary,
  article.body,
  article.steps,
  article.tags,
  article.safety_level,
  article.safety_notice,
  article.escalation_text,
  article.nexus_ready,
  article.is_featured,
  'published',
  'Build 27 starter knowledge',
  article.published_at
FROM public.hdc_knowledge_articles article
WHERE article.public_article_id IN (
  'KB-NET-001',
  'KB-PRN-001',
  'KB-POS-001',
  'KB-HST-001'
)
ON CONFLICT (article_id, version) DO NOTHING;

UPDATE public.hdc_knowledge_articles
SET published_version = 1
WHERE public_article_id IN (
  'KB-NET-001',
  'KB-PRN-001',
  'KB-POS-001',
  'KB-HST-001'
)
  AND published_version IS NULL;

REVOKE ALL ON public.hdc_knowledge_articles FROM PUBLIC, hdc_app;
REVOKE ALL ON public.hdc_knowledge_article_versions FROM PUBLIC, hdc_app;
REVOKE ALL ON public.hdc_knowledge_feedback FROM PUBLIC, hdc_app;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.hdc_knowledge_articles TO hdc_app;
GRANT SELECT, INSERT
  ON public.hdc_knowledge_article_versions TO hdc_app;
GRANT SELECT, INSERT, UPDATE
  ON public.hdc_knowledge_feedback TO hdc_app;

INSERT INTO public.hdc_schema_migrations (
  version, migration_name, is_baseline
) VALUES ('0023', 'build27_knowledge_base', false)
ON CONFLICT (version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
