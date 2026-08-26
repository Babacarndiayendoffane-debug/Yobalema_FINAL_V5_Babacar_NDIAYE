import { PrismaClient } from '@prisma/client';

const base = new PrismaClient();

/**
 * Last-line business invariants. The UI and API must still validate these rules,
 * but persistence must never allow a contradictory vehicle or commission split.
 */
export const prisma = base.$extends({
  query: {
    driver: {
      async create({ args, query }: any) {
        args.data.vehicleType = 'MOTO';
        return query(args);
      },
      async update({ args, query }: any) {
        args.data.vehicleType = 'MOTO';
        return query(args);
      },
      async upsert({ args, query }: any) {
        args.create.vehicleType = 'MOTO';
        args.update.vehicleType = 'MOTO';
        return query(args);
      },
    },
    ride: {
      async create({ args, query }: any) {
        const data = args.data;
        if (typeof data.priceFcfa === 'number') {
          const platformFee = Math.round(data.priceFcfa * 0.10);
          data.platformFee = platformFee;
          data.driverEarnings = data.priceFcfa - platformFee;
        }
        return query(args);
      },
      async update({ args, query }: any) {
        const data = args.data;
        const price = typeof data.priceFcfa === 'number' ? data.priceFcfa : undefined;
        if (price !== undefined) {
          const platformFee = Math.round(price * 0.10);
          data.platformFee = platformFee;
          data.driverEarnings = price - platformFee;
        }
        return query(args);
      },
    },
  },
});

export async function disconnectPrisma() {
  await base.$disconnect();
}
