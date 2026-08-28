import 'package:flutter_test/flutter_test.dart';
import 'package:yobalema/core/models/ride.dart';
import 'package:yobalema/core/state/ride_state_machine.dart';

void main() {
  group('RideStateMachine', () {
    test('allows the normal motorcycle ride lifecycle', () {
      expect(RideStateMachine.canTransition(RideStatus.requested, RideStatus.driverAssigned), isTrue);
      expect(RideStateMachine.canTransition(RideStatus.driverAssigned, RideStatus.driverArriving), isTrue);
      expect(RideStateMachine.canTransition(RideStatus.driverArriving, RideStatus.inProgress), isTrue);
      expect(RideStateMachine.canTransition(RideStatus.inProgress, RideStatus.paymentPending), isTrue);
      expect(RideStateMachine.canTransition(RideStatus.paymentPending, RideStatus.completed), isTrue);
    });

    test('rejects invalid lifecycle jumps', () {
      expect(RideStateMachine.canTransition(RideStatus.requested, RideStatus.completed), isFalse);
      expect(() => RideStateMachine.requireTransition(RideStatus.completed, RideStatus.inProgress), throwsStateError);
    });
  });
}
