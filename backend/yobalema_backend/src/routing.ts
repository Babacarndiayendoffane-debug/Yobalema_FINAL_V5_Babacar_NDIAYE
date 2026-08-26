export type RoutePoint = { lat: number; lng: number };

export type RouteResult = {
  distanceKm: number;
  durationMin: number;
  geometry: RoutePoint[];
};

type OsrmRoute = {
  distance?: number;
  duration?: number;
  geometry?: { coordinates?: Array<[number, number]> };
};

export async function routeRoad(fromLat: number, fromLng: number, toLat: number, toLng: number): Promise<RouteResult | null> {
  const base = (process.env.OSRM_BASE_URL ?? 'https://router.project-osrm.org').replace(/\/$/, '');
  const url = `${base}/route/v1/driving/${fromLng},${fromLat};${toLng},${toLat}?overview=full&geometries=geojson&steps=false`;
  try {
    const response = await fetch(url, {
      headers: { accept: 'application/json' },
      signal: AbortSignal.timeout(7000),
    });
    if (!response.ok) return null;
    const payload = await response.json() as { routes?: OsrmRoute[] };
    const route = payload.routes?.[0];
    const coords = route?.geometry?.coordinates;
    if (!route || !Number.isFinite(route.distance) || !Number.isFinite(route.duration) || !coords?.length) return null;

    const geometry = coords
      .filter(([lng, lat]) => Number.isFinite(lat) && Number.isFinite(lng))
      .map(([lng, lat]) => ({ lat, lng }));
    if (geometry.length < 2) return null;

    return {
      distanceKm: route.distance! / 1000,
      durationMin: route.duration! / 60,
      geometry,
    };
  } catch {
    return null;
  }
}
