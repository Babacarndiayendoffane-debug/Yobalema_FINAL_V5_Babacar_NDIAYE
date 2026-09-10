import 'dotenv/config';

export const config = {
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: process.env.JWT_SECRET ?? 'dev-secret-change-me',
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  nodeEnv: process.env.NODE_ENV ?? 'development',
  otpDev: process.env.OTP_DEV === 'true',
  maxRideSearchKm: Number(process.env.MAX_RIDE_SEARCH_KM ?? 10),
  paymentWebhookSecret: process.env.PAYMENT_WEBHOOK_SECRET ?? 'dev-payment-webhook-secret',
};
