import type { DbClient } from './db.mjs';
import { json, methodNotAllowed } from './http.mjs';
import { internalDashboardPermissions } from './internal-dashboard.mjs';
import type { InternalRoleCode } from './roles.mjs';

export type OperationsAccess = {
  userId: string;
  internalRoles: readonly InternalRoleCode[];
  allReviewRoles: boolean;
  reviewRoles: readonly string[];
  canReviewRecovery: boolean;
};

type ReportDefinition = {
  title: string;
  description: string;
  current: string;
  source: string;
};

// These projections are intentionally explicit: account credentials, recovery
// answers, token identifiers, and security fingerprints are never report data.
const assignments = `
  SELECT a.id::text, coalesce(nullif(a.title, ''), d.name) AS title,
    u.display_name || ' · ' || d.name AS subtitle,
    CASE WHEN a.is_active AND d.is_active AND (s.id IS NULL OR s.is_active)
      THEN 'active' ELSE 'inactive' END AS status,
    a.created_at, a.updated_at, a.user_id,
    jsonb_build_object('Member', u.display_name, 'Member ID', u.public_member_id,
      'Title', a.title, 'Department', d.name, 'Section', s.name,
      'Assigned by', assigner.display_name) AS data
  FROM public.hdc_internal_staff_assignments a
  JOIN public.hdc_users u ON u.id = a.user_id
  JOIN public.hdc_internal_departments d ON d.id = a.department_id
  LEFT JOIN public.hdc_internal_department_sections s ON s.id = a.section_id
  LEFT JOIN public.hdc_users assigner ON assigner.id = a.assigned_by`;

const knowledge = `
  SELECT a.id::text, a.title, a.public_article_id AS subtitle, a.status,
    a.created_at, a.updated_at, a.published_version,
    jsonb_build_object('Article ID', a.public_article_id, 'Category', a.category,
      'Created by', author.display_name, 'Creator member ID', author.public_member_id,
      'Last edited by', editor.display_name,
      'Submitted for review by', reviewer.display_name,
      'Reviewer member ID', reviewer.public_member_id, 'Submitted for review at', review.created_at,
      'Published by', publisher.display_name, 'Publisher member ID', publisher.public_member_id,
      'Published at', published.published_at, 'Working version', a.version,
      'Published version', a.published_version, 'Working summary', a.summary,
      'Working guide', a.body, 'Working steps', a.steps, 'Tags', a.tags,
      'Published guide', CASE WHEN published.id IS NULL THEN NULL ELSE
        jsonb_build_object('Title', published.title, 'Summary', published.summary,
          'Guide', published.body, 'Steps', published.steps,
          'Safety notice', published.safety_notice, 'Escalation', published.escalation_text) END,
      'Safety level', a.safety_level, 'Safety notice', a.safety_notice,
      'Escalation', a.escalation_text, 'Available to Nexus', a.nexus_ready) AS data
  FROM public.hdc_knowledge_articles a
  LEFT JOIN public.hdc_users author ON author.id = a.created_by
  LEFT JOIN public.hdc_users editor ON editor.id = a.updated_by
  LEFT JOIN LATERAL (
    SELECT created_by, created_at FROM public.hdc_knowledge_article_versions
    WHERE article_id = a.id AND workflow_status = 'review'
    ORDER BY version DESC LIMIT 1
  ) review ON true
  LEFT JOIN public.hdc_users reviewer ON reviewer.id = review.created_by
  LEFT JOIN public.hdc_knowledge_article_versions published
    ON published.article_id = a.id AND published.version = a.published_version
  LEFT JOIN public.hdc_users publisher ON publisher.id = published.created_by`;

export const operationsReports: Record<string, ReportDefinition> = {
  myAssignments: {
    title: 'My assignments', description: 'Your recorded staff assignments and their departments.',
    current: "status = 'active'", source: assignments + ' WHERE a.user_id = (SELECT actor_id FROM scope)',
  },
  activeStaffAssignments: {
    title: 'Staff assignments', description: 'Staff members, departments, sections, and assignment status.',
    current: "status = 'active'", source: assignments,
  },
  activeDepartments: {
    title: 'Departments', description: 'Department records and active or inactive status.',
    current: "status = 'active'", source: `
      SELECT d.id::text, d.name AS title, d.code AS subtitle,
        CASE WHEN d.is_active THEN 'active' ELSE 'inactive' END AS status,
        d.created_at, d.updated_at,
        jsonb_build_object('Code', d.code, 'Description', d.description,
          'Created by', u.display_name) AS data
      FROM public.hdc_internal_departments d
      LEFT JOIN public.hdc_users u ON u.id = d.created_by`,
  },
  activeSections: {
    title: 'Department sections', description: 'Sections and the department each belongs to.',
    current: "status = 'active'", source: `
      SELECT s.id::text, s.name AS title, d.name AS subtitle,
        CASE WHEN s.is_active AND d.is_active THEN 'active' ELSE 'inactive' END AS status,
        s.created_at, s.updated_at,
        jsonb_build_object('Code', s.code, 'Description', s.description,
          'Department', d.name, 'Created by', u.display_name) AS data
      FROM public.hdc_internal_department_sections s
      JOIN public.hdc_internal_departments d ON d.id = s.department_id
      LEFT JOIN public.hdc_users u ON u.id = s.created_by`,
  },
  activeMembers: {
    title: 'Registered members',
    description: 'Active means the account is enabled. It does not mean the member is online now.',
    current: "status = 'active'", source: `
      SELECT u.id::text, u.display_name AS title, u.public_member_id AS subtitle,
        u.status, u.created_at, u.updated_at,
        jsonb_build_object('Member ID', u.public_member_id, 'Display name', u.display_name,
          'Email', u.email, 'Email verified', u.email_verified,
          'About', p.bio, 'Location', p.location, 'Preferred contact', p.contact_preference,
          'Platform roles', (SELECT coalesce(jsonb_agg(role::text ORDER BY role::text), '[]')
            FROM public.hdc_user_roles WHERE user_id = u.id AND status = 'active'),
          'Internal roles', (SELECT coalesce(jsonb_agg(role ORDER BY role), '[]')
            FROM public.hdc_internal_role_assignments WHERE user_id = u.id AND is_active)) AS data
      FROM public.hdc_users u
      LEFT JOIN public.hdc_member_profiles p ON p.user_id = u.id`,
  },
  pendingRoleApplications: {
    title: 'Role applications', description: 'Applications within your authorized review scope.',
    current: "status IN ('submitted', 'under_review')", source: `
      SELECT a.id::text, u.display_name AS title, a.role AS subtitle, a.status,
        a.created_at, a.updated_at,
        jsonb_build_object('Member ID', u.public_member_id, 'Email', u.email,
          'Requested role', a.role, 'Applicant note', a.applicant_note,
          'Application answers', a.answers, 'Submitted at', a.submitted_at,
          'Reviewed by', reviewer.display_name, 'Reviewed at', a.reviewed_at,
          'Review note', a.review_note) AS data
      FROM public.hdc_platform_role_applications a
      JOIN public.hdc_users u ON u.id = a.user_id
      LEFT JOIN public.hdc_users reviewer ON reviewer.id = a.reviewed_by
      WHERE (SELECT all_roles FROM scope)
        OR a.role IN (SELECT jsonb_array_elements_text(roles) FROM scope)`,
  },
  pendingRecoveryReviews: {
    title: 'Account recovery reviews', description: 'Recovery review status and recorded staff decisions.',
    current: "status = 'pending'", source: `
      SELECT r.id::text, u.display_name AS title, u.public_member_id AS subtitle,
        r.status, r.created_at, r.updated_at,
        jsonb_build_object('Member ID', u.public_member_id, 'Email', u.email,
          'Delivery status', r.delivery_status, 'Reviewed by', reviewer.display_name,
          'Reviewed at', r.reviewed_at, 'Reviewer note', r.reviewer_note) AS data
      FROM public.hdc_account_recovery_review_requests r
      JOIN public.hdc_users u ON u.id = r.user_id
      LEFT JOIN public.hdc_users reviewer ON reviewer.id = r.reviewed_by`,
  },
  pendingDisputes: {
    title: 'Disputes', description: 'Individual cases, participants, requested outcomes, evidence, and case history.',
    current: "status IN ('open', 'underReview')", source: `
      SELECT d.id, t.request_title AS title, d.id AS subtitle, d.status,
        d.created_at, d.updated_at,
        jsonb_build_object('Transaction ID', d.transaction_id, 'Customer', t.customer_name,
          'Technician', t.technician_name, 'Opened by', opener.display_name,
          'Reason', d.reason_code, 'Summary', d.summary, 'Requested outcome', d.requested_outcome,
          'Previous service status', d.prior_transaction_status,
          'Resolution outcome', d.resolution_outcome, 'Resolution note', d.resolution_note,
          'Resolved by', resolver.display_name, 'Resolved at', d.resolved_at,
          'Version', d.version) AS data
      FROM public.hdc_service_disputes d
      JOIN public.hdc_service_transactions t ON t.id = d.transaction_id
      LEFT JOIN public.hdc_users opener ON opener.id = d.opened_by
      LEFT JOIN public.hdc_users resolver ON resolver.id = d.resolved_by`,
  },
  openServiceRequests: {
    title: 'Service requests', description: 'Requests, customer requirements, budgets, and their current status.',
    current: "status IN ('open', 'receivingOffers', 'technicianSelected', 'inProgress')", source: `
      SELECT r.id, r.title, r.customer_name AS subtitle, r.status, r.created_at, r.updated_at,
        jsonb_build_object('Customer', r.customer_name, 'Customer member ID', u.public_member_id,
          'Category', r.category_name, 'Description', r.description, 'Location', r.location,
          'Preferred date', r.preferred_date, 'Preferred time', r.preferred_time,
          'Urgency', r.urgency, 'Minimum budget (PHP)', r.minimum_budget,
          'Maximum budget (PHP)', r.maximum_budget, 'Offers', r.offer_count, 'Version', r.version) AS data
      FROM public.hdc_service_requests r JOIN public.hdc_users u ON u.id = r.customer_id`,
  },
  activeServiceTransactions: {
    title: 'Service transactions', description: 'Participants, accepted terms, progression, and recorded service activity.',
    current: "status NOT IN ('completed', 'cancelled')", source: `
      SELECT t.id, t.request_title AS title,
        t.customer_name || ' · ' || t.technician_name AS subtitle, t.status, t.created_at, t.updated_at,
        jsonb_build_object('Request ID', t.request_id, 'Proposal ID', t.proposal_id,
          'Customer', t.customer_name, 'Technician', t.technician_name,
          'Category', t.category_name, 'Service location', t.service_location,
          'Accepted terms', t.accepted_terms, 'Activity', t.activity, 'Version', t.version) AS data
      FROM public.hdc_service_transactions t`,
  },
  knowledgeReview: {
    title: 'Knowledge Base review', description: 'Guide authors, review submissions, and publication attribution.',
    current: "status = 'review'", source: knowledge,
  },
  publishedKnowledge: {
    title: 'Published Knowledge Base', description: 'Guides with a current public version and the account that published it.',
    current: "published_version IS NOT NULL AND status <> 'archived'", source: knowledge,
  },
};

export function allowedOperationsReports(access: OperationsAccess): string[] {
  if (!access.internalRoles.length) return [];
  const p = internalDashboardPermissions(access.internalRoles);
  return [
    'myAssignments',
    ...(access.allReviewRoles || access.reviewRoles.length ? ['pendingRoleApplications'] : []),
    ...(access.canReviewRecovery ? ['pendingRecoveryReviews'] : []),
    ...(p.canApprovePlatformRoles ? ['pendingDisputes'] : []),
    ...(p.canManageInternalStructure ? ['activeDepartments', 'activeSections', 'activeStaffAssignments'] : []),
    ...(p.hasPrivilegedResourceAccess ? [
      'activeMembers', 'openServiceRequests', 'activeServiceTransactions', 'knowledgeReview', 'publishedKnowledge',
    ] : []),
  ];
}

export async function knowledgeOperationsOverview(sql: DbClient) {
  const rows = await sql.unsafe(`
    WITH articles AS NOT MATERIALIZED (${knowledge})
    SELECT (SELECT count(*)::int FROM articles WHERE status = 'review') AS review_count,
      (SELECT count(*)::int FROM articles
        WHERE published_version IS NOT NULL AND status <> 'archived') AS published_count,
      coalesce((SELECT jsonb_agg(to_jsonb(recent)) FROM (
        SELECT id, title, status, updated_at,
          data->>'Created by' AS created_by,
          data->>'Creator member ID' AS creator_member_id,
          data->>'Submitted for review by' AS submitted_by,
          data->>'Reviewer member ID' AS submitter_member_id,
          data->>'Published by' AS published_by,
          data->>'Publisher member ID' AS publisher_member_id
        FROM articles ORDER BY updated_at DESC, id DESC LIMIT 6
      ) recent), '[]'::jsonb) AS activities`);
  return {
    reviewCount: Number(rows[0]?.review_count ?? 0),
    publishedCount: Number(rows[0]?.published_count ?? 0),
    activities: rows[0]?.activities ?? [],
  };
}

export async function handleOperationsReport(
  req: Request, sql: DbClient, access: OperationsAccess,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  const params = new URL(req.url).searchParams;
  const key = params.get('report') ?? '';
  if (!Object.hasOwn(operationsReports, key)) return json({ error: 'invalid_operations_report' }, 400);
  if (!allowedOperationsReports(access).includes(key)) return json({ error: 'operations_report_forbidden' }, 403);
  const scope = params.get('scope') ?? 'current';
  const query = (params.get('q') ?? '').trim();
  const id = params.get('id') ?? '';
  const offsetText = params.get('offset') ?? '0';
  const limitText = params.get('limit') ?? '25';
  const offset = Number(offsetText);
  const limit = Number(limitText);
  const section = params.get('section') ?? '';
  const sectionOffsetText = params.get('sectionOffset') ?? '0';
  const sectionOffset = Number(sectionOffsetText);
  const sectionKeys = key === 'pendingDisputes' ? ['history', 'evidence']
    : ['knowledgeReview', 'publishedKnowledge'].includes(key) ? ['versions'] : [];
  if (!['current', 'all'].includes(scope) || query.length > 180 ||
      (params.has('id') && !/^[A-Za-z0-9_-]{1,100}$/.test(id)) ||
      !/^\d+$/.test(offsetText) || !Number.isSafeInteger(offset) || offset > 1_000_000 ||
      !/^\d+$/.test(limitText) || !Number.isInteger(limit) || limit < 1 || limit > 100 ||
      (section !== '' && (!id || !sectionKeys.includes(section))) ||
      !/^\d+$/.test(sectionOffsetText) || !Number.isSafeInteger(sectionOffset) ||
      sectionOffset > 1_000_000 || (sectionOffset > 0 && !section)) {
    return json({ error: 'invalid_operations_filters' }, 400);
  }
  const definition = operationsReports[key];
  // Only the fixed, server-owned definition is interpolated. Every request and
  // access value remains a bound SQL parameter, including record identifiers.
  const rows = await sql.unsafe(`
    WITH scope AS (SELECT $1::uuid AS actor_id, $2::boolean AS all_roles, $3::jsonb AS roles),
    report_rows AS (${definition.source}), filtered AS (
      SELECT r.id, r.title, r.subtitle, r.status, r.created_at, r.updated_at,
        CASE WHEN $8::text <> '' THEN r.data ELSE '{}'::jsonb END AS data
      FROM report_rows r
      WHERE CASE WHEN $8::text <> '' THEN r.id = $8 ELSE
        ($4::text = 'all' OR (${definition.current})) AND
        ($5::text = '' OR position(lower($5) in lower(r.title || ' ' || r.subtitle || ' ' || r.id)) > 0)
      END
    )
    SELECT (SELECT count(*)::int FROM filtered) AS total,
      coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM (
        SELECT id, title, subtitle, status, created_at, updated_at, data FROM filtered
        ORDER BY updated_at DESC, id DESC LIMIT $6 OFFSET $7
      ) page), '[]'::jsonb) AS records`,
  [access.userId, access.allReviewRoles, JSON.stringify(access.reviewRoles), scope, query,
    id ? 1 : limit, id ? 0 : offset, id]);
  const records = (rows[0]?.records ?? []) as Record<string, unknown>[];
  if (id && records.length === 0) return json({ error: 'operations_record_not_found' }, 404);
  const sections = id ? await recordSections(sql, key, id, section, sectionOffset) : [];
  const total = Number(rows[0]?.total ?? 0);
  return json({
    privateWorkspace: true, userId: access.userId, report: key,
    title: definition.title, description: definition.description,
    scope, query, total, offset: id ? 0 : offset, limit,
    hasMore: !id && offset + records.length < total, records, sections,
    generatedAt: new Date().toISOString(),
  });
}

async function recordSections(sql: DbClient, key: string, id: string, section: string, offset: number) {
  const page = (key: string, title: string, items: Record<string, unknown>[]) => ({
    key, title, items: items.slice(0, 25), hasMore: items.length > 25,
    nextOffset: offset + Math.min(items.length, 25),
  });
  if (key === 'pendingDisputes') {
    const sections = [];
    if (!section || section === 'history') {
      const events = await sql`
      SELECT e.event_type AS title, e.message, e.created_at, u.display_name AS actor
      FROM public.hdc_service_dispute_events e
      LEFT JOIN public.hdc_users u ON u.id = e.actor_id
      WHERE e.dispute_id = ${id} ORDER BY e.created_at, e.id LIMIT 26 OFFSET ${offset}`;
      sections.push(page('history', 'Case history', events));
    }
    if (!section || section === 'evidence') {
      const documents = await sql`
      SELECT d.title, d.document_type AS type, d.content_text AS content, d.status, d.created_at,
        u.display_name AS author
      FROM public.hdc_service_documents d LEFT JOIN public.hdc_users u ON u.id = d.created_by
      WHERE d.dispute_id = ${id} ORDER BY d.created_at, d.id LIMIT 26 OFFSET ${offset}`;
      sections.push(page('evidence', 'Dispute evidence', documents));
    }
    return sections;
  }
  if (key === 'knowledgeReview' || key === 'publishedKnowledge') {
    const versions = await sql`
      SELECT v.version, v.workflow_status AS status, v.change_note, v.created_at, v.published_at,
        u.display_name AS author, u.public_member_id AS member_id
      FROM public.hdc_knowledge_article_versions v
      LEFT JOIN public.hdc_users u ON u.id = v.created_by
      WHERE v.article_id = ${id}::uuid ORDER BY v.version DESC LIMIT 26 OFFSET ${offset}`;
    return [page('versions', 'Version and publication history', versions)];
  }
  return [];
}
