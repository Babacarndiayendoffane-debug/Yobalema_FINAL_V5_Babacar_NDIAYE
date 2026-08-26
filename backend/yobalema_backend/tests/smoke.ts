import { calculatePrice } from '../src/pricing';
import { inKaolack } from '../src/geo';

const q = calculatePrice(4, 'CITY', 'CITY', 2, false);
if (q.total !== 450) throw new Error(`Pricing smoke test failed: ${q.total}`);
if (q.platform !== Math.round(q.total * 0.10)) throw new Error(`Platform commission must be 10%: ${q.platform}`);
if (q.driver !== Math.round(q.total * 0.90)) throw new Error(`Driver share must be 90%: ${q.driver}`);

const inside = [
  [14.15, -16.07], // Kaolack area
  [13.75, -15.80], // Nioro du Rip
  [14.25, -15.95], // Guinguinéo sector
] as const;
for (const [lat, lng] of inside) if (!inKaolack(lat, lng)) throw new Error(`Expected point inside Kaolack: ${lat},${lng}`);

const outside = [
  [14.7167, -17.4677], // Dakar
  [14.7886, -16.9250], // Thiès area
  [14.25, -15.58],      // Kaffrine-side area
] as const;
for (const [lat, lng] of outside) if (inKaolack(lat, lng)) throw new Error(`Expected point outside Kaolack: ${lat},${lng}`);

console.log('Yobalema smoke tests OK');
