import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import postgres from 'postgres';

const root = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const migrationDirectory = join(root, 'migrations');
const upgradeDatabase = 'hdc_upgrade_build27';

const sourceDatabaseUrl = process.env.HDC_TEST_DATABASE_URL?.trim();
if (!sourceDatabaseUrl) {
  throw new Error('HDC_TEST_DATABASE_URL is required for the Build 27 upgrade rehearsal.');
}
if (process.env.HDC_ALLOW_TEST_DATABASE_RESET !== '1') {
  throw new Error('Set HDC_ALLOW_TEST_DATABASE_RESET=1 for the isolated test server.');
}

const sourceUrl = new URL(sourceDatabaseUrl);
const sourceDatabase = decodeURIComponent(sourceUrl.pathname.replace(/^\//, ''));
if (
  !/^hdc[_-]test(?:[_-].*)?$/i.test(sourceDatabase) ||
  !['localhost', '127.0.0.1', '[::1]'].includes(sourceUrl.hostname)
) {
  throw new Error(
    'The Build 27 upgrade rehearsal may run only on a loopback HDC test server.',
  );
}

const manifest = JSON.parse(
  readFileSync(join(migrationDirectory, 'checksums.json'), 'utf8'),
);
const migrationFiles = readdirSync(migrationDirectory)
  .filter((name) => /^[0-9]{4}_.+\.sql$/.test(name))
  .sort();
if (
  manifest.algorithm !== 'sha256' ||
  JSON.stringify(Object.keys(manifest.files ?? {}).sort()) !==
    JSON.stringify(migrationFiles)
) {
  throw new Error('The migration checksum manifest is incomplete.');
}

const migrations = migrationFiles.map((name) => {
  const contents = readFileSync(join(migrationDirectory, name), 'utf8');
  const checksum = createHash('sha256').update(contents).digest('hex');
  if (checksum !== manifest.files[name]) {
    throw new Error(`Migration checksum mismatch: ${name}`);
  }
  return { name, number: Number(name.slice(0, 4)), contents };
});

const adminUrl = new URL(sourceUrl);
adminUrl.pathname = '/postgres';
const upgradeUrl = new URL(sourceUrl);
upgradeUrl.pathname = `/${upgradeDatabase}`;

const admin = postgres(adminUrl.toString(), {
  max: 1,
  prepare: false,
  connect_timeout: 10,
  idle_timeout: 10,
});
let upgradeSql;
let databaseCreated = false;

async function apply(selectedMigrations) {
  for (const migration of selectedMigrations) {
    process.stdout.write(`Applying ${migration.name}... `);
    await upgradeSql.unsafe(migration.contents);
    console.log('ok');
  }
}

async function expectLocationGuard(statement, label) {
  try {
    await upgradeSql.unsafe(statement);
  } catch (error) {
    if (error?.code === '23514') return;
    throw error;
  }
  throw new Error(`${label} accepted an unsupported new location.`);
}

try {
  const existing = await admin`
    SELECT 1 FROM pg_database WHERE datname = ${upgradeDatabase}
  `;
  if (existing.length > 0) {
    throw new Error(`Refusing to replace existing database ${upgradeDatabase}.`);
  }
  await admin.unsafe(`CREATE DATABASE ${upgradeDatabase}`);
  databaseCreated = true;

  upgradeSql = postgres(upgradeUrl.toString(), {
    max: 1,
    prepare: false,
    connect_timeout: 10,
    idle_timeout: 10,
  });

  await apply(migrations.filter((migration) => migration.number <= 16));

  await upgradeSql.unsafe(`
    INSERT INTO public.hdc_users(
      id, email, password_hash, display_name, status,
      email_verified, public_member_id
    ) VALUES
      (
        '11111111-1111-4111-8111-111111111111',
        'upgrade-customer@example.invalid', 'representative-hash',
        'Upgrade Customer', 'active', true, 'HDC-AAAAAAAAAAAA'
      ),
      (
        '22222222-2222-4222-8222-222222222222',
        'upgrade-seller@example.invalid', 'representative-hash',
        'Upgrade Seller', 'active', true, 'HDC-BBBBBBBBBBBB'
      );

    INSERT INTO public.hdc_user_roles(user_id, role, is_active, status)
    VALUES
      ('11111111-1111-4111-8111-111111111111', 'customer', true, 'active'),
      ('22222222-2222-4222-8222-222222222222', 'seller', true, 'active');

    UPDATE public.hdc_member_profiles
    SET
      bio = CASE
        WHEN user_id = '11111111-1111-4111-8111-111111111111'
          THEN 'Representative legacy customer'
        ELSE 'Representative legacy seller'
      END,
      location = CASE
        WHEN user_id = '11111111-1111-4111-8111-111111111111'
          THEN 'Legacy City'
        ELSE 'Legacy Province'
      END
    WHERE user_id IN (
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222'
    );

    INSERT INTO public.hdc_platform_role_profiles(
      id, user_id, role, public_name, headline, description,
      location, is_public, details
    ) VALUES (
      '33333333-3333-4333-8333-333333333333',
      '22222222-2222-4222-8222-222222222222',
      'seller', 'Upgrade Seller', 'Existing seller',
      'Representative profile retained during migration',
      'Legacy Province', true, '{}'::jsonb
    )
    ON CONFLICT (user_id, role) DO UPDATE SET
      public_name = EXCLUDED.public_name,
      headline = EXCLUDED.headline,
      description = EXCLUDED.description,
      location = EXCLUDED.location,
      is_public = EXCLUDED.is_public;

    INSERT INTO public.hdc_platform_role_applications(
      id, user_id, role, status, answers, applicant_snapshot, submitted_at
    ) VALUES (
      '44444444-4444-4444-8444-444444444444',
      '11111111-1111-4111-8111-111111111111',
      'technician', 'submitted', '{}'::jsonb, '{}'::jsonb, now()
    );

    INSERT INTO public.hdc_service_requests(
      id, customer_id, customer_name, title, category_id, category_name,
      description, location, preferred_date, preferred_time, urgency, status
    ) VALUES (
      'REQ-UPGRADE-001', '11111111-1111-4111-8111-111111111111',
      'Upgrade Customer', 'Representative legacy request', 'network',
      'Network',
      'Representative request retained while adding controlled locations.',
      'Legacy City', now() + interval '2 days', 'Morning', 'normal', 'open'
    );

    INSERT INTO public.hdc_product_listings(
      id, public_listing_id, seller_profile_id, seller_user_id, seller_role,
      category_code, title, description, item_condition, currency,
      unit_price_minor, stock_quantity, status, published_at
    )
    SELECT
      '55555555-5555-4555-8555-555555555555', 'HDC-LST-ABCDEF123456',
      profile.id, '22222222-2222-4222-8222-222222222222', 'seller',
      'networking', 'Upgrade router',
      'Representative product retained during the migration.',
      'used', 'PHP', 125000, 2, 'active', now()
    FROM public.hdc_platform_role_profiles profile
    WHERE profile.user_id = '22222222-2222-4222-8222-222222222222'
      AND profile.role = 'seller';

    INSERT INTO public.hdc_product_purchase_requests(
      id, public_purchase_id, idempotency_key, listing_id,
      seller_user_id, seller_role, buyer_user_id,
      public_listing_id_snapshot, listing_title_snapshot,
      seller_name_snapshot, buyer_name_snapshot,
      buyer_public_member_id_snapshot, quantity, currency,
      unit_price_minor, subtotal_minor, status, decided_at
    ) VALUES (
      '66666666-6666-4666-8666-666666666666', 'HDC-BUY-ABCDEF123456',
      '77777777-7777-4777-8777-777777777777',
      '55555555-5555-4555-8555-555555555555',
      '22222222-2222-4222-8222-222222222222', 'seller',
      '11111111-1111-4111-8111-111111111111', 'HDC-LST-ABCDEF123456',
      'Upgrade router', 'Upgrade Seller', 'Upgrade Customer',
      'HDC-AAAAAAAAAAAA', 1, 'PHP', 125000, 125000, 'accepted', now()
    );

    INSERT INTO public.hdc_product_purchase_request_events(
      purchase_request_id, actor_user_id, event_type,
      from_status, to_status, snapshot
    ) VALUES
      (
        '66666666-6666-4666-8666-666666666666',
        '11111111-1111-4111-8111-111111111111',
        'submitted', NULL, 'submitted', '{}'::jsonb
      ),
      (
        '66666666-6666-4666-8666-666666666666',
        '22222222-2222-4222-8222-222222222222',
        'accepted', 'submitted', 'accepted', '{}'::jsonb
      );
  `);

  await apply(migrations.filter((migration) => migration.number >= 17));

  const rows = await upgradeSql`
    SELECT
      (SELECT count(*)::int FROM public.hdc_schema_migrations)
        AS migration_count,
      (SELECT max(version) FROM public.hdc_schema_migrations)
        AS latest_version,
      (SELECT count(*)::int FROM public.hdc_users) AS users,
      (SELECT count(*)::int FROM public.hdc_member_profiles)
        AS member_profiles,
      (SELECT count(*)::int FROM public.hdc_service_requests)
        AS service_requests,
      (SELECT count(*)::int FROM public.hdc_product_listings) AS listings,
      (SELECT count(*)::int FROM public.hdc_product_purchase_requests)
        AS purchases,
      (SELECT count(*)::int FROM public.hdc_product_purchase_request_events)
        AS purchase_events,
      (SELECT location FROM public.hdc_member_profiles
        WHERE user_id = '11111111-1111-4111-8111-111111111111')
        AS legacy_member_location,
      (SELECT location FROM public.hdc_service_requests
        WHERE id = 'REQ-UPGRADE-001') AS legacy_request_location,
      (SELECT count(*)::int FROM public.hdc_knowledge_articles
        WHERE status = 'published' AND published_version = 1)
        AS published_knowledge_starters,
      (SELECT count(*)::int FROM public.hdc_knowledge_article_versions)
        AS knowledge_versions,
      (SELECT count(*)::int FROM pg_trigger
        WHERE tgrelid IN (
          'public.hdc_knowledge_articles'::regclass,
          'public.hdc_knowledge_article_versions'::regclass
        ) AND NOT tgisinternal AND tgenabled <> 'D')
        AS knowledge_protection_triggers,
      (SELECT count(*)::int FROM pg_constraint constraint_object
        JOIN pg_namespace namespace
          ON namespace.oid = constraint_object.connamespace
        WHERE namespace.nspname = 'public'
          AND NOT constraint_object.convalidated) AS unvalidated_constraints,
      (SELECT count(*)::int FROM pg_index index_object
        JOIN pg_class relation ON relation.oid = index_object.indexrelid
        JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = 'public'
          AND NOT index_object.indisvalid) AS invalid_indexes,
      (SELECT count(*)::int FROM pg_trigger trigger_object
        JOIN pg_class relation ON relation.oid = trigger_object.tgrelid
        JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = 'public'
          AND relation.relname LIKE 'hdc\_%' ESCAPE '\\'
          AND NOT trigger_object.tgisinternal
          AND trigger_object.tgenabled = 'D') AS disabled_hdc_triggers,
      has_table_privilege(
        'hdc_app', 'public.hdc_knowledge_articles',
        'SELECT,INSERT,UPDATE,DELETE'
      ) AS knowledge_article_privileges,
      has_table_privilege(
        'hdc_app', 'public.hdc_knowledge_article_versions', 'SELECT,INSERT'
      ) AS knowledge_version_privileges,
      NOT has_table_privilege(
        'hdc_app', 'public.hdc_knowledge_article_versions', 'UPDATE,DELETE'
      ) AS knowledge_version_mutation_denied,
      NOT has_table_privilege(
        'public', 'public.hdc_knowledge_articles', 'SELECT'
      ) AS public_table_access_denied
  `;
  const check = rows[0];
  if (
    Number(check.migration_count) !== migrations.length ||
    check.latest_version !== '0024' ||
    Number(check.users) !== 2 ||
    Number(check.member_profiles) !== 2 ||
    Number(check.service_requests) !== 1 ||
    Number(check.listings) !== 1 ||
    Number(check.purchases) !== 1 ||
    Number(check.purchase_events) !== 2 ||
    check.legacy_member_location !== 'Legacy City' ||
    check.legacy_request_location !== 'Legacy City' ||
    Number(check.published_knowledge_starters) !== 4 ||
    Number(check.knowledge_versions) !== 4 ||
    Number(check.knowledge_protection_triggers) !== 3 ||
    Number(check.unvalidated_constraints) !== 0 ||
    Number(check.invalid_indexes) !== 0 ||
    Number(check.disabled_hdc_triggers) !== 0 ||
    check.knowledge_article_privileges !== true ||
    check.knowledge_version_privileges !== true ||
    check.knowledge_version_mutation_denied !== true ||
    check.public_table_access_denied !== true
  ) {
    throw new Error(`Build 27 upgrade readiness failed: ${JSON.stringify(check)}`);
  }

  await expectLocationGuard(
    `UPDATE public.hdc_member_profiles
     SET location = 'Unsupported New Location'
     WHERE user_id = '11111111-1111-4111-8111-111111111111'`,
    'Member profile guard',
  );
  await expectLocationGuard(
    `UPDATE public.hdc_service_requests
     SET location = 'Unsupported New Location'
     WHERE id = 'REQ-UPGRADE-001'`,
    'Service-request guard',
  );
  await expectLocationGuard(
    `UPDATE public.hdc_platform_role_applications
     SET answers = '{"country":"Nowhere"}'::jsonb
     WHERE id = '44444444-4444-4444-8444-444444444444'`,
    'Role-application guard',
  );

  console.log(
    'Build 27 upgrade rehearsal preserved representative 0016 data and applied migrations 0017-0024.',
  );
} finally {
  if (upgradeSql) await upgradeSql.end({ timeout: 2 });
  if (databaseCreated) {
    await admin.unsafe(`DROP DATABASE ${upgradeDatabase}`);
  }
  await admin.end({ timeout: 2 });
}
