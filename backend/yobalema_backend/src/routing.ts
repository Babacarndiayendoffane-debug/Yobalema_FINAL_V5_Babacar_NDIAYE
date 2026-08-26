export type RouteResult = {
  distanceKm: number;
  durationMin: number;
  geometry?: unknown;
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
    const payload = await response.json() as {
      routes?: Array<{ distance?: number; duration?: number; geometry?: unknown }>;
    };
    const route = payload.routes?.[0];
    if (!route || !Number.isFinite(route.distance) || !Number.isFinite(route.duration)) return null;
    return {
      distanceKm: route.distance / 1000,
      durationMin: route.duration / 60,
      geometry: route.geometry,
    };
  } catch {
    return null;
  }
}
