import type { DbClient } from './db.mjs';
import { json, methodNotAllowed } from './http.mjs';
import { TECHNICIAN_PUBLIC_FIELDS } from './profiles.mjs';

const text = (value: unknown): string => typeof value === 'string' ? value : '';
const number = (value: unknown): number | null => {
  if (typeof value !== 'number' && typeof value !== 'string') return null;
  if (value === '') return null;
  const result = Number(value);
  return Number.isFinite(result) && result >= 0 ? result : null;
};

export function technicianDirectoryEntryView(row: Record<string, unknown>) {
  const details = row.details && typeof row.details === 'object' &&
    !Array.isArray(row.details) ? row.details as Record<string, unknown> : {};
  // An old is_public flag is not consent to publish every field to guests.
  const visible = new Set(Array.isArray(details.publicFields)
    ? details.publicFields.filter((field): field is string =>
      typeof field === 'string' && TECHNICIAN_PUBLIC_FIELDS.some((key) => key === field))
    : []);
  const years = number(details.yearsExperience);
  const publicDetails: Record<string, unknown> = {
    yearsExperience: years !== null && Number.isInteger(years) && years <= 80 ? years : null,
  };
  for (const key of ['skills', 'specialties']) {
    if (visible.has(key) && Array.isArray(details[key])) {
      publicDetails[key] = details[key].filter((value) => typeof value === 'string');
    }
  }
  for (const key of ['serviceRadiusKm', 'hourlyRate']) {
    if (visible.has(key)) publicDetails[key] = number(details[key]);
  }
  if (visible.has('availability')) publicDetails.availability = text(details.availability);
  if (visible.has('emergencyService')) publicDetails.emergencyService = details.emergencyService === true;
  const ratingCount = number(row.rating_count) ?? 0;
  const averageRating = number(row.average_rating);
  let avatar = text(row.avatar_url);
  try {
    const url = new URL(avatar);
    avatar = url.protocol === 'https:' && !url.username && !url.password ? url.toString() : '';
  } catch { avatar = ''; }
  return {
    profileId: text(row.id),
    publicMemberId: text(row.public_member_id),
    publicName: text(row.public_name),
    avatarUrl: /^https:\/\//i.test(avatar) ? avatar : '',
    headline: visible.has('headline') ? text(row.headline) : '',
    description: visible.has('description') ? text(row.description) : '',
    location: visible.has('location') ? text(row.location) : '',
    contactEmail: visible.has('contactEmail') ? text(row.contact_email) : '',
    contactPhone: visible.has('contactPhone') ? text(row.contact_phone) : '',
    website: visible.has('website') ? text(row.website) : '',
    details: publicDetails,
    ratingCount,
    averageRating: ratingCount > 0 && averageRating !== null && averageRating >= 1 && averageRating <= 5
      ? averageRating : null,
    completedServices: number(row.completed_services) ?? 0,
    updatedAt: row.updated_at instanceof Date ? row.updated_at.toISOString() : text(row.updated_at),
  };
}

export async function handleTechnicianDirectory(
  req: Request,
  sql: DbClient,
  profileId: string | null = null,
): Promise<Response> {
  if (req.method !== 'GET') return methodNotAllowed();
  if (profileId !== null && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(profileId)) {
    return json({ error: 'technician_profile_not_found' }, 404);
  }
  const pageValue = new URL(req.url).searchParams.get('reviewPage') ?? '0';
  if (!/^\d{1,5}$/.test(pageValue) || Number(pageValue) > 10000) {
    return json({ error: 'invalid_review_page' }, 400);
  }
  const reviewPage = Number(pageValue);
  // One statement keeps approval, visibility, totals and reviews in one snapshot.
  // Reputation covers services delivered by this technician, never their purchases.
  const rows = await sql`
    SELECT profile.*, member.public_member_id, member_profile.avatar_url,
      reputation.rating_count, reputation.average_rating,
      completed.completed_services, recent.reviews
    FROM public.hdc_platform_role_profiles profile
    JOIN public.hdc_users member
      ON member.id = profile.user_id AND member.status = 'active'
    JOIN public.hdc_user_roles assignment
      ON assignment.user_id = profile.user_id
      AND assignment.role::text = 'technician'
      AND assignment.is_active = true AND assignment.status = 'active'
    LEFT JOIN public.hdc_member_profiles member_profile ON member_profile.user_id = profile.user_id
    LEFT JOIN LATERAL (
      SELECT count(*)::int AS rating_count, round(avg(rating.score)::numeric, 2) AS average_rating
      FROM public.hdc_transaction_ratings rating
      JOIN public.hdc_service_transactions service
        ON service.id = rating.service_transaction_id AND service.status = 'completed'
        AND service.technician_id = profile.user_id AND service.customer_id = rating.rater_member_id
      WHERE rating.rated_member_id = profile.user_id
        AND rating.transaction_kind = 'service' AND rating.status = 'active'
    ) reputation ON true
    LEFT JOIN LATERAL (
      SELECT count(*)::int AS completed_services
      FROM public.hdc_service_transactions service
      WHERE service.technician_id = profile.user_id AND service.status = 'completed'
    ) completed ON true
    LEFT JOIN LATERAL (
      SELECT jsonb_agg(item.value ORDER BY item.created_at DESC, item.id DESC) AS reviews
      FROM (
        SELECT rating.id, rating.created_at, jsonb_build_object(
          'publicRatingId', rating.public_rating_id, 'score', rating.score,
          'review', rating.review, 'createdAt', rating.created_at
        ) AS value
        FROM public.hdc_transaction_ratings rating
        JOIN public.hdc_service_transactions service
          ON service.id = rating.service_transaction_id AND service.status = 'completed'
          AND service.technician_id = profile.user_id AND service.customer_id = rating.rater_member_id
        WHERE ${profileId}::uuid IS NOT NULL AND rating.rated_member_id = profile.user_id
          AND rating.transaction_kind = 'service' AND rating.status = 'active'
        ORDER BY rating.created_at DESC, rating.id DESC
        LIMIT 20 OFFSET ${reviewPage * 20}
      ) item
    ) recent ON true
    WHERE profile.role = 'technician'
      AND (${profileId}::uuid IS NULL OR profile.id = ${profileId}::uuid)
    ORDER BY lower(profile.public_name), profile.id
  `;
  if (profileId !== null) {
    if (!rows[0]) return json({ error: 'technician_profile_not_found' }, 404);
    const technician = technicianDirectoryEntryView(rows[0]);
    return json({
      technician, reviews: rows[0].reviews ?? [], reviewPage,
      hasMoreReviews: (reviewPage + 1) * 20 < technician.ratingCount,
    });
  }
  return json({ technicians: rows.map(technicianDirectoryEntryView), updatedAt: new Date().toISOString() });
}
