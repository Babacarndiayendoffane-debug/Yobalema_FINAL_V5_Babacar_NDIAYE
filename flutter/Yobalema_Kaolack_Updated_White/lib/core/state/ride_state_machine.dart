import '../models/ride.dart';

/// Single source of truth for the client-side ride lifecycle.
///
/// The backend remains authoritative. This class prevents UI code from
/// making impossible state jumps and keeps Passenger and Driver aligned.
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
      RideStatus.cancelled,
    },
    RideStatus.paymentPending: {
      RideStatus.completed,
      RideStatus.cancelled,
    },
    RideStatus.completed: <RideStatus>{},
    RideStatus.cancelled: <RideStatus>{},
  };

  static bool canTransition(RideStatus from, RideStatus to) {
    return _allowed[from]?.contains(to) ?? false;
  }

  static RideStatus requireTransition(RideStatus from, RideStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid ride transition: $from -> $to');
    }
    return to;
  }

  static Set<RideStatus> nextStatuses(RideStatus current) {
    return Set<RideStatus>.unmodifiable(_allowed[current] ?? const {});
  }

  static bool isTerminal(RideStatus status) {
    return status == RideStatus.completed || status == RideStatus.cancelled;
  }
}
