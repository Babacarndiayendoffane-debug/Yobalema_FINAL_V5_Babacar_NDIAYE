export type Zone = 'CITY' | 'PERIURBAN' | 'VILLAGE';

export function trafficFactor(zone: Zone, level: number): number {
  if (zone === 'VILLAGE') return 1.0;
  if (level <= 0) return 1.0;
  if (level === 1) return 1.05;
  if (level === 2) return 1.10;
  return 1.15;
}

/**
 * Calculates Yobalema Moto price across Kaolack region.
 * STRICT RULE: Platform commission is exactly 10%, driver gets 90%.
 */
export function calculatePrice(
  km: number,
  fromZone: Zone,
  toZone: Zone,
  trafficLevel: number,
  night: boolean
) {
  const zone: Zone =
    fromZone === 'CITY' || toZone === 'CITY'
      ? 'CITY'
      : fromZone === 'PERIURBAN' || toZone === 'PERIURBAN'
      ? 'PERIURBAN'
      : 'VILLAGE';

  let base: number;
  let explanation: string;

  if (zone === 'CITY') {
    if (km <= 2) base = 300;
    else if (km <= 4) base = 400;
    else if (km <= 6) base = 500;
    else if (km <= 10) base = 700;
    else base = 700 + (km - 10) * 75;
    explanation = 'Tarif Moto urbain : distance routière + trafic estimé.';
  } else if (zone === 'PERIURBAN') {
    base = 500 + km * 85;
    explanation = 'Tarif Moto périurbain : distance routière + disponibilité.';
  } else {
    base = 350 + km * 95;
    explanation = 'Tarif Moto village / intercommunal : distance routière + conditions de route.';
  }

  let total = base * trafficFactor(zone, trafficLevel);
  if (night) total += zone === 'VILLAGE' ? 100 : 200;

  total = Math.min(25000, Math.max(300, total));
  const rounded = Math.round(total / 50) * 50;

  // Strict 10% platform commission / 90% driver earnings
  const driver = Math.round(rounded * 0.90);
  const platform = rounded - driver;

  return {
    total: rounded,
    driver,
    platform,
    trafficFactor: trafficFactor(zone, trafficLevel),
    zone,
    service: 'MOTO',
    explanation,
  };
}
