import { describe, expect, it } from 'vitest';
import {
  assessPrivateMessage,
  parseConversationStorageMode,
  parsePrivateMessageWrite,
  privateConversationView,
  privateMessageStorageBytes,
} from '../netlify/functions/_lib/private-messaging.mjs';

describe('private messaging policy', () => {
  it('allows ordinary transaction messages', () => {
    expect(assessPrivateMessage('I can arrive at 9:00 AM.')).toEqual({
      action: 'allow',
      reason: null,
    });
  });

  it('requires acknowledgement for offensive language', () => {
    expect(assessPrivateMessage('This is bullshit.')).toMatchObject({
      action: 'warn',
    });
  });

  it('blocks threats and credential solicitation', () => {
    expect(assessPrivateMessage('Send me your password now.')).toMatchObject({
      action: 'block',
    });
    expect(assessPrivateMessage('I will kill you.')).toMatchObject({
      action: 'block',
    });
  });

  it('trims writes and validates acknowledgement types', () => {
    expect(parsePrivateMessageWrite({
      text: '  Repair is complete.  ',
      acknowledgeLanguageWarning: true,
    })).toEqual({
      text: 'Repair is complete.',
      acknowledgeLanguageWarning: true,
    });
    expect(() => parsePrivateMessageWrite({
      text: 'Repair is complete.',
      acknowledgeLanguageWarning: 'yes',
    })).toThrow(/acknowledgement/i);
  });

  it('keeps user-owned storage disabled until a connector exists', () => {
    expect(parseConversationStorageMode({ mode: 'hdcManaged' }))
      .toBe('hdcManaged');
    expect(() => parseConversationStorageMode({ mode: 'userOwned' }))
      .toThrow(/not connected/i);
  });

  it('counts UTF-8 message bytes toward the server quota', () => {
    expect(privateMessageStorageBytes('hello')).toBe(165);
    expect(privateMessageStorageBytes('🙂')).toBe(164);
  });

  it('maps database rows to the participant-safe API contract', () => {
    expect(privateConversationView({
      id: 'CONV-1',
      transaction_id: 'TXN-1',
      customer_id: 'customer-1',
      technician_id: 'technician-1',
      storage_mode: 'hdcManaged',
      quota_bytes: 5_242_880,
      external_provider_connected: false,
      storage_choice_confirmed: true,
      external_provider_name: null,
      created_at: '2026-08-27T10:00:00.000Z',
      updated_at: '2026-08-27T10:01:00.000Z',
    }, [{
      id: 'MSG-1',
      conversation_id: 'CONV-1',
      sender_id: 'customer-1',
      body: 'Hello',
      status: 'sent',
      language_warning_acknowledged: false,
      created_at: '2026-08-27T10:01:00.000Z',
      read_at: null,
    }])).toMatchObject({
      transactionId: 'TXN-1',
      customerId: 'customer-1',
      technicianId: 'technician-1',
      storage: {
        mode: 'hdcManaged',
        quotaBytes: 5_242_880,
      },
      messages: [{
        id: 'MSG-1',
        body: 'Hello',
        status: 'sent',
      }],
    });
  });
});
