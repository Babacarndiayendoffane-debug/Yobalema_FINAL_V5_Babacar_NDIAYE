import '../models/ride.dart';

class RideStateMachine {
  static const _allowed = <RideStatus, Set<RideStatus>>{
    RideStatus.requested: {RideStatus.driverAssigned, RideStatus.cancelled},
    RideStatus.driverAssigned: {RideStatus.driverArriving, RideStatus.cancelled},
    RideStatus.driverArriving: {RideStatus.inProgress, RideStatus.cancelled},
    RideStatus.inProgress: {RideStatus.paymentPending, RideStatus.completed},
    RideStatus.paymentPending: {RideStatus.completed},
    RideStatus.completed: {},
    RideStatus.cancelled: {},
  };

  static bool canTransition(RideStatus from, RideStatus to) => _allowed[from]?.contains(to) ?? false;

  static RideStatus requireTransition(RideStatus from, RideStatus to) {
    if (!canTransition(from, to)) {
      throw StateError('Invalid ride transition: $from -> $to');
    }
    return to;
  }
}
