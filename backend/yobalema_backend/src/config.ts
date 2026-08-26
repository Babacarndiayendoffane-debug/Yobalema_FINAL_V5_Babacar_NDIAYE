import 'dotenv/config';

const nodeEnv = process.env.NODE_ENV ?? 'development';
const isProduction = nodeEnv === 'production';

function requiredSecret(name: string, fallback: string): string {
  const value = process.env[name]?.trim();
  if (value) return value;
  if (isProduction) throw new Error(`${name} must be configured in production`);
  return fallback;
}

export const config = {
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: requiredSecret('JWT_SECRET', 'dev-secret-change-me'),
  corsOrigin: process.env.CORS_ORIGIN ?? (isProduction ? '' : '*'),
  nodeEnv,
  otpDev: process.env.OTP_DEV === 'true' && !isProduction,
  maxRideSearchKm: Math.min(20, Math.max(1, Number(process.env.MAX_RIDE_SEARCH_KM ?? 10))),
  paymentWebhookSecret: requiredSecret('PAYMENT_WEBHOOK_SECRET', 'dev-payment-webhook-secret'),
  isProduction,
};
