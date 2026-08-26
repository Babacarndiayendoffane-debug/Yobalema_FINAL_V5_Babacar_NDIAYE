import { RideStatus } from '@prisma/client';

/** Yobalema currently operates one vehicle category only: MOTO. */
export const YOBALEMA_VEHICLE_TYPE = 'MOTO' as const;

export const ALLOWED_RIDE_STATUS_TRANSITIONS: Readonly<Record<RideStatus, readonly RideStatus[]>> = {
  REQUESTED: ['ACCEPTED', 'CANCELLED'],
  ACCEPTED: ['DRIVER_ARRIVING', 'CANCELLED'],
  DRIVER_ARRIVING: ['IN_PROGRESS', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

export function isAllowedRideTransition(from: RideStatus, to: RideStatus): boolean {
  return ALLOWED_RIDE_STATUS_TRANSITIONS[from].includes(to);
}

export function assertRideTransition(from: RideStatus, to: RideStatus): void {
  if (!isAllowedRideTransition(from, to)) {
    throw new Error(`Transition de course interdite: ${from} -> ${to}`);
  }
}

export function normalizeVehicleType(value: string): string {
  return value.trim().toUpperCase() === YOBALEMA_VEHICLE_TYPE ? YOBALEMA_VEHICLE_TYPE : '';
}
