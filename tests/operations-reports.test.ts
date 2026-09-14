import { describe, expect, it, vi } from 'vitest';
import type { DbClient } from '../netlify/functions/_lib/db.mjs';
import { allowedOperationsReports, handleOperationsReport, type OperationsAccess } from '../netlify/functions/_lib/operations-reports.mjs';

const owner: OperationsAccess = {
  userId: '00000000-0000-0000-0000-000000000001', internalRoles: ['owner'],
  allReviewRoles: true, reviewRoles: [], canReviewRecovery: true,
};
const request = (query: string, method = 'GET') => new Request(`https://hdc.test/api/internal/reports?${query}`, { method });

describe('private operations reports', () => {
  it('separates member, moderator, delegated reviewer, admin and owner authority', () => {
    expect(allowedOperationsReports({ ...owner, internalRoles: [] })).toEqual([]);
    const moderator: OperationsAccess = { ...owner, internalRoles: ['moderator'], allReviewRoles: false, canReviewRecovery: false };
    expect(allowedOperationsReports(moderator)).toEqual(['myAssignments']);
    expect(allowedOperationsReports({ ...moderator, reviewRoles: ['technician'] }))
      .toEqual(['myAssignments', 'pendingRoleApplications']);
    const admin = allowedOperationsReports({ ...moderator, internalRoles: ['admin'] });
    expect(admin).toContain('activeMembers');
    expect(admin).toContain('knowledgeReview');
    expect(admin).not.toContain('pendingDisputes');
    expect(admin).not.toContain('activeDepartments');
    expect(allowedOperationsReports(owner)).toHaveLength(12);
  });

  it.each(['report=__proto__', 'report=activeMembers&scope=disabled', 'report=activeMembers&limit=101',
    'report=activeMembers&offset=-1', 'report=activeMembers&offset=1.5', 'report=activeMembers&id=',
    'report=activeMembers&id=a%27', 'report=pendingDisputes&section=history',
    'report=pendingDisputes&id=case&sectionOffset=25', 'report=knowledgeReview&id=guide&section=evidence'])
  ('rejects invalid filters without querying: %s', async (query) => {
    const unsafe = vi.fn();
    const response = await handleOperationsReport(request(query), { unsafe } as unknown as DbClient, owner);
    expect(response.status).toBe(400);
    expect(unsafe).not.toHaveBeenCalled();
  });

  it('rejects unauthorized reports and mutations before reading records', async () => {
    const unsafe = vi.fn();
    const sql = { unsafe } as unknown as DbClient;
    const response = await handleOperationsReport(request('report=pendingDisputes&id=case'), sql,
      { ...owner, internalRoles: ['admin'] });
    expect(response.status).toBe(403);
    expect((await handleOperationsReport(request('report=activeMembers', 'POST'), sql, owner)).status).toBe(405);
    expect(unsafe).not.toHaveBeenCalled();
  });

  it('binds search text and review scope as values, and returns bounded navigation', async () => {
    const unsafe = vi.fn().mockResolvedValue([{total: 3, records: [{id: 'two'}]}]);
    const response = await handleOperationsReport(request("report=pendingRoleApplications&limit=1&offset=1&q=%27%20OR%201%3D1"),
      { unsafe } as unknown as DbClient, { ...owner, allReviewRoles: false, reviewRoles: ['technician'] });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ total: 3, offset: 1, limit: 1, hasMore: true, userId: owner.userId });
    const [query, values] = unsafe.mock.calls[0];
    expect(query).not.toContain("' OR 1=1");
    expect(values).toEqual([owner.userId, false, '["technician"]', 'current', "' OR 1=1", 1, 1, '']);
  });

  it('returns not found without looking up a history for an inaccessible record', async () => {
    const unsafe = vi.fn().mockResolvedValue([{total: 0, records: []}]);
    expect((await handleOperationsReport(request('report=knowledgeReview&id=missing'),
      { unsafe } as unknown as DbClient, owner)).status).toBe(404);
    expect(unsafe).toHaveBeenCalledOnce();
  });
});
