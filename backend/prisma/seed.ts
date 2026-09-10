import { PrismaClient, Role, DriverStatus, VerificationStatus } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function upsertUser(phone: string, name: string, role: Role, password: string) {
  const passwordHash = await bcrypt.hash(password, 12);
  return prisma.user.upsert({ where: { phone }, update: { name, role, passwordHash }, create: { phone, passwordHash, name, role } });
}

async function main() {
  const driver = await upsertUser('+221770000001', 'Chauffeur Démo', Role.DRIVER, 'Yobalema123!');
  await prisma.driver.upsert({
    where: { userId: driver.id },
    update: { status: DriverStatus.ONLINE, lat: 14.151, lng: -16.0726, vehicleType: 'Taxi', vehiclePlate: 'DK-0001-AA', verificationStatus: VerificationStatus.VERIFIED },
    create: { userId: driver.id, status: DriverStatus.ONLINE, lat: 14.151, lng: -16.0726, vehicleType: 'Taxi', vehiclePlate: 'DK-0001-AA', verificationStatus: VerificationStatus.VERIFIED }
  });
  const passenger = await upsertUser('+221770000002', 'Passager Démo', Role.PASSENGER, 'Yobalema123!');
  await prisma.user.update({ where: { id: passenger.id }, data: { phoneVerifiedAt: new Date() } });
  const admin = await upsertUser('+221770000003', 'Admin Yobalema', Role.ADMIN, 'YobalemaAdmin123!');
  await prisma.user.update({ where: { id: admin.id }, data: { phoneVerifiedAt: new Date() } });
  console.log('Comptes démo:');
  console.log('Chauffeur: +221770000001 / Yobalema123!');
  console.log('Passager : +221770000002 / Yobalema123!');
  console.log('Admin    : +221770000003 / YobalemaAdmin123!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
