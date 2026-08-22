import { calculatePrice } from '../src/pricing';
const q = calculatePrice(4, 'CITY' as any, 'CITY' as any, 2, false);
if (q.total !== 450) throw new Error(`Pricing smoke test failed: ${q.total}`);
console.log('Yobalema smoke test OK');
