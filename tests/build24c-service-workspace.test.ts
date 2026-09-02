import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const read = (path: string) =>
  readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

describe('Build 24C responsive Service Workspace', () => {
  it('keeps every workspace account-scoped and sorted by current activity', () => {
    const list = read(
      'lib/features/transactions/my_transactions_screen.dart',
    );

    expect(list).toContain('provider.forCustomer(widget.actorId)');
    expect(list).toContain('provider.forTechnician(widget.actorId)');
    expect(list).toContain('provider.forParticipant(widget.actorId)');
    expect(list).toContain('transaction.roleFor(actorId)');
    expect(list).toContain('participantRole != requestedRole');
    expect(list).toContain('b.updatedAt.compareTo(a.updatedAt)');
    expect(list).toContain("Key('hdc-transaction-filter-${view.name}')");
    expect(list).toContain("Key('hdc-transaction-results')");
    expect(list).toContain('_requiresParticipantAction(transaction, role)');
  });

  it('uses responsive HDC surfaces without horizontal workspace scrolling', () => {
    const list = read(
      'lib/features/transactions/my_transactions_screen.dart',
    );
    const workspace = read(
      'lib/features/transactions/service_transaction_workspace_screen.dart',
    );

    expect(list).toContain('HDCFlowHero(');
    expect(list).toContain('constraints.maxWidth >= 960');
    expect(list).toContain("Key('hdc-transaction-card-${transaction.id}')");
    expect(workspace).toContain('HDCSignalBackdrop(');
    expect(workspace).toContain('HDCFlowHero(');
    expect(workspace).toContain('HDCFlowProgress(');
    expect(workspace).toContain('constraints.maxWidth >= 1020');
    expect(workspace).toContain('constraints.maxWidth < 600');
    expect(workspace).not.toContain('scrollDirection: Axis.horizontal');
  });

  it('fails closed before showing a mismatched participant workspace', () => {
    const workspace = read(
      'lib/features/transactions/service_transaction_workspace_screen.dart',
    );

    expect(workspace).toContain(
      'final participantRole = transaction.roleFor(actorId);',
    );
    expect(workspace).toContain(
      'participantRole == null || participantRole != role',
    );
    expect(workspace).toContain("Key('hdc-workspace-access-unavailable')");
    expect(workspace).toContain('No transaction details were shown.');
    expect(workspace).toContain('role: participantRole');
  });

  it('keeps server-backed transitions and existing participant tools intact', () => {
    const workspace = read(
      'lib/features/transactions/service_transaction_workspace_screen.dart',
    );

    expect(workspace).toContain('await provider.transition(');
    expect(workspace).toContain('PrivateTransactionChatScreen(');
    expect(workspace).toContain('TransactionToolsScreen(');
    for (const label of [
      'Private Transaction Chat',
      'Schedule, Price & Issues',
      'Payment & Receipt',
      'Documents',
      'Dispute',
    ]) {
      expect(workspace).toContain(label);
    }
  });
});
