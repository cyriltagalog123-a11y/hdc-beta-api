export type PhoneVerificationRequest = Readonly<{
  idempotencyKey: string;
  userId: string;
  phoneE164: string;
  purpose: 'account_verification' | 'sensitive_action' | 'recovery_review';
}>;

export type PhoneVerificationChallenge = Readonly<{
  providerKey: string;
  externalReference: string;
  expiresAt: Date;
  maskedDestination: string;
}>;

export type PhoneVerificationResult = Readonly<{
  verified: boolean;
  verifiedAt?: Date;
}>;

export interface PhoneVerificationProvider {
  readonly providerKey: string;
  begin(
    request: PhoneVerificationRequest,
  ): Promise<PhoneVerificationChallenge>;
  verify(
    externalReference: string,
    code: string,
  ): Promise<PhoneVerificationResult>;
  healthCheck(): Promise<boolean>;
}
