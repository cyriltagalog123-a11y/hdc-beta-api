import { createHash, createHmac } from 'node:crypto';

export const RECOVERY_QUESTION_VERSION = 1;

export const RECOVERY_QUESTIONS = [
  {
    code: 'first_meal',
    prompt: 'What was the first meal you learned to prepare by yourself?',
  },
  {
    code: 'childhood_nickname',
    prompt: 'What nickname did someone close to you use for you when you were young?',
  },
  {
    code: 'private_phrase',
    prompt: 'Create a private recovery phrase that you do not use anywhere else.',
  },
] as const;

export type RecoveryQuestionCode = typeof RECOVERY_QUESTIONS[number]['code'];

export type RecoveryAnswerInput = {
  questionCode: RecoveryQuestionCode;
  answer: string;
};

const questionCodes = new Set<string>(
  RECOVERY_QUESTIONS.map((question) => question.code),
);

export function normalizeRecoveryAnswer(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const normalized = value
    .normalize('NFKC')
    .trim()
    .toLocaleLowerCase('en-US')
    .replace(/\s+/g, ' ');
  if (normalized.length < 4 || normalized.length > 160) return null;
  if (!/[\p{L}\p{N}]/u.test(normalized)) return null;
  return normalized;
}

export function parseRecoveryAnswers(value: unknown): RecoveryAnswerInput[] | null {
  if (!Array.isArray(value) || value.length !== RECOVERY_QUESTIONS.length) {
    return null;
  }

  const parsed = new Map<RecoveryQuestionCode, string>();
  for (const item of value) {
    if (!item || typeof item !== 'object') return null;
    const record = item as Record<string, unknown>;
    const questionCode = typeof record.questionCode === 'string'
      ? record.questionCode.trim()
      : '';
    if (!questionCodes.has(questionCode)) return null;
    const answer = normalizeRecoveryAnswer(record.answer);
    if (!answer || parsed.has(questionCode as RecoveryQuestionCode)) return null;
    parsed.set(questionCode as RecoveryQuestionCode, answer);
  }

  const answers = RECOVERY_QUESTIONS.map((question) => ({
    questionCode: question.code,
    answer: parsed.get(question.code) ?? '',
  }));
  if (answers.some((item) => !item.answer)) return null;
  if (new Set(answers.map((item) => item.answer)).size !== answers.length) {
    return null;
  }
  return answers;
}

/**
 * Adds a server-only pepper before the deliberately slow password hash. The
 * returned digest is safe to pass to bcrypt and prevents a database-only leak
 * from being sufficient for offline answer guessing.
 */
export function recoveryAnswerDigest(
  answer: string,
  secret: string | Uint8Array,
): string {
  return createHmac('sha256', secret)
    .update(`hdc-recovery-v${RECOVERY_QUESTION_VERSION}\0${answer}`)
    .digest('base64url');
}

export function passwordResetTokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function publicRecoveryQuestions(): Array<{
  questionCode: RecoveryQuestionCode;
  prompt: string;
}> {
  return RECOVERY_QUESTIONS.map((question) => ({
    questionCode: question.code,
    prompt: question.prompt,
  }));
}
