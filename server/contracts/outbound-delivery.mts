export type OutboundDeliveryChannel = 'email' | 'sms';

export type OutboundDeliveryMessage = Readonly<{
  idempotencyKey: string;
  recipient: string;
  subject?: string;
  bodyText: string;
  metadata: Readonly<Record<string, unknown>>;
}>;

export type OutboundDeliveryReceipt = Readonly<{
  providerKey: string;
  externalReference: string;
  acceptedAt: Date;
}>;

export interface OutboundDeliveryProvider {
  readonly providerKey: string;
  readonly channel: OutboundDeliveryChannel;
  send(message: OutboundDeliveryMessage): Promise<OutboundDeliveryReceipt>;
  healthCheck(): Promise<boolean>;
}
