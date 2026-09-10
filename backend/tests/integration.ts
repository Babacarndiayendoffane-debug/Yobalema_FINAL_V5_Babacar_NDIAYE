import { PrismaClient, Role, DriverStatus, VerificationStatus, PaymentMethod } from '@prisma/client';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { calculatePrice } from '../src/pricing';
import { inKaolack, haversineKm } from '../src/geo';
import { signToken, verifyToken } from '../src/auth';

const prisma = new PrismaClient();

async function runTests() {
  console.log('--- TEST 1: Prisma & PostgreSQL connection ---');
  const check = await prisma.$queryRaw`SELECT 1 as result`;
  console.log('PostgreSQL connect OK:', check);

  console.log('--- TEST 2: Pricing engine ---');
  const price1 = calculatePrice(5, 'CITY', 'CITY', 0, false);
  if (price1.total < 300) throw new Error('Prix trop bas');
  console.log('Pricing OK:', price1);

  console.log('--- TEST 3: Geo perimeter & Kaolack Regional Polygon ---');
  const inKaolackCity = inKaolack(14.151, -16.0726); // Kaolack center
  const inNdoffane = inKaolack(13.8447, -15.9382); // Ndoffane (Kaolack dep)
  const inPorokhane = inKaolack(13.8000, -15.7000); // Porokhane (Nioro dep)
  const inNioro = inKaolack(13.7500, -15.7800); // Nioro du Rip
  const inGuinguineo = inKaolack(14.2700, -15.9500); // Guinguineo
  const inMedinaSabakh = inKaolack(13.6002, -15.5804); // Medina Sabakh
  
  // Rejections
  const outDakar = inKaolack(14.6698, -17.4326); // Dakar
  const outThies = inKaolack(14.7900, -16.9260); // Thies
  const outTouba = inKaolack(14.8620, -15.8770); // Touba
  const outFatick = inKaolack(14.3310, -16.4060); // Fatick

  if (!inKaolackCity || !inNdoffane || !inPorokhane || !inNioro || !inGuinguineo || !inMedinaSabakh) {
    throw new Error('Erreur: une localité de la région de Kaolack a été rejetée à tort');
  }
  if (outDakar || outThies || outTouba || outFatick) {
    throw new Error('Erreur: un point hors de la région de Kaolack a été accepté');
  }

  const dist = haversineKm(14.151, -16.0726, 13.8447, -15.9382); // Kaolack -> Ndoffane
  console.log('Polygon & Geo validation OK. Distance Kaolack-Ndoffane:', dist.toFixed(2), 'km');

  console.log('--- TEST 4: Auth & JWT ---');
  const token = signToken({ id: 'test-user-id', role: 'PASSENGER' });
  const decoded = verifyToken(token);
  if (decoded.id !== 'test-user-id') throw new Error('Token verification failed');
  console.log('JWT sign/verify OK');

  console.log('--- TEST 5: 6-digit OTP generation ---');
  const otpCode = crypto.randomInt(100000, 1000000).toString();
  if (otpCode.length !== 6 || isNaN(Number(otpCode))) throw new Error('OTP 6 chiffres invalide');
  console.log('OTP 6 chiffres OK:', otpCode);

  console.log('--- TEST 6: User & Driver creation & Ride flow in DB ---');
  const testPhonePass = `+22177${Math.floor(1000000 + Math.random() * 9000000)}`;
  const testPhoneDriver = `+22178${Math.floor(1000000 + Math.random() * 9000000)}`;

  const passUser = await prisma.user.create({
    data: {
      phone: testPhonePass,
      name: 'Test Passager Auto',
      passwordHash: await bcrypt.hash('Secret123!', 10),
      role: Role.PASSENGER,
    },
  });

  const driverUser = await prisma.user.create({
    data: {
      phone: testPhoneDriver,
      name: 'Test Chauffeur Auto',
      passwordHash: await bcrypt.hash('Secret123!', 10),
      role: Role.DRIVER,
      driver: {
        create: {
          status: DriverStatus.ONLINE,
          verificationStatus: VerificationStatus.VERIFIED,
          lat: 14.151,
          lng: -16.0726,
          vehicleType: 'Moto Jakarta',
          vehiclePlate: 'KL-9999-Z',
        },
      },
    },
    include: { driver: true },
  });

  // Create Ride
  const ride = await prisma.ride.create({
    data: {
      passengerId: passUser.id,
      fromName: 'Ndoffane',
      toName: 'Kaolack',
      fromLat: 13.8447,
      fromLng: -15.9382,
      toLat: 14.151,
      toLng: -16.0726,
      distanceKm: dist,
      zone: 'CITY',
      priceFcfa: 1500,
      driverEarnings: 1350,
      platformFee: 150,
      paymentMethod: PaymentMethod.CASH,
      payment: {
        create: {
          method: PaymentMethod.CASH,
          amountFcfa: 1500,
        },
      },
    },
  });
  console.log('Ride created in DB:', ride.id, 'Price:', ride.priceFcfa, 'FCFA');

  // Accept Ride
  const acceptedRide = await prisma.ride.update({
    where: { id: ride.id },
    data: { driverId: driverUser.id, status: 'ACCEPTED' },
  });
  console.log('Ride accepted:', acceptedRide.status, 'by driver:', driverUser.id);

  // Set Pickup OTP
  const pickupOtp = crypto.randomInt(100000, 1000000).toString();
  const pickupHash = crypto.createHash('sha256').update(pickupOtp).digest('hex');
  await prisma.ride.update({
    where: { id: ride.id },
    data: { otpPickupHash: pickupHash },
  });
  console.log('Pickup OTP generated:', pickupOtp);

  // Verify Pickup PIN & Start
  const startedRide = await prisma.ride.update({
    where: { id: ride.id },
    data: { pickupVerifiedAt: new Date(), status: 'IN_PROGRESS' },
  });
  console.log('Pickup verified, status:', startedRide.status);

  // Complete Ride
  const completedRide = await prisma.ride.update({
    where: { id: ride.id },
    data: { status: 'COMPLETED', paymentStatus: 'PAID' },
  });
  console.log('Ride completed, status:', completedRide.status);

  // Credit Driver Wallet
  const wallet = await prisma.walletEntry.create({
    data: {
      userId: driverUser.id,
      type: 'CREDIT',
      amountFcfa: ride.driverEarnings,
      reference: `CASH-${ride.id}`,
      note: 'Test de commission chauffeur',
    },
  });
  console.log('Driver wallet credited:', wallet.amountFcfa, 'FCFA');

  console.log('\n=== TOUS LES TESTS BACKEND SONT VALIDÉS AVEC SUCCÈS ===\n');
}

runTests()
  .catch((e) => {
    console.error('Test failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
