import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 24A Customer request and Technician discovery redesign', () => {
  it('keeps the public release identity synchronized to the current interface build', () => {
    const login = read('lib/features/authentication/login_screen.dart');

    expect(login).toContain('CONTROLLED BETA • BUILD 25');
    expect(login).not.toContain('CONTROLLED BETA • BUILD 24');
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
    const screen = read(
      'lib/features/service_requests/create_service_request_screen.dart',
    );
    const provider = read('lib/providers/service_request_provider.dart');

    expect(screen).toContain('HDCFlowHero');
    expect(screen).toContain('HDCFlowProgress');
    expect(screen).toContain('HDCSectionCard');
    expect(screen).toContain('HDCResponsiveActions');
    expect(screen).toContain('validateServiceRequestDraft');
    expect(provider).toContain('await _repository.createRequest(request)');
    expect(provider).not.toContain("defaultValue: 'queued'");
  });

  it('uses account-scoped requests and provider-backed offer filters', () => {
    const customer = read(
      'lib/features/dashboard/customer_service_workspace_screen.dart',
    );
    const technician = read(
      'lib/features/dashboard/technician_opportunities_screen.dart',
    );

    expect(customer).toContain('loadRequests(customerId: auth.accountId)');
    expect(customer).toContain('loadProposals(requestId: request.id)');
    expect(technician).toContain('loadOpportunities(technicianId: auth.accountId)');
    expect(technician).toContain('loadTechnicianProposals(');
  });

  it('keeps all offers and accepted-service workspace actions reachable', () => {
    const customer = read(
      'lib/features/dashboard/customer_service_workspace_screen.dart',
    );

    expect(customer).toContain('View all offers');
    expect(customer).toContain('Active service');
    expect(customer).toContain('ServiceWorkspaceScreen');
  });

  it('uses approved public directory data without synthetic reputation claims', () => {
    const discovery = read(
      'lib/features/discovery/technician_discovery_screen.dart',
    );

    expect(discovery).toContain('directoryProfile');
    expect(discovery).toContain('No verified public profile yet');
    expect(discovery).not.toContain('4.9');
    expect(discovery).not.toContain('98%');
  });

  it('documents the unchanged data and authority boundary', () => {
    const review = read('docs/build24-final-review.md');

    expect(review).toContain('backend-authoritative');
    expect(review).toContain('fail closed');
  });
});
