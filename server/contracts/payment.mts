export type Money = Readonly<{
  currency: string;
  amountMinor: number;
}>;

export type PaymentIntentRequest = Readonly<{
  idempotencyKey: string;
  transactionId: string;
  amount: Money;
  description: string;
  metadata: Readonly<Record<string, string>>;
}>;

export type PaymentIntent = Readonly<{
  providerKey: string;
  externalReference: string;
  status: 'pending' | 'authorized' | 'captured' | 'failed' | 'cancelled';
  clientAction?: Readonly<Record<string, string>>;
}>;

export type VerifiedPaymentEvent = Readonly<{
  eventId: string;
  externalReference: string;
  status: PaymentIntent['status'] | 'refunded' | 'partially_refunded';
  occurredAt: Date;
}>;

export interface PaymentProvider {
  readonly providerKey: string;
  createIntent(request: PaymentIntentRequest): Promise<PaymentIntent>;
  capture(externalReference: string, idempotencyKey: string): Promise<PaymentIntent>;
  refund(
    externalReference: string,
    amount: Money,
    idempotencyKey: string,
  ): Promise<PaymentIntent>;
  verifyWebhook(headers: Headers, body: Uint8Array): Promise<VerifiedPaymentEvent>;
  healthCheck(): Promise<boolean>;
}
