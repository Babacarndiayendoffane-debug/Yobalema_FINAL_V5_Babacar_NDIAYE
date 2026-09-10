import { calculatePrice } from '../src/pricing';
import { inKaolack, isPointInKaolackRegion, haversineKm, estimateRoadDistanceKm } from '../src/geo';

// 1. Pricing test with peak traffic
const q = calculatePrice(4, 'CITY', 'CITY', 2, false);
if (q.total !== 450) throw new Error(`Pricing smoke test failed: ${q.total}`);
if (q.driver !== 405 || q.platform !== 45) {
  throw new Error(`Commission test failed: driver=${q.driver}, platform=${q.platform}`);
}

// 2. Exact 10% platform commission invariant
const qLong = calculatePrice(25, 'VILLAGE', 'CITY', 0, false);
if (qLong.driver + qLong.platform !== qLong.total) throw new Error('Sum invariant failed');
if (qLong.driver !== Math.round(qLong.total * 0.90)) throw new Error('Driver 90% invariant failed');
if (qLong.platform !== qLong.total - qLong.driver) throw new Error('Platform 10% invariant failed');

// 3. Kaolack Regional Polygon Boundary tests
const validLocations = [
  ['Kaolack Centre', 14.1510, -16.0726],
  ['Kahone', 14.1560, -16.0400],
  ['Ndoffane', 13.8447, -15.9382],
  ['Gandiaye', 14.2300, -16.3200],
  ['Sibassor', 14.1500, -16.0000],
  ['Latmingue', 14.2700, -15.9800],
  ['Nioro du Rip', 13.7500, -15.7800],
  ['Porokhane', 13.8000, -15.7000],
  ['Medina Sabakh', 13.6002, -15.5804],
  ['Guinguineo', 14.2700, -15.9500],
  ['Mbadakhoune', 14.3000, -15.8500],
  ['Ngathie Naoude', 14.3500, -15.9500],
];

for (const [name, lat, lng] of validLocations) {
  if (!isPointInKaolackRegion(lat as number, lng as number)) {
    throw new Error(`Erreur: localité autorisée rejetée: ${name} (${lat}, ${lng})`);
  }
}

// 4. Out-of-region rejections (Dakar, Thiès, Touba, Fatick, Gambia)
const outsideLocations = [
  ['Dakar Plateau', 14.6698, -17.4326],
  ['Almadies', 14.7470, -17.5180],
  ['Thies', 14.7900, -16.9260],
  ['Touba', 14.8620, -15.8770],
  ['Fatick', 14.3310, -16.4060],
  ['Banjul', 13.4549, -16.5790],
];

for (const [name, lat, lng] of outsideLocations) {
  if (isPointInKaolackRegion(lat as number, lng as number)) {
    throw new Error(`Erreur: lieu hors Kaolack accepté: ${name} (${lat}, ${lng})`);
  }
}

console.log('✅ Yobalema Backend Smoke Tests: Pricing (10% Comm), Kaolack Regional Polygon & Rejections ALL PASSED!');

