export const KAOLACK_BOUNDS = { minLat: 13.50, maxLat: 14.55, minLng: -16.45, maxLng: -15.35 };

// Outer ring for Région de Kaolack, WGS84 [longitude, latitude].
// Bounding box is only a fast pre-check; final authorization uses the polygon.
export const KAOLACK_REGION_POLYGON: ReadonlyArray<readonly [number, number]> = [
  [-15.49803009, 13.64152230], [-16.06405351, 13.58511505], [-16.15391802, 13.67756338],
  [-16.24073442, 13.80504914], [-16.19722287, 13.89791169], [-16.24869259, 14.02885977],
  [-16.29142900, 14.15262482], [-16.37214759, 14.16265005], [-16.38015744, 14.16843781],
  [-16.36579139, 14.18724803], [-16.35581784, 14.22094107], [-16.30574337, 14.29380484],
  [-16.25706418, 14.33959016], [-16.16461504, 14.35509308], [-15.90491690, 14.36765148],
  [-15.79900428, 14.38485871], [-15.74602176, 13.92892060], [-15.60451885, 13.79467425],
  [-15.47390077, 13.79467425], [-15.39406856, 13.77151194], [-15.43633988, 13.74117788],
  [-15.47861121, 13.69125844], [-15.49803009, 13.64152230],
];

function pointInPolygon(lat: number, lng: number, polygon: ReadonlyArray<readonly [number, number]>) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const [xi, yi] = polygon[i];
    const [xj, yj] = polygon[j];
    const intersects = ((yi > lat) !== (yj > lat)) && (lng < ((xj - xi) * (lat - yi)) / (yj - yi) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}

export function inKaolack(lat: number, lng: number) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false;
  if (lat < KAOLACK_BOUNDS.minLat || lat > KAOLACK_BOUNDS.maxLat || lng < KAOLACK_BOUNDS.minLng || lng > KAOLACK_BOUNDS.maxLng) return false;
  return pointInPolygon(lat, lng, KAOLACK_REGION_POLYGON);
}

export function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number) {
  const R = 6371;
  const dLat = (bLat - aLat) * Math.PI / 180;
  const dLng = (bLng - aLng) * Math.PI / 180;
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(aLat * Math.PI / 180) * Math.cos(bLat * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}
