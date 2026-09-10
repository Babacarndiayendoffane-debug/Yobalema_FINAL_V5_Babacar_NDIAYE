import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import crypto from 'crypto';
import { Server } from 'socket.io';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { config } from './config';
import { prisma } from './prisma';
import { hashPassword, verifyPassword, signToken, requireAuth, requireRole, verifyToken } from './auth';
import { inKaolack, isPointInKaolackRegion, haversineKm, estimateRoadDistanceKm } from './geo';
import { calculatePrice } from './pricing';
import { Role, DriverStatus, RideStatus, PaymentMethod, PaymentStatus, VerificationStatus, NotificationType, TicketStatus, WalletEntryType } from '@prisma/client';
import { notify, creditDriver, paymentProviders } from './services';

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
    credentials: true,
  },
});

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(cors({ origin: '*', credentials: true }));
app.use(express.json({ limit: '1mb' }));

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 120, standardHeaders: true, legacyHeaders: false });
app.use('/api/auth', authLimiter);
app.use('/admin', express.static('public'));

const sha = (v: string) => crypto.createHash('sha256').update(v).digest('hex');
const generate6DigitOtp = (): string => crypto.randomInt(100000, 1000000).toString();

// Health check endpoints
const healthHandler = async (_req: express.Request, res: express.Response) => {
  try {
    const db = await prisma.$queryRaw`SELECT 1`;
    res.json({
      ok: true,
      service: 'yobalema-backend-v4',
      database: !!db,
      time: new Date().toISOString(),
    });
  } catch (err: any) {
    res.status(500).json({ ok: false, database: false, error: err.message });
  }
};
app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

// AUTH SCHEMAS & ENDPOINTS
const authSchema = z.object({
  phone: z.string().min(8),
  password: z.string().min(4),
  name: z.string().min(2).optional(),
  role: z.enum(['PASSENGER', 'DRIVER']).default('PASSENGER'),
});

app.post('/api/auth/register', async (req, res, next) => {
  try {
    const b = authSchema.parse(req.body);
    const cleanPhone = b.phone.trim();
    const exists = await prisma.user.findUnique({ where: { phone: cleanPhone } });
    if (exists) return res.status(409).json({ error: 'Ce numÃ©ro de tÃ©lÃ©phone est dÃ©jÃ  enregistrÃ©' });

    const user = await prisma.user.create({
      data: {
        phone: cleanPhone,
        name: b.name?.trim() || (b.role === 'DRIVER' ? 'Chauffeur Yobalema' : 'Passager Yobalema'),
        passwordHash: await hashPassword(b.password),
        role: b.role as Role,
      },
    });

    if (user.role === Role.DRIVER) {
      await prisma.driver.create({
        data: {
          userId: user.id,
          status: DriverStatus.OFFLINE,
          verificationStatus: VerificationStatus.VERIFIED, // Auto-verify for smooth dev & real test usage
          vehicleType: 'MOTO',
          vehiclePlate: 'KL-0000-M',
        },
      });
    }

    const code = generate6DigitOtp();
    await prisma.otpCode.create({
      data: {
        userId: user.id,
        codeHash: sha(code),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });

    const token = signToken({ id: user.id, role: user.role });
    res.status(201).json({
      token,
      user: { id: user.id, phone: user.phone, name: user.name, role: user.role },
      devOtp: code,
    });
  } catch (e) {
    next(e);
  }
});

app.post('/api/auth/login', async (req, res, next) => {
  try {
    const b = z.object({ phone: z.string().min(4), password: z.string() }).parse(req.body);
    const cleanPhone = b.phone.trim();
    const user = await prisma.user.findUnique({ where: { phone: cleanPhone } });
    if (!user || !(await verifyPassword(b.password, user.passwordHash))) {
      return res.status(401).json({ error: 'NumÃ©ro ou mot de passe incorrect' });
    }
    const token = signToken({ id: user.id, role: user.role });
    res.json({
      token,
      user: {
        id: user.id,
        phone: user.phone,
        name: user.name,
        role: user.role,
        phoneVerified: !!user.phoneVerifiedAt,
      },
    });
  } catch (e) {
    next(e);
  }
});

app.post('/api/auth/request-otp', requireAuth, async (req, res, next) => {
  try {
    const code = generate6DigitOtp();
    await prisma.otpCode.create({
      data: {
        userId: req.user!.id,
        codeHash: sha(code),
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });
    res.json({ sent: true, devOtp: code, otp: code });
  } catch (e) {
    next(e);
  }
});

app.post('/api/auth/verify-otp', requireAuth, async (req, res, next) => {
  try {
    const b = z.object({ code: z.string().length(6) }).parse(req.body);
    const row = await prisma.otpCode.findFirst({
      where: { userId: req.user!.id, consumedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!row || row.codeHash !== sha(b.code)) {
      return res.status(400).json({ error: 'Code OTP invalide ou expirÃ©' });
    }
    await prisma.$transaction([
      prisma.otpCode.update({ where: { id: row.id }, data: { consumedAt: new Date() } }),
      prisma.user.update({ where: { id: req.user!.id }, data: { phoneVerifiedAt: new Date() } }),
    ]);
    res.json({ verified: true });
  } catch (e) {
    next(e);
  }
});

app.get('/api/me', requireAuth, async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      include: { driver: true },
    });
    if (!user) return res.status(404).json({ error: 'Utilisateur introuvable' });
    res.json(user);
  } catch (e) {
    next(e);
  }
});

// DRIVER PROFILE & STATUS
const locSchema = z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180), accuracy: z.number().nonnegative().optional(), speed: z.number().nonnegative().optional(), heading: z.number().min(0).max(360).optional() });

app.patch('/api/drivers/me/status', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const b = z.object({ status: z.enum(['OFFLINE', 'ONLINE', 'BUSY']) }).parse(req.body);
    let driver = await prisma.driver.findUnique({ where: { userId: req.user!.id } });
    if (!driver) {
      driver = await prisma.driver.create({
        data: {
          userId: req.user!.id,
          status: DriverStatus.OFFLINE,
          verificationStatus: VerificationStatus.VERIFIED,
          vehicleType: 'MOTO',
          vehiclePlate: 'KL-0001-M',
        },
      });
    }
    if (b.status === 'ONLINE' && driver.verificationStatus !== VerificationStatus.VERIFIED) {
      return res.status(403).json({ error: 'Chauffeur non vÃ©rifiÃ©' });
    }
    const updated = await prisma.driver.update({
      where: { userId: req.user!.id },
      data: { status: b.status as DriverStatus },
    });
    res.json(updated);
  } catch (e) {
    next(e);
  }
});

app.patch('/api/drivers/me/location', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const b = locSchema.parse(req.body);
    if (!inKaolack(b.lat, b.lng)) {
      return res.status(400).json({ error: 'Position en dehors de la rÃ©gion de Kaolack' });
    }
    const d = await prisma.driver.update({
      where: { userId: req.user!.id },
      data: b,
    });
    io.to(`ride-driver:${req.user!.id}`).emit('driver:location', { driverId: d.id, lat: b.lat, lng: b.lng });
    io.emit('driver:location:public', { driverId: d.id, lat: b.lat, lng: b.lng });
    res.json(d);
  } catch (e) {
    next(e);
  }
});

app.patch('/api/drivers/me/vehicle', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const b = z.object({ vehicleType: z.string().min(2), vehiclePlate: z.string().min(2) }).parse(req.body);
    const updated = await prisma.driver.update({
      where: { userId: req.user!.id },
      data: b,
    });
    res.json(updated);
  } catch (e) {
    next(e);
  }
});

app.get('/api/drivers/nearby', requireAuth, async (req, res, next) => {
  try {
    const q = req.query;
    const latRaw = Array.isArray(q.lat) ? q.lat[0] : q.lat;
    const lngRaw = Array.isArray(q.lng) ? q.lng[0] : q.lng;
    const radiusRaw = Array.isArray(q.radiusKm) ? q.radiusKm[0] : q.radiusKm;
    const b = locSchema.extend({ radiusKm: z.number().min(0.1).max(50).default(10) }).parse({
      lat: Number(latRaw),
      lng: Number(lngRaw),
      radiusKm: Number(radiusRaw ?? 10),
    });
    const ds = await prisma.driver.findMany({
      where: { status: DriverStatus.ONLINE, verificationStatus: VerificationStatus.VERIFIED, lat: { not: null }, lng: { not: null } },
      include: { user: { select: { name: true, phone: true } } },
    });
    res.json(
      ds
        .map((d) => ({ ...d, distanceKm: haversineKm(b.lat, b.lng, d.lat!, d.lng!) }))
        .filter((d) => d.distanceKm <= b.radiusKm)
        .sort((a, b) => a.distanceKm - b.distanceKm)
        .slice(0, 10)
    );
  } catch (e) {
    next(e);
  }
});

// PRICING & RIDES (100% MOTO in Kaolack Region)
const quoteSchema = z.object({
  fromName: z.string(),
  toName: z.string(),
  fromLat: z.number(),
  fromLng: z.number(),
  toLat: z.number(),
  toLng: z.number(),
  fromZone: z.enum(['CITY', 'PERIURBAN', 'VILLAGE']),
  toZone: z.enum(['CITY', 'PERIURBAN', 'VILLAGE']),
  trafficLevel: z.number().int().min(0).max(3).default(0),
  night: z.boolean().default(false),
  distanceKm: z.number().positive().optional(),
});

async function makeQuote(b: any) {
  if (!isPointInKaolackRegion(b.fromLat, b.fromLng) || !isPointInKaolackRegion(b.toLat, b.toLng)) {
    throw new Error('DÃ©part et destination doivent Ãªtre situÃ©s dans la rÃ©gion administrative de Kaolack');
  }

  const straightKm = haversineKm(b.fromLat, b.fromLng, b.toLat, b.toLng);
  // Use client road distance if valid and reasonable (between 0.7x and 3.5x straight line),
  // otherwise use calibrated road estimation (1.25x straight line).
  let km = estimateRoadDistanceKm(b.fromLat, b.fromLng, b.toLat, b.toLng);
  if (
    typeof b.distanceKm === 'number' &&
    b.distanceKm >= Math.max(0.5, straightKm * 0.7) &&
    b.distanceKm <= Math.max(2.0, straightKm * 3.5)
  ) {
    km = Number(b.distanceKm.toFixed(2));
  }

  return { km, price: calculatePrice(km, b.fromZone, b.toZone, b.trafficLevel, b.night) };
}

app.post('/api/rides/quote', requireAuth, async (req, res, next) => {
  try {
    const b = quoteSchema.parse(req.body);
    const q = await makeQuote(b);
    res.json({ distanceKm: Number(q.km.toFixed(2)), ...q.price });
  } catch (e) {
    next(e);
  }
});

const rideSchema = quoteSchema.extend({
  shareTrip: z.boolean().default(false),
  paymentMethod: z.enum(['CASH', 'WAVE', 'ORANGE_MONEY']).default('CASH'),
});

app.post('/api/rides', requireAuth, requireRole('PASSENGER'), async (req, res, next) => {
  try {
    const b = rideSchema.parse(req.body);
    const q = await makeQuote(b);
    const ride = await prisma.ride.create({
      data: {
        passengerId: req.user!.id,
        fromName: b.fromName,
        toName: b.toName,
        fromLat: b.fromLat,
        fromLng: b.fromLng,
        toLat: b.toLat,
        toLng: b.toLng,
        distanceKm: q.km,
        zone: q.price.zone,
        trafficLevel: b.trafficLevel,
        night: b.night,
        priceFcfa: q.price.total,
        driverEarnings: q.price.driver,
        platformFee: q.price.platform,
        shareTrip: b.shareTrip,
        paymentMethod: b.paymentMethod as PaymentMethod,
        paymentStatus: PaymentStatus.PENDING,
        payment: {
          create: {
            method: b.paymentMethod as PaymentMethod,
            amountFcfa: q.price.total,
          },
        },
      },
      include: { payment: true },
    });

    // Notify online drivers in the region
    const candidates = await prisma.driver.findMany({
      where: {
        status: DriverStatus.ONLINE,
        verificationStatus: VerificationStatus.VERIFIED,
        lat: { not: null },
        lng: { not: null },
      },
    });

    const ranked = candidates
      .map((d) => ({ ...d, distanceKm: haversineKm(b.fromLat, b.fromLng, d.lat!, d.lng!) }))
      .filter((d) => d.distanceKm <= 35) // Kaolack regional perimeter
      .sort((a, b) => a.distanceKm - b.distanceKm);

    // Broadcast ride offer to drivers room and candidates
    io.to('drivers').emit('ride:new', {
      rideId: ride.id,
      from: b.fromName,
      to: b.toName,
      lat: b.fromLat,
      lng: b.fromLng,
      priceFcfa: ride.priceFcfa,
      paymentMethod: ride.paymentMethod,
    });

    if (ranked.length > 0) {
      for (const d of ranked.slice(0, 5)) {
        io.to(`driver:${d.userId}`).emit('ride:offer', {
          rideId: ride.id,
          from: b.fromName,
          to: b.toName,
          lat: b.fromLat,
          lng: b.fromLng,
          priceFcfa: ride.priceFcfa,
          distanceKm: Number(d.distanceKm.toFixed(2)),
          paymentMethod: ride.paymentMethod,
        });
        await notify(d.userId, NotificationType.RIDE, 'Nouvelle course disponible', `Course de ${b.fromName} vers ${b.toName} (${ride.priceFcfa} FCFA)`, { rideId: ride.id });
      }
    } else {
      io.to(`passenger:${req.user!.id}`).emit('ride:waiting', { rideId: ride.id });
      await notify(req.user!.id, NotificationType.RIDE, 'Recherche en cours', 'Nous recherchons un chauffeur disponible dans votre zone.', { rideId: ride.id });
    }

    res.status(201).json({
      ride,
      quote: q.price,
      matching: {
        status: ranked.length ? 'DRIVER_NOTIFIED' : 'SEARCHING',
        candidates: ranked.length,
      },
    });
  } catch (e) {
    next(e);
  }
});

// Drivers: List pending requested rides
app.get('/api/rides/pending', requireAuth, requireRole('DRIVER'), async (_req, res, next) => {
  try {
    const rides = await prisma.ride.findMany({
      where: { status: RideStatus.REQUESTED },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        passenger: { select: { id: true, name: true, phone: true } },
      },
    });
    res.json(rides);
  } catch (e) {
    next(e);
  }
});

app.get('/api/rides', requireAuth, async (req, res, next) => {
  try {
    res.json(
      await prisma.ride.findMany({
        where: req.user!.role === 'DRIVER' ? { driverId: req.user!.id } : { passengerId: req.user!.id },
        orderBy: { createdAt: 'desc' },
        take: 50,
        include: { payment: true, ratings: true },
      })
    );
  } catch (e) {
    next(e);
  }
});

app.get('/api/rides/:id', requireAuth, async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({
      where: { id: id as string },
      include: {
        payment: true,
        ratings: true,
        passenger: { select: { id: true, name: true, phone: true } },
        driver: { select: { id: true, name: true, phone: true, driver: true } },
      },
    });
    if (!ride) return res.status(404).json({ error: 'Course introuvable' });
    if (ride.passengerId !== req.user!.id && ride.driverId !== req.user!.id && req.user!.role !== 'ADMIN') {
      return res.status(403).json({ error: 'AccÃ¨s interdit' });
    }
    res.json(ride);
  } catch (e) {
    next(e);
  }
});

app.post('/api/rides/:id/accept', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string } });
    const d = await prisma.driver.findUnique({ where: { userId: req.user!.id } });
    if (!ride || ride.status !== RideStatus.REQUESTED) {
      return res.status(409).json({ error: 'Cette course nâ€™est plus disponible' });
    }
    if (!d || d.status !== DriverStatus.ONLINE) {
      return res.status(409).json({ error: 'Vous devez Ãªtre en ligne pour accepter une course' });
    }

    const updated = await prisma.$transaction(async (tx) => {
      const latest = await tx.ride.findUnique({ where: { id: ride.id } });
      if (!latest || latest.status !== RideStatus.REQUESTED) {
        throw new Error('Course dÃ©jÃ  prise par un autre chauffeur');
      }
      const u = await tx.ride.update({
        where: { id: ride.id },
        data: { driverId: req.user!.id, status: RideStatus.ACCEPTED },
      });
      await tx.driver.update({ where: { id: d.id }, data: { status: DriverStatus.BUSY } });
      return u;
    });

    io.to(`ride:${ride.id}`).emit('ride:accepted', { rideId: ride.id, driverId: req.user!.id });
    io.to(`passenger:${ride.passengerId}`).emit('ride:accepted', { rideId: ride.id, driverId: req.user!.id });
    await notify(ride.passengerId, NotificationType.RIDE, 'Chauffeur trouvÃ© !', 'Votre chauffeur a acceptÃ© la course et se met en route.', { rideId: ride.id, driverId: req.user!.id });

    res.json(updated);
  } catch (e) {
    next(e);
  }
});

// PASSENGER GENERATES 6-DIGIT OTP FOR PICKUP
app.post('/api/rides/:id/pickup-otp', requireAuth, async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string } });
    if (!ride || ride.passengerId !== req.user!.id) {
      return res.status(403).json({ error: 'AccÃ¨s interdit' });
    }
    const code = generate6DigitOtp();
    await prisma.ride.update({
      where: { id: ride.id },
      data: { otpPickupHash: sha(code) },
    });
    res.json({ sent: true, devOtp: code, otp: code });
  } catch (e) {
    next(e);
  }
});

// DRIVER VERIFIES 6-DIGIT PICKUP OTP TO START TRIP
app.post('/api/rides/:id/verify-pickup', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const b = z.object({ code: z.string().length(6) }).parse(req.body);
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string } });
    if (!ride || ride.driverId !== req.user!.id || !ride.otpPickupHash || ride.otpPickupHash !== sha(b.code)) {
      return res.status(400).json({ error: 'Code PIN de dÃ©part incorrect' });
    }
    const u = await prisma.ride.update({
      where: { id: ride.id },
      data: { pickupVerifiedAt: new Date(), status: RideStatus.IN_PROGRESS },
    });
    io.to(`ride:${ride.id}`).emit('ride:status', { rideId: ride.id, status: u.status });
    io.to(`passenger:${ride.passengerId}`).emit('ride:status', { rideId: ride.id, status: u.status });
    res.json(u);
  } catch (e) {
    next(e);
  }
});

app.patch('/api/rides/:id/status', requireAuth, async (req, res, next) => {
  try {
    const b = z.object({ status: z.enum(['DRIVER_ARRIVING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']) }).parse(req.body);
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string } });
    if (!ride) return res.status(404).json({ error: 'Course introuvable' });
    if (ride.passengerId !== req.user!.id && ride.driverId !== req.user!.id) {
      return res.status(403).json({ error: 'AccÃ¨s interdit' });
    }

    const u = await prisma.ride.update({
      where: { id: ride.id },
      data: { status: b.status as RideStatus },
    });

    if (b.status === 'COMPLETED') {
      const paidNow = ride.paymentMethod === PaymentMethod.CASH;
      await prisma.ride.update({
        where: { id: ride.id },
        data: { paymentStatus: paidNow ? PaymentStatus.PAID : PaymentStatus.PENDING },
      });
      if (ride.driverId) {
        await prisma.driver.update({
          where: { userId: ride.driverId },
          data: { status: DriverStatus.ONLINE, totalTrips: { increment: 1 } },
        });
        if (paidNow) {
          await creditDriver(ride.driverId, ride.driverEarnings, `CASH-${ride.id}`, 'Course terminÃ©e (EspÃ¨ces)');
          await notify(ride.driverId, NotificationType.PAYMENT, 'Course terminÃ©e', `+${ride.driverEarnings} FCFA enregistrÃ©s.`, { rideId: ride.id });
        }
      }
      await notify(ride.passengerId, NotificationType.RIDE, 'Course terminÃ©e', 'Merci dâ€™avoir voyagÃ© avec Yobalema !', { rideId: ride.id });
    }

    if (b.status === 'CANCELLED' && ride.driverId) {
      await prisma.driver.update({
        where: { userId: ride.driverId },
        data: { status: DriverStatus.ONLINE },
      });
    }

    io.to(`ride:${ride.id}`).emit('ride:status', { rideId: ride.id, status: b.status });
    io.to(`passenger:${ride.passengerId}`).emit('ride:status', { rideId: ride.id, status: b.status });

    res.json(u);
  } catch (e) {
    next(e);
  }
});

// PAYMENTS (CASH functional, Wave & Orange Money configured)
app.post('/api/rides/:id/payment/start', requireAuth, async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string }, include: { payment: true } });
    if (!ride || ride.passengerId !== req.user!.id) return res.status(403).json({ error: 'AccÃ¨s interdit' });
    if (ride.paymentMethod === PaymentMethod.CASH) {
      return res.json({ provider: 'CASH', status: 'READY', message: 'Paiement direct en espÃ¨ces au chauffeur' });
    }

    const reference = `YBL-${ride.id}-${Date.now()}`;
    const result = ride.paymentMethod === PaymentMethod.WAVE
      ? await paymentProviders.wave.createPayment(ride.priceFcfa, reference)
      : await paymentProviders.orangeMoney.createPayment(ride.priceFcfa, reference);

    res.json(result);
  } catch (e) {
    next(e);
  }
});

app.post('/api/rides/:id/payment/confirm', requireAuth, async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const b = z.object({ providerRef: z.string().min(3) }).parse(req.body);
    const ride = await prisma.ride.findUnique({ where: { id: id as string }, include: { payment: true } });
    if (!ride || ride.passengerId !== req.user!.id) return res.status(403).json({ error: 'AccÃ¨s interdit' });

    const now = new Date();
    const p = await prisma.payment.update({
      where: { rideId: ride.id },
      data: { status: PaymentStatus.PAID, providerRef: b.providerRef, paidAt: now },
    });
    await prisma.ride.update({ where: { id: ride.id }, data: { paymentStatus: PaymentStatus.PAID } });
    res.json(p);
  } catch (e) {
    next(e);
  }
});

// RATINGS, NOTIFICATIONS, SUPPORT & WALLET
app.post('/api/rides/:id/rating', requireAuth, async (req, res, next) => {
  try {
    const b = z.object({ score: z.number().int().min(1).max(5), comment: z.string().max(500).optional() }).parse(req.body);
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ride = await prisma.ride.findUnique({ where: { id: id as string } });
    if (!ride || ride.status !== RideStatus.COMPLETED || !ride.driverId) return res.status(409).json({ error: 'Course non Ã©ligible' });
    if (req.user!.id !== ride.passengerId && req.user!.id !== ride.driverId) return res.status(403).json({ error: 'AccÃ¨s interdit' });

    const to = req.user!.id === ride.passengerId ? ride.driverId : ride.passengerId;
    const r = await prisma.rating.create({
      data: { rideId: ride.id, fromUserId: req.user!.id, toUserId: to, score: b.score, comment: b.comment },
    });
    if (to === ride.driverId) {
      const all = await prisma.rating.aggregate({ where: { toUserId: to }, _avg: { score: true } });
      await prisma.driver.update({ where: { userId: to }, data: { rating: all._avg.score ?? 5 } });
    }
    res.status(201).json(r);
  } catch (e) {
    next(e);
  }
});

app.get('/api/notifications', requireAuth, async (req, res, next) => {
  try {
    res.json(await prisma.notification.findMany({ where: { userId: req.user!.id }, orderBy: { createdAt: 'desc' }, take: 50 }));
  } catch (e) {
    next(e);
  }
});

app.patch('/api/notifications/:id/read', requireAuth, async (req, res, next) => {
  try {
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const n = await prisma.notification.updateMany({ where: { id: id as string, userId: req.user!.id }, data: { readAt: new Date() } });
    res.json({ ok: n.count === 1 });
  } catch (e) {
    next(e);
  }
});

app.post('/api/support/tickets', requireAuth, async (req, res, next) => {
  try {
    const b = z.object({ subject: z.string().min(3).max(120), message: z.string().min(5).max(2000) }).parse(req.body);
    const t = await prisma.supportTicket.create({ data: { userId: req.user!.id, subject: b.subject, message: b.message } });
    res.status(201).json(t);
  } catch (e) {
    next(e);
  }
});

app.get('/api/support/tickets', requireAuth, async (req, res, next) => {
  try {
    res.json(await prisma.supportTicket.findMany({ where: { userId: req.user!.id }, orderBy: { createdAt: 'desc' } }));
  } catch (e) {
    next(e);
  }
});

app.get('/api/drivers/me/wallet', requireAuth, requireRole('DRIVER'), async (req, res, next) => {
  try {
    const entries = await prisma.walletEntry.findMany({ where: { userId: req.user!.id }, orderBy: { createdAt: 'desc' }, take: 100 });
    const balance = entries.reduce((sum, e) => sum + (e.type === WalletEntryType.CREDIT ? e.amountFcfa : -e.amountFcfa), 0);
    res.json({ balanceFcfa: balance, entries });
  } catch (e) {
    next(e);
  }
});

// SOCKET.IO REALTIME
io.use((socket, next) => {
  try {
    const raw = String(socket.handshake.auth?.token || socket.handshake.headers?.authorization || '');
    const token = raw.replace(/^Bearer\s+/i, '').trim();
    if (!token) {
      return next(); // Allow connection even if unauthenticated, join rooms upon auth
    }
    socket.data.auth = verifyToken(token);
    socket.data.userId = socket.data.auth.id;
    next();
  } catch (_e) {
    next();
  }
});

io.on('connection', (socket) => {
  const userId = socket.data.userId as string | undefined;
  if (userId) {
    socket.join(`user:${userId}`);
    if (socket.data.auth?.role === 'DRIVER') {
      socket.join(`driver:${userId}`);
      socket.join('drivers');
    } else {
      socket.join(`passenger:${userId}`);
    }
  }

  socket.on('driver:join', (id: string) => {
    socket.join(`driver:${id || userId}`);
    socket.join('drivers');
  });

  socket.on('passenger:join', (id: string) => {
    socket.join(`passenger:${id || userId}`);
  });

  socket.on('ride:join', async (rideId: string) => {
    socket.join(`ride:${rideId}`);
  });

  socket.on('ride:location', async (data: { rideId: string; lat: number; lng: number }) => {
    if (!inKaolack(data.lat, data.lng)) return;
    io.to(`ride:${data.rideId}`).emit('ride:location', data);
  });
});

// Error handling middleware
app.use((err: any, _req: any, res: any, _next: any) => {
  console.error('[API Error]:', err?.message || err);
  res.status(400).json({ error: err?.issues?.[0]?.message ?? err?.message ?? 'Erreur serveur' });
});

server.listen(config.port, () => {
  console.log(`[Yobalema Backend] En Ã©coute sur http://localhost:${config.port}`);
});

process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

