import { calculatePrice } from '../src/pricing';
import { inKaolack } from '../src/geo';

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

const shortRide = calculatePrice(1.5, 'CITY', 'CITY', 0, false);
assert(shortRide.total === 300, 'Minimum urban ride must be 300 FCFA');
assert(shortRide.platform === Math.round(shortRide.total * 0.10), 'Platform must receive exactly 10%');
assert(shortRide.driver === shortRide.total - shortRide.platform, 'Driver must receive the other 90%');

const mediumRide = calculatePrice(4, 'CITY', 'CITY', 2, false);
assert(mediumRide.total === 450, '4 km at traffic level 2 must remain 450 FCFA');
assert(mediumRide.platform === 45, '450 FCFA must produce a 45 FCFA platform fee');
assert(mediumRide.driver === 405, '450 FCFA must produce 405 FCFA driver earnings');

const nightVillage = calculatePrice(5, 'VILLAGE', 'VILLAGE', 3, true);
assert(nightVillage.total >= 300, 'Village fare must respect the minimum');
assert(nightVillage.platform === Math.round(nightVillage.total * 0.10), 'Night village fare must preserve 10% commission');

const allowed = [
  [14.151, -16.0726],
  [13.8447, -15.9382],
  [13.75, -15.80],
  [14.27, -15.95],
] as const;
for (const [lat, lng] of allowed) assert(inKaolack(lat, lng), `Expected Kaolack point: ${lat},${lng}`);

const forbidden = [
  [14.7167, -17.4677],
  [14.7886, -16.9250],
  [15.0000, -16.0000],
] as const;
for (const [lat, lng] of forbidden) assert(!inKaolack(lat, lng), `Expected outside point: ${lat},${lng}`);

console.log('Yobalema masterclass business invariants: OK');
