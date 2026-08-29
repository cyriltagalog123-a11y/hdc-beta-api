import { WorkflowHttpError } from './workflow.mjs';

export const PRIVATE_MESSAGE_MAX_LENGTH = 4000;
export const PRIVATE_CONVERSATION_BETA_QUOTA_BYTES = 5 * 1024 * 1024;

const profanityTokens = new Set([
  'fuck',
  'fucking',
  'shit',
  'bullshit',
  'bitch',
  'asshole',
  'motherfucker',
  'puta',
  'putangina',
  'tangina',
  'gago',
  'ulol',
]);

const blockedPatterns = [
  'i will kill you',
  'i am going to kill you',
  'send me your password',
  'give me your password',
  'send your otp',
  'give me your otp',
];

export type PrivateMessageModeration = Readonly<{
  action: 'allow' | 'warn' | 'block';
  reason: string | null;
}>;

export type PrivateMessageWrite = Readonly<{
  clientMessageId: string;
  text: string;
  acknowledgeLanguageWarning: boolean;
}>;

export function assessPrivateMessage(text: string): PrivateMessageModeration {
  const normalized = text.trim().toLowerCase();
  if (!normalized) {
    return Object.freeze({
      action: 'block',
      reason: 'Message cannot be empty.',
    });
  }

  if (blockedPatterns.some((pattern) => normalized.includes(pattern))) {
    return Object.freeze({
      action: 'block',
      reason: 'This message contains content HDC will not send in private chat.',
    });
  }

  const words = normalized
    .replace(/[^a-z0-9]+/g, ' ')
    .split(' ')
    .filter(Boolean);
  if (words.some((word) => profanityTokens.has(word))) {
    return Object.freeze({
      action: 'warn',
      reason: 'This message contains language that may be offensive.',
    });
  }

  return Object.freeze({ action: 'allow', reason: null });
}

export function parsePrivateMessageWrite(
  source: Record<string, unknown>,
): PrivateMessageWrite {
  if (typeof source.text !== 'string') {
    throw new WorkflowHttpError(
      'invalid_private_message',
      400,
      'Enter a message before sending.',
    );
  }
  const text = source.text.trim();
  if (!text || text.length > PRIVATE_MESSAGE_MAX_LENGTH) {
    throw new WorkflowHttpError(
      'invalid_private_message',
      400,
      `Private messages must contain 1 to ${PRIVATE_MESSAGE_MAX_LENGTH} characters.`,
    );
  }
  if (
    typeof source.clientMessageId !== 'string' ||
    !/^[A-Za-z0-9._:-]{3,100}$/.test(source.clientMessageId)
  ) {
    throw new WorkflowHttpError(
      'invalid_private_message',
      400,
      'The client message reference is invalid.',
    );
  }
  if (
    source.acknowledgeLanguageWarning !== undefined &&
    typeof source.acknowledgeLanguageWarning !== 'boolean'
  ) {
    throw new WorkflowHttpError(
      'invalid_private_message',
      400,
      'The language-warning acknowledgement is invalid.',
    );
  }
  return Object.freeze({
    clientMessageId: source.clientMessageId,
    text,
    acknowledgeLanguageWarning:
      source.acknowledgeLanguageWarning === true,
  });
}

export function parseConversationStorageMode(
  source: Record<string, unknown>,
): 'hdcManaged' {
  if (source.mode !== 'hdcManaged') {
    throw new WorkflowHttpError(
      'user_storage_not_connected',
      409,
      'User-owned chat storage is not connected yet.',
    );
  }
  return 'hdcManaged';
}

export function privateMessageStorageBytes(text: string): number {
  return new TextEncoder().encode(text).byteLength + 160;
}

export function privateMessageView(
  row: Record<string, unknown>,
): Record<string, unknown> {
  return {
    id: String(row.id),
    clientMessageId: String(row.client_message_id ?? row.id),
    conversationId: String(row.conversation_id),
    senderId: String(row.sender_id),
    body: String(row.body),
    status: String(row.status),
    languageWarningAcknowledged:
      Boolean(row.language_warning_acknowledged),
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at ?? row.created_at)).toISOString(),
    readAt: row.read_at === null || row.read_at === undefined
      ? null
      : new Date(String(row.read_at)).toISOString(),
  };
}

export function privateConversationView(
  row: Record<string, unknown>,
  messages: Record<string, unknown>[],
): Record<string, unknown> {
  return {
    id: String(row.id),
    transactionId: String(row.transaction_id),
    customerId: String(row.customer_id),
    technicianId: String(row.technician_id),
    storage: {
      mode: String(row.storage_mode),
      quotaBytes: Number(row.quota_bytes),
      externalProviderConnected:
        Boolean(row.external_provider_connected),
      storageChoiceConfirmed:
        Boolean(row.storage_choice_confirmed),
      externalProviderName: row.external_provider_name === null ||
          row.external_provider_name === undefined
        ? null
        : String(row.external_provider_name),
      updatedAt: new Date(String(row.updated_at)).toISOString(),
    },
    messages: messages.map(privateMessageView),
    createdAt: new Date(String(row.created_at)).toISOString(),
    updatedAt: new Date(String(row.updated_at)).toISOString(),
  };
}
