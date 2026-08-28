import '../models/ride.dart';

/// Single source of truth for client-side ride lifecycle transitions.
/// The backend remains authoritative, but the UI uses this guard to avoid
/// presenting impossible actions.
class RideStateMachine {
  const RideStateMachine._();

  static const Map<RideStatus, Set<RideStatus>> _allowed = {
    RideStatus.requested: {
      RideStatus.driverAssigned,
      RideStatus.cancelled,
    },
    RideStatus.driverAssigned: {
      RideStatus.driverArriving,
      RideStatus.cancelled,
    },
    RideStatus.driverArriving: {
      RideStatus.inProgress,
      RideStatus.cancelled,
    },
    RideStatus.inProgress: {
      RideStatus.paymentPending,
      RideStatus.completed,
    },
    RideStatus.paymentPending: {
      RideStatus.completed,
    },
    RideStatus.completed: {},
    RideStatus.cancelled: {},
  };

  static bool canTransition(RideStatus from, RideStatus to) =>
      _allowed[from]?.contains(to) ?? false;

  static void requireTransition(RideStatus from, RideStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid ride transition: $from -> $to');
    }
  }

  static bool isTerminal(RideStatus status) =>
      status == RideStatus.completed || status == RideStatus.cancelled;
}
