import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 24A Customer request and Technician discovery redesign', () => {
  it('keeps the public release identity synchronized to Build 24', () => {
    const login = read('lib/features/authentication/login_screen.dart');

    expect(login).toContain('CONTROLLED BETA • BUILD 24');
    expect(login).not.toContain('CONTROLLED BETA • BUILD 23');
  });

  it('provides shared responsive flow primitives', () => {
    const flow = read('lib/core/ui/hdc_flow.dart');

    for (const component of [
      'class HDCFlowHero',
      'class HDCFlowProgress',
      'class HDCSectionCard',
      'class HDCResponsiveActions',
      'class HDCMetricTile',
      'class HDCEmptyState',
    ]) {
      expect(flow).toContain(component);
    }
    expect(flow).toContain('constraints.maxWidth >= breakpoint');
  });

  it('keeps request intake validation and provider-backed publication intact', () => {
    const create = read(
      'lib/features/service_requests/create_service_request_screen.dart',
    );
    const review = read(
      'lib/features/service_requests/review_service_request_screen.dart',
    );

    for (const marker of [
      "Key('hdc-request-title')",
      "Key('hdc-request-category')",
      "Key('hdc-request-description')",
      "Key('hdc-request-location')",
      "Key('hdc-request-review')",
      "steps: ['Describe', 'Review', 'Publish']",
      'requireRegisteredUser',
    ]) {
      expect(create).toContain(marker);
    }

    for (const marker of [
      "Key('hdc-request-edit-details')",
      "Key('hdc-request-publish')",
      'ServiceRequestProvider.createRequestId()',
      'await provider.publish(',
      'await provider.updateRequest(',
      'pushAndRemoveUntil',
    ]) {
      expect(review).toContain(marker);
    }
  });

  it('uses account-scoped requests and provider-backed offer filters', () => {
    const requests = read(
      'lib/features/service_requests/my_service_requests_screen.dart',
    );

    expect(requests).toContain('request.customerId == customerId');
    expect(requests).toContain('summaryForRequest(request.id).received > 0');
    expect(requests).toContain('context.watch<ServiceTransactionProvider>()');
    expect(requests).toContain('.forRequest(');
    expect(requests).toContain("Key('hdc-request-filter-${view.name}')");
    expect(requests).toContain("Key('hdc-customer-request-results')");
    expect(requests).toContain('b.updatedAt.compareTo(a.updatedAt)');
  });

  it('keeps all offers and accepted-service workspace actions reachable', () => {
    const details = read(
      'lib/features/service_requests/service_request_details_screen.dart',
    );

    expect(details).toContain('CustomerProposalInboxScreen');
    expect(details).toContain('ServiceTransactionWorkspaceScreen');
    expect(details).toContain("Key('hdc-request-review-offers')");
    expect(details).toContain("Key('hdc-request-open-workspace')");
    expect(details).toContain("Key('hdc-request-details-actions')");
    expect(details).toContain('constraints.maxWidth >= 1020');
    expect(details).toContain('RequestProposalActivityCard');
  });

  it('uses approved public directory data without synthetic reputation claims', () => {
    const search = read('lib/features/search/search_screen.dart');

    for (const marker of [
      'TechnicianDiscoveryProvider',
      'refreshDirectory()',
      'searchTechnicians(',
      "Key('hdc-technician-query')",
      "Key('hdc-technician-area')",
      "Key('hdc-technician-results')",
      'Public profiles only',
      'Technician-published details',
      'areaMatchRank(',
      'hasPublicContact',
    ]) {
      expect(search).toContain(marker);
    }

    expect(search).not.toContain('Icons.star');
    expect(search).not.toContain('distanceKm');
    expect(search).not.toContain('technician.rating');
    expect(search).not.toContain('sampleTechnicians');
  });

  it('documents the unchanged data and authority boundary', () => {
    const release = read('README_BUILD_0_6_4_BUILD24A.txt');

    expect(release).toContain('No database migration, API route');
    expect(release).toContain('does not manufacture ratings');
    expect(release).toContain('participant and staff authorization rules');
  });
});
