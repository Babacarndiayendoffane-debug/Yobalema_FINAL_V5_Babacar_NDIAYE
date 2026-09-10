import { prisma } from './prisma';
import { NotificationType, WalletEntryType } from '@prisma/client';

export async function notify(userId: string, type: NotificationType, title: string, body: string, data?: unknown) {
  const n = await prisma.notification.create({
    data: {
      userId,
      type,
      title,
      body,
      dataJson: data ? JSON.stringify(data) : undefined,
    },
  });
  return n;
}

export async function creditDriver(driverId: string, amount: number, reference: string, note: string) {
  const existing = await prisma.walletEntry.findFirst({ where: { userId: driverId, reference } });
  if (existing) return existing;
  return prisma.walletEntry.create({
    data: {
      userId: driverId,
      type: WalletEntryType.CREDIT,
      amountFcfa: amount,
      reference,
      note,
    },
  });
}

export interface PaymentIntentResult {
  provider: 'WAVE' | 'ORANGE_MONEY' | 'CASH';
  status: 'PENDING' | 'READY';
  amountFcfa: number;
  reference: string;
  checkoutUrl?: string;
  message: string;
  isSimulated: boolean;
}

export const paymentProviders = {
  wave: {
    async createPayment(amountFcfa: number, reference: string): Promise<PaymentIntentResult> {
      // Production webhook URL and Wave API integration stub
      return {
        provider: 'WAVE',
        status: 'PENDING',
        amountFcfa,
        reference,
        message: 'Paiement Wave initialisé. En attente de confirmation.',
        isSimulated: true,
      };
    },
  },
  orangeMoney: {
    async createPayment(amountFcfa: number, reference: string): Promise<PaymentIntentResult> {
      // Production OM WebPay API integration stub
      return {
        provider: 'ORANGE_MONEY',
        status: 'PENDING',
        amountFcfa,
        reference,
        message: 'Paiement Orange Money initialisé. En attente de validation OTP / USSD.',
        isSimulated: true,
      };
    },
  },
};

