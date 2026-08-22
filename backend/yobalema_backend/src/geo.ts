export const KAOLACK_BOUNDS = { minLat: 13.50, maxLat: 14.55, minLng: -16.45, maxLng: -15.35 };
export function inKaolack(lat: number, lng: number) {
  return lat >= KAOLACK_BOUNDS.minLat && lat <= KAOLACK_BOUNDS.maxLat && lng >= KAOLACK_BOUNDS.minLng && lng <= KAOLACK_BOUNDS.maxLng;
}
export function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number) {
  const R = 6371;
  const dLat = (bLat-aLat)*Math.PI/180, dLng = (bLng-aLng)*Math.PI/180;
  const x = Math.sin(dLat/2)**2 + Math.cos(aLat*Math.PI/180)*Math.cos(bLat*Math.PI/180)*Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1-x));
}
