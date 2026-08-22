import { prisma } from './prisma';
import { NotificationType, WalletEntryType } from '@prisma/client';

export async function notify(userId:string, type:NotificationType, title:string, body:string, data?:unknown) {
  const n = await prisma.notification.create({data:{userId,type,title,body,dataJson:data?JSON.stringify(data):undefined}});
  return n;
}

export async function creditDriver(driverId:string, amount:number, reference:string, note:string) {
  const existing = await prisma.walletEntry.findFirst({where:{userId:driverId, reference}});
  if (existing) return existing;
  return prisma.walletEntry.create({data:{userId:driverId,type:WalletEntryType.CREDIT,amountFcfa:amount,reference,note}});
}

export const paymentProviders = {
  wave: {
    async createPayment(amountFcfa:number, reference:string) {
      return {provider:'WAVE', status:'PENDING', amountFcfa, reference, integrationRequired:true};
    }
  },
  orangeMoney: {
    async createPayment(amountFcfa:number, reference:string) {
      return {provider:'ORANGE_MONEY', status:'PENDING', amountFcfa, reference, integrationRequired:true};
    }
  }
};
