-- HDC Build 26 follow-up: completed-transaction ratings, suggestions, earned badges.
BEGIN;

DO $$
BEGIN
  IF to_regclass('public.hdc_service_transactions') IS NULL
     OR to_regclass('public.hdc_product_purchase_requests') IS NULL
     OR to_regclass('public.hdc_schema_migrations') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM public.hdc_schema_migrations WHERE version = '0021'
     ) THEN
    RAISE EXCEPTION 'HDC migration 0021 must be applied first';
  END IF;
END
$$;

-- Marketplace acceptance is not treated as a completed transaction. The seller
-- records fulfillment and the buyer confirms completion before ratings unlock.
ALTER TABLE public.hdc_product_purchase_requests
  ADD COLUMN IF NOT EXISTS fulfilled_at timestamptz,
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

ALTER TABLE public.hdc_product_purchase_requests
  DROP CONSTRAINT IF EXISTS hdc_product_purchase_status,
  DROP CONSTRAINT IF EXISTS hdc_product_purchase_state;
ALTER TABLE public.hdc_product_purchase_requests
  ADD CONSTRAINT hdc_product_purchase_status CHECK (
    status IN ('submitted', 'accepted', 'fulfilled', 'completed', 'declined', 'cancelled')
  ),
  ADD CONSTRAINT hdc_product_purchase_state CHECK (
    (status = 'submitted' AND decided_at IS NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'accepted' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'fulfilled' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NOT NULL AND completed_at IS NULL)
    OR (status = 'completed' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NOT NULL AND completed_at IS NOT NULL)
    OR (status = 'declined' AND decided_at IS NOT NULL AND cancelled_at IS NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
    OR (status = 'cancelled' AND decided_at IS NULL AND cancelled_at IS NOT NULL
      AND fulfilled_at IS NULL AND completed_at IS NULL)
  );

ALTER TABLE public.hdc_product_purchase_request_events
  DROP CONSTRAINT IF EXISTS hdc_product_purchase_event_type,
  DROP CONSTRAINT IF EXISTS hdc_product_purchase_event_from_status,
  DROP CONSTRAINT IF EXISTS hdc_product_purchase_event_to_status;
ALTER TABLE public.hdc_product_purchase_request_events
  ADD CONSTRAINT hdc_product_purchase_event_type CHECK (
    event_type IN ('submitted', 'accepted', 'fulfilled', 'completed', 'declined', 'cancelled')
  ),
  ADD CONSTRAINT hdc_product_purchase_event_from_status CHECK (
    from_status IS NULL OR from_status IN (
      'submitted', 'accepted', 'fulfilled', 'completed', 'declined', 'cancelled'
    )
  ),
  ADD CONSTRAINT hdc_product_purchase_event_to_status CHECK (
    to_status IN ('submitted', 'accepted', 'fulfilled', 'completed', 'declined', 'cancelled')
  );

CREATE TABLE public.hdc_transaction_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_rating_id text NOT NULL UNIQUE DEFAULT (
    'HDC-RATE-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  ),
  transaction_kind text NOT NULL,
  service_transaction_id text REFERENCES public.hdc_service_transactions(id) ON DELETE RESTRICT,
  purchase_request_id uuid REFERENCES public.hdc_product_purchase_requests(id) ON DELETE RESTRICT,
  rater_member_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  rated_member_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  score smallint NOT NULL,
  review text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  withdrawn_at timestamptz,
  CONSTRAINT hdc_transaction_ratings_public_id CHECK (
    public_rating_id ~ '^HDC-RATE-[A-F0-9]{12}$'
  ),
  CONSTRAINT hdc_transaction_ratings_kind CHECK (
    transaction_kind IN ('service', 'commerce')
  ),
  CONSTRAINT hdc_transaction_ratings_reference CHECK (
    (transaction_kind = 'service' AND service_transaction_id IS NOT NULL AND purchase_request_id IS NULL)
    OR (transaction_kind = 'commerce' AND purchase_request_id IS NOT NULL AND service_transaction_id IS NULL)
  ),
  CONSTRAINT hdc_transaction_ratings_participants CHECK (rater_member_id <> rated_member_id),
  CONSTRAINT hdc_transaction_ratings_score CHECK (score BETWEEN 1 AND 5),
  CONSTRAINT hdc_transaction_ratings_review CHECK (char_length(review) <= 1000),
  CONSTRAINT hdc_transaction_ratings_status CHECK (status IN ('active', 'withdrawn')),
  CONSTRAINT hdc_transaction_ratings_withdrawal CHECK (
    (status = 'active' AND withdrawn_at IS NULL)
    OR (status = 'withdrawn' AND withdrawn_at IS NOT NULL)
  )
);

CREATE UNIQUE INDEX hdc_transaction_ratings_service_rater
  ON public.hdc_transaction_ratings(service_transaction_id, rater_member_id)
  WHERE service_transaction_id IS NOT NULL;
CREATE UNIQUE INDEX hdc_transaction_ratings_commerce_rater
  ON public.hdc_transaction_ratings(purchase_request_id, rater_member_id)
  WHERE purchase_request_id IS NOT NULL;
CREATE INDEX hdc_transaction_ratings_received
  ON public.hdc_transaction_ratings(rated_member_id, status, created_at DESC);

CREATE OR REPLACE FUNCTION public.hdc_validate_transaction_rating()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  expected_rated uuid;
  transaction_status text;
  first_party uuid;
  second_party uuid;
BEGIN
  IF NEW.transaction_kind = 'service' THEN
    SELECT status, customer_id, technician_id
    INTO transaction_status, first_party, second_party
    FROM public.hdc_service_transactions
    WHERE id = NEW.service_transaction_id;
  ELSE
    SELECT status, buyer_user_id, seller_user_id
    INTO transaction_status, first_party, second_party
    FROM public.hdc_product_purchase_requests
    WHERE id = NEW.purchase_request_id;
  END IF;

  IF transaction_status IS NULL THEN
    RAISE EXCEPTION 'HDC rating transaction does not exist';
  END IF;
  IF transaction_status <> 'completed' THEN
    RAISE EXCEPTION 'HDC ratings require a completed transaction';
  END IF;
  IF NEW.rater_member_id = first_party THEN
    expected_rated := second_party;
  ELSIF NEW.rater_member_id = second_party THEN
    expected_rated := first_party;
  ELSE
    RAISE EXCEPTION 'HDC rating author is not a transaction participant';
  END IF;
  NEW.rated_member_id := expected_rated;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS hdc_transaction_ratings_validate ON public.hdc_transaction_ratings;
CREATE TRIGGER hdc_transaction_ratings_validate
BEFORE INSERT ON public.hdc_transaction_ratings
FOR EACH ROW EXECUTE FUNCTION public.hdc_validate_transaction_rating();

CREATE OR REPLACE FUNCTION public.hdc_guard_transaction_rating_identity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF ROW(NEW.id, NEW.public_rating_id, NEW.transaction_kind,
         NEW.service_transaction_id, NEW.purchase_request_id,
         NEW.rater_member_id, NEW.rated_member_id, NEW.score, NEW.review, NEW.created_at)
     IS DISTINCT FROM
     ROW(OLD.id, OLD.public_rating_id, OLD.transaction_kind,
         OLD.service_transaction_id, OLD.purchase_request_id,
         OLD.rater_member_id, OLD.rated_member_id, OLD.score, OLD.review, OLD.created_at) THEN
    RAISE EXCEPTION 'HDC rating evidence is immutable; withdraw instead';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END
$$;
DROP TRIGGER IF EXISTS hdc_transaction_ratings_identity_guard ON public.hdc_transaction_ratings;
CREATE TRIGGER hdc_transaction_ratings_identity_guard
BEFORE UPDATE ON public.hdc_transaction_ratings
FOR EACH ROW EXECUTE FUNCTION public.hdc_guard_transaction_rating_identity();

CREATE OR REPLACE FUNCTION public.hdc_prevent_rating_delete()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'HDC rating history is retained; withdraw the rating instead';
END
$$;
DROP TRIGGER IF EXISTS hdc_transaction_ratings_no_delete ON public.hdc_transaction_ratings;
CREATE TRIGGER hdc_transaction_ratings_no_delete
BEFORE DELETE ON public.hdc_transaction_ratings
FOR EACH ROW EXECUTE FUNCTION public.hdc_prevent_rating_delete();

CREATE TABLE public.hdc_suggestions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  public_suggestion_id text NOT NULL UNIQUE DEFAULT (
    'HDC-SUG-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
  ),
  member_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  category text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  status text NOT NULL DEFAULT 'submitted',
  staff_response text NOT NULL DEFAULT '',
  public_attribution_consent boolean NOT NULL DEFAULT false,
  reviewed_by uuid REFERENCES public.hdc_users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT hdc_suggestions_public_id CHECK (public_suggestion_id ~ '^HDC-SUG-[A-F0-9]{12}$'),
  CONSTRAINT hdc_suggestions_category CHECK (
    category IN ('feature', 'usability', 'marketplace', 'service_workflow', 'safety', 'knowledge_base', 'other')
  ),
  CONSTRAINT hdc_suggestions_title CHECK (char_length(title) BETWEEN 4 AND 160),
  CONSTRAINT hdc_suggestions_body CHECK (char_length(body) BETWEEN 10 AND 5000),
  CONSTRAINT hdc_suggestions_status CHECK (
    status IN ('submitted', 'reviewing', 'planned', 'declined', 'implemented')
  ),
  CONSTRAINT hdc_suggestions_response CHECK (char_length(staff_response) <= 3000)
);
CREATE INDEX hdc_suggestions_member ON public.hdc_suggestions(member_id, created_at DESC);
CREATE INDEX hdc_suggestions_staff_queue ON public.hdc_suggestions(status, updated_at DESC);

CREATE OR REPLACE FUNCTION public.hdc_touch_suggestion()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;
DROP TRIGGER IF EXISTS hdc_suggestions_touch ON public.hdc_suggestions;
CREATE TRIGGER hdc_suggestions_touch
BEFORE UPDATE ON public.hdc_suggestions
FOR EACH ROW EXECUTE FUNCTION public.hdc_touch_suggestion();

CREATE TABLE public.hdc_badge_definitions (
  badge_key text PRIMARY KEY,
  name text NOT NULL,
  description text NOT NULL,
  icon_key text NOT NULL,
  category text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  CONSTRAINT hdc_badge_key CHECK (badge_key ~ '^[a-z0-9_]{3,64}$'),
  CONSTRAINT hdc_badge_name CHECK (char_length(name) BETWEEN 3 AND 80),
  CONSTRAINT hdc_badge_description CHECK (char_length(description) BETWEEN 10 AND 300),
  CONSTRAINT hdc_badge_category CHECK (category IN ('service', 'commerce', 'community'))
);

CREATE TABLE public.hdc_member_badges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id uuid NOT NULL REFERENCES public.hdc_users(id) ON DELETE RESTRICT,
  badge_key text NOT NULL REFERENCES public.hdc_badge_definitions(badge_key) ON DELETE RESTRICT,
  evidence_kind text NOT NULL,
  evidence_count integer NOT NULL,
  earned_at timestamptz NOT NULL DEFAULT now(),
  visible boolean NOT NULL DEFAULT true,
  revoked_at timestamptz,
  revoked_reason text,
  CONSTRAINT hdc_member_badges_unique UNIQUE(member_id, badge_key),
  CONSTRAINT hdc_member_badges_evidence CHECK (evidence_count > 0),
  CONSTRAINT hdc_member_badges_revocation CHECK (
    (revoked_at IS NULL AND revoked_reason IS NULL)
    OR (revoked_at IS NOT NULL AND char_length(revoked_reason) BETWEEN 3 AND 500)
  )
);
CREATE INDEX hdc_member_badges_public ON public.hdc_member_badges(member_id, visible, earned_at DESC);

INSERT INTO public.hdc_badge_definitions(badge_key, name, description, icon_key, category) VALUES
  ('first_service_complete', 'First Service Complete', 'Completed a recorded HDC service transaction.', 'build_circle', 'service'),
  ('service_five', 'Service Milestone 5', 'Completed at least five recorded HDC service transactions.', 'handyman', 'service'),
  ('service_twenty_five', 'Service Milestone 25', 'Completed at least twenty-five recorded HDC service transactions.', 'workspace_premium', 'service'),
  ('first_marketplace_complete', 'First Marketplace Complete', 'Completed a buyer-to-seller HDC marketplace transaction.', 'shopping_bag', 'commerce'),
  ('marketplace_five', 'Marketplace Milestone 5', 'Completed at least five recorded HDC marketplace transactions.', 'storefront', 'commerce'),
  ('helpful_contributor', 'Helpful Contributor', 'Submitted an HDC suggestion that was implemented.', 'lightbulb', 'community')
ON CONFLICT (badge_key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  icon_key = EXCLUDED.icon_key,
  category = EXCLUDED.category,
  active = true;

CREATE OR REPLACE FUNCTION public.hdc_sync_member_badges(target_member uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  service_count integer;
  commerce_count integer;
  implemented_count integer;
BEGIN
  SELECT count(*)::integer INTO service_count
  FROM public.hdc_service_transactions
  WHERE status = 'completed'
    AND target_member IN (customer_id, technician_id);

  SELECT count(*)::integer INTO commerce_count
  FROM public.hdc_product_purchase_requests
  WHERE status = 'completed'
    AND target_member IN (buyer_user_id, seller_user_id);

  SELECT count(*)::integer INTO implemented_count
  FROM public.hdc_suggestions
  WHERE member_id = target_member AND status = 'implemented';

  IF service_count >= 1 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'first_service_complete', 'completed_service_transactions', service_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
  IF service_count >= 5 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'service_five', 'completed_service_transactions', service_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
  IF service_count >= 25 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'service_twenty_five', 'completed_service_transactions', service_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
  IF commerce_count >= 1 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'first_marketplace_complete', 'completed_marketplace_transactions', commerce_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
  IF commerce_count >= 5 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'marketplace_five', 'completed_marketplace_transactions', commerce_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
  IF implemented_count >= 1 THEN
    INSERT INTO public.hdc_member_badges(member_id, badge_key, evidence_kind, evidence_count)
    VALUES(target_member, 'helpful_contributor', 'implemented_suggestions', implemented_count)
    ON CONFLICT(member_id, badge_key) DO UPDATE SET evidence_count = GREATEST(hdc_member_badges.evidence_count, EXCLUDED.evidence_count);
  END IF;
END
$$;

INSERT INTO public.hdc_schema_migrations(version, migration_name, is_baseline)
VALUES ('0022', 'build26_feedback_reputation', false)
ON CONFLICT(version) DO UPDATE SET
  migration_name = EXCLUDED.migration_name,
  is_baseline = EXCLUDED.is_baseline;

COMMIT;
