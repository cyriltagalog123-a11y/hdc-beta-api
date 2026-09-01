export const PORTABLE_PRIVILEGES_VERSION = 1;

const ALLOWED_GRANTEES = new Set(['PUBLIC', 'hdc_app']);
const PRIVILEGES = Object.freeze({
  SCHEMA: new Set(['CREATE', 'USAGE']),
  TABLE: new Set([
    'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES',
    'TRIGGER', 'MAINTAIN',
  ]),
  SEQUENCE: new Set(['USAGE', 'SELECT', 'UPDATE']),
  FUNCTION: new Set(['EXECUTE']),
  PROCEDURE: new Set(['EXECUTE']),
  DOMAIN: new Set(['USAGE']),
  TYPE: new Set(['USAGE']),
  COLUMN: new Set(['SELECT', 'INSERT', 'UPDATE', 'REFERENCES']),
});

const CAPTURE_SQL = `
  WITH portable_objects AS (
    SELECT
      'SCHEMA'::text AS object_kind,
      n.oid AS object_oid,
      n.nspname AS schema_name,
      n.nspname AS object_name,
      ''::text AS identity_arguments,
      ''::text AS column_name
    FROM pg_namespace n
    WHERE n.nspname = 'public'

    UNION ALL

    SELECT
      CASE WHEN c.relkind = 'S' THEN 'SEQUENCE' ELSE 'TABLE' END,
      c.oid,
      n.nspname,
      c.relname,
      '',
      ''
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND left(c.relname, 4) = 'hdc_'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'f', 'S')

    UNION ALL

    SELECT
      CASE WHEN p.prokind = 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
      p.oid,
      n.nspname,
      p.proname,
      pg_get_function_identity_arguments(p.oid),
      ''
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND left(p.proname, 4) = 'hdc_'
      AND p.prokind IN ('f', 'p')

    UNION ALL

    SELECT
      CASE WHEN t.typtype = 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
      t.oid,
      n.nspname,
      t.typname,
      '',
      ''
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND left(t.typname, 4) = 'hdc_'
      AND t.typtype IN ('d', 'e')
  ),
  effective_acl AS (
    SELECT
      'SCHEMA'::text AS object_kind,
      n.oid AS object_oid,
      ''::text AS column_name,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE grantee.rolname END
        AS grantee_name,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_namespace n
    CROSS JOIN LATERAL aclexplode(
      COALESCE(n.nspacl, acldefault('n', n.nspowner))
    ) acl
    LEFT JOIN pg_roles grantee ON grantee.oid = acl.grantee
    WHERE n.nspname = 'public'
      AND (acl.grantee = 0 OR grantee.rolname = 'hdc_app')

    UNION ALL

    SELECT
      CASE WHEN c.relkind = 'S' THEN 'SEQUENCE' ELSE 'TABLE' END,
      c.oid,
      '',
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE grantee.rolname END,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(COALESCE(
      c.relacl,
      acldefault(
        (CASE WHEN c.relkind = 'S' THEN 'S' ELSE 'r' END)::"char",
        c.relowner
      )
    )) acl
    LEFT JOIN pg_roles grantee ON grantee.oid = acl.grantee
    WHERE n.nspname = 'public'
      AND left(c.relname, 4) = 'hdc_'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'f', 'S')
      AND (acl.grantee = 0 OR grantee.rolname = 'hdc_app')

    UNION ALL

    SELECT
      CASE WHEN p.prokind = 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
      p.oid,
      '',
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE grantee.rolname END,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    CROSS JOIN LATERAL aclexplode(
      COALESCE(p.proacl, acldefault('f', p.proowner))
    ) acl
    LEFT JOIN pg_roles grantee ON grantee.oid = acl.grantee
    WHERE n.nspname = 'public'
      AND left(p.proname, 4) = 'hdc_'
      AND p.prokind IN ('f', 'p')
      AND (acl.grantee = 0 OR grantee.rolname = 'hdc_app')

    UNION ALL

    SELECT
      CASE WHEN t.typtype = 'd' THEN 'DOMAIN' ELSE 'TYPE' END,
      t.oid,
      '',
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE grantee.rolname END,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    CROSS JOIN LATERAL aclexplode(
      COALESCE(t.typacl, acldefault('T', t.typowner))
    ) acl
    LEFT JOIN pg_roles grantee ON grantee.oid = acl.grantee
    WHERE n.nspname = 'public'
      AND left(t.typname, 4) = 'hdc_'
      AND t.typtype IN ('d', 'e')
      AND (acl.grantee = 0 OR grantee.rolname = 'hdc_app')
  ),
  object_rows AS (
    SELECT
      object.object_kind,
      object.schema_name,
      object.object_name,
      object.identity_arguments,
      object.column_name,
      acl.grantee_name,
      acl.privilege_type,
      acl.is_grantable
    FROM portable_objects object
    LEFT JOIN effective_acl acl
      ON acl.object_kind = object.object_kind
      AND acl.object_oid = object.object_oid
      AND acl.column_name = object.column_name
  ),
  column_rows AS (
    SELECT
      'COLUMN'::text AS object_kind,
      n.nspname AS schema_name,
      c.relname AS object_name,
      ''::text AS identity_arguments,
      attribute.attname AS column_name,
      CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE grantee.rolname END
        AS grantee_name,
      acl.privilege_type,
      acl.is_grantable
    FROM pg_attribute attribute
    JOIN pg_class c ON c.oid = attribute.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(attribute.attacl) acl
    LEFT JOIN pg_roles grantee ON grantee.oid = acl.grantee
    WHERE n.nspname = 'public'
      AND left(c.relname, 4) = 'hdc_'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
      AND attribute.attnum > 0
      AND NOT attribute.attisdropped
      AND (acl.grantee = 0 OR grantee.rolname = 'hdc_app')
  )
  SELECT * FROM object_rows
  UNION ALL
  SELECT * FROM column_rows
  ORDER BY
    object_kind,
    schema_name,
    object_name,
    identity_arguments,
    column_name,
    grantee_name,
    privilege_type,
    is_grantable
`;

function keyOf(object) {
  return [
    object.kind,
    object.schema,
    object.name,
    object.identityArguments ?? '',
    object.column ?? '',
  ].join('\u0000');
}

function quoteIdentifier(value) {
  return `"${value.replaceAll('"', '""')}"`;
}

function granteeSql(grantee) {
  return grantee === 'PUBLIC' ? 'PUBLIC' : quoteIdentifier(grantee);
}

function assertSafeIdentityArguments(value) {
  if (
    value.length > 1_000 ||
    /[;()'\\\r\n]/.test(value) ||
    value.includes('--') ||
    value.includes('/*') ||
    value.includes('*/') ||
    !/^[A-Za-z0-9_., "\[\]]*$/.test(value)
  ) {
    throw new Error('Portable routine identity arguments are unsafe.');
  }
}

export function normalizePortablePrivileges(snapshot) {
  if (
    !snapshot ||
    typeof snapshot !== 'object' ||
    Array.isArray(snapshot) ||
    snapshot.version !== PORTABLE_PRIVILEGES_VERSION ||
    !Array.isArray(snapshot.objects) ||
    snapshot.objects.length === 0 ||
    snapshot.objects.length > 1_000
  ) {
    throw new Error('The portable HDC privilege snapshot is invalid.');
  }

  const seen = new Set();
  let grantCount = 0;
  const objects = snapshot.objects.map((candidate) => {
    if (!candidate || typeof candidate !== 'object' || Array.isArray(candidate)) {
      throw new Error('A portable HDC privilege object is invalid.');
    }
    const kind = String(candidate.kind ?? '');
    const schema = String(candidate.schema ?? '');
    const name = String(candidate.name ?? '');
    const identityArguments = String(candidate.identityArguments ?? '');
    const column = String(candidate.column ?? '');
    if (!PRIVILEGES[kind] || schema !== 'public') {
      throw new Error('A portable HDC privilege target is invalid.');
    }
    if (kind === 'SCHEMA') {
      if (name !== 'public' || identityArguments || column) {
        throw new Error('The portable schema privilege target is invalid.');
      }
    } else if (!/^hdc_[a-z0-9_]+$/.test(name)) {
      throw new Error('A portable HDC object name is invalid.');
    }
    if (kind === 'FUNCTION' || kind === 'PROCEDURE') {
      assertSafeIdentityArguments(identityArguments);
      if (column) throw new Error('A portable routine column is invalid.');
    } else if (identityArguments) {
      throw new Error('Unexpected portable routine identity arguments.');
    }
    if (kind === 'COLUMN') {
      if (!/^[a-z][a-z0-9_]*$/.test(column)) {
        throw new Error('A portable HDC column name is invalid.');
      }
    } else if (column) {
      throw new Error('Unexpected portable HDC column metadata.');
    }

    const grants = Array.isArray(candidate.grants) ? candidate.grants : null;
    if (!grants) throw new Error('Portable HDC grants are invalid.');
    const grantSeen = new Set();
    const normalizedGrants = grants.map((grant) => {
      const grantee = String(grant?.grantee ?? '');
      const privilege = String(grant?.privilege ?? '').toUpperCase();
      const grantable = grant?.grantable;
      if (
        !ALLOWED_GRANTEES.has(grantee) ||
        !PRIVILEGES[kind].has(privilege) ||
        typeof grantable !== 'boolean'
      ) {
        throw new Error('A portable HDC grant is invalid.');
      }
      const grantKey = `${grantee}\u0000${privilege}`;
      if (grantSeen.has(grantKey)) {
        throw new Error('A portable HDC grant is duplicated.');
      }
      grantSeen.add(grantKey);
      grantCount += 1;
      if (grantCount > 10_000) {
        throw new Error('The portable HDC privilege snapshot is too large.');
      }
      return { grantee, privilege, grantable };
    }).sort((left, right) =>
      left.grantee.localeCompare(right.grantee) ||
      left.privilege.localeCompare(right.privilege));

    const normalized = {
      kind,
      schema,
      name,
      ...(identityArguments ? { identityArguments } : {}),
      ...(column ? { column } : {}),
      grants: normalizedGrants,
    };
    const objectKey = keyOf(normalized);
    if (seen.has(objectKey)) {
      throw new Error('A portable HDC privilege target is duplicated.');
    }
    seen.add(objectKey);
    return normalized;
  }).sort((left, right) => keyOf(left).localeCompare(keyOf(right)));

  for (const required of [
    'SCHEMA\u0000public\u0000public\u0000\u0000',
    'TABLE\u0000public\u0000hdc_schema_migrations\u0000\u0000',
    'TABLE\u0000public\u0000hdc_users\u0000\u0000',
  ]) {
    if (!seen.has(required)) {
      throw new Error('The portable HDC privilege snapshot is incomplete.');
    }
  }

  return { version: PORTABLE_PRIVILEGES_VERSION, objects };
}

export async function capturePortablePrivileges(sql) {
  const rows = await sql.unsafe(CAPTURE_SQL);
  const objects = new Map();
  for (const row of rows) {
    const candidate = {
      kind: String(row.object_kind),
      schema: String(row.schema_name),
      name: String(row.object_name),
      ...(row.identity_arguments
        ? { identityArguments: String(row.identity_arguments) }
        : {}),
      ...(row.column_name ? { column: String(row.column_name) } : {}),
      grants: [],
    };
    const objectKey = keyOf(candidate);
    const object = objects.get(objectKey) ?? candidate;
    if (row.grantee_name) {
      object.grants.push({
        grantee: String(row.grantee_name),
        privilege: String(row.privilege_type),
        grantable: row.is_grantable === true,
      });
    }
    objects.set(objectKey, object);
  }
  return normalizePortablePrivileges({
    version: PORTABLE_PRIVILEGES_VERSION,
    objects: [...objects.values()],
  });
}

function targetSql(object) {
  const qualified = `${quoteIdentifier(object.schema)}.${quoteIdentifier(object.name)}`;
  if (object.kind === 'SCHEMA') return quoteIdentifier(object.name);
  if (object.kind === 'FUNCTION' || object.kind === 'PROCEDURE') {
    return `${qualified}(${object.identityArguments ?? ''})`;
  }
  return qualified;
}

export function renderPortablePrivilegeStatements(snapshot) {
  const normalized = normalizePortablePrivileges(snapshot);
  const statements = [];
  for (const object of normalized.objects) {
    const target = targetSql(object);
    if (object.kind === 'COLUMN') {
      const column = quoteIdentifier(object.column);
      statements.push(
        `REVOKE ALL PRIVILEGES (${column}) ON TABLE ${target} ` +
        'FROM PUBLIC, "hdc_app";',
      );
    } else {
      statements.push(
        `REVOKE ALL PRIVILEGES ON ${object.kind} ${target} ` +
        'FROM PUBLIC, "hdc_app";',
      );
    }

    for (const grantee of ['PUBLIC', 'hdc_app']) {
      for (const grantable of [false, true]) {
        const privileges = object.grants
          .filter((grant) =>
            grant.grantee === grantee && grant.grantable === grantable)
          .map((grant) => grant.privilege);
        if (privileges.length === 0) continue;
        const privilegeSql = object.kind === 'COLUMN'
          ? privileges.map((privilege) =>
            `${privilege} (${quoteIdentifier(object.column)})`).join(', ')
          : privileges.join(', ');
        const targetKind = object.kind === 'COLUMN' ? 'TABLE' : object.kind;
        statements.push(
          `GRANT ${privilegeSql} ON ${targetKind} ${target} TO ` +
          `${granteeSql(grantee)}${grantable ? ' WITH GRANT OPTION' : ''};`,
        );
      }
    }
  }
  return statements;
}

export async function applyPortablePrivileges(sql, snapshot) {
  const normalized = normalizePortablePrivileges(snapshot);
  const statements = renderPortablePrivilegeStatements(normalized);
  await sql.begin(async (transaction) => {
    for (const statement of statements) {
      await transaction.unsafe(statement);
    }
  });
  const restored = await capturePortablePrivileges(sql);
  if (JSON.stringify(restored) !== JSON.stringify(normalized)) {
    throw new Error('Restored HDC privileges do not match the authenticated backup.');
  }
  return restored;
}
