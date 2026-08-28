import 'package:flutter_test/flutter_test.dart';
import 'package:yobalema/core/models/ride_status.dart';
import 'package:yobalema/core/state/ride_state_machine.dart';

void main() {
  group('RideStateMachine', () {
    test('allows the normal motorcycle ride lifecycle', () {
      const flow = [
        RideStatus.requested,
        RideStatus.driverAssigned,
        RideStatus.driverArriving,
        RideStatus.inProgress,
        RideStatus.paymentPending,
        RideStatus.completed,
      ];

      for (var index = 0; index < flow.length - 1; index++) {
        expect(
          RideStateMachine.canTransition(flow[index], flow[index + 1]),
          isTrue,
        );
      }
    });

    test('allows cancellation only before terminal completion', () {
      expect(
        RideStateMachine.canTransition(
          RideStatus.requested,
          RideStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        RideStateMachine.canTransition(
          RideStatus.inProgress,
          RideStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        RideStateMachine.canTransition(
          RideStatus.completed,
          RideStatus.cancelled,
        ),
        isFalse,
      );
    });

    test('rejects invalid lifecycle jumps', () {
      expect(
        RideStateMachine.canTransition(
          RideStatus.requested,
          RideStatus.completed,
        ),
        isFalse,
      );
      expect(
        RideStateMachine.canTransition(
          RideStatus.driverAssigned,
          RideStatus.inProgress,
        ),
        isFalse,
      );
      expect(
        () => RideStateMachine.requireTransition(
          RideStatus.completed,
          RideStatus.inProgress,
        ),
        throwsStateError,
      );
    });

    test('maps statuses to backend contract values', () {
      expect(RideStatus.requested.apiValue, 'REQUESTED');
      expect(RideStatus.driverAssigned.apiValue, 'DRIVER_ASSIGNED');
      expect(RideStatus.driverArriving.apiValue, 'DRIVER_ARRIVING');
      expect(RideStatus.inProgress.apiValue, 'IN_PROGRESS');
      expect(RideStatus.paymentPending.apiValue, 'PAYMENT_PENDING');
      expect(RideStatus.completed.apiValue, 'COMPLETED');
      expect(RideStatus.cancelled.apiValue, 'CANCELLED');
      expect(RideStatusX.fromApi('in_progress'), RideStatus.requested);
      expect(RideStatusX.fromApi('IN_PROGRESS'), RideStatus.inProgress);
    });

    test('exposes only valid next statuses', () {
      expect(
        RideStateMachine.nextStatuses(RideStatus.requested),
        containsAll({RideStatus.driverAssigned, RideStatus.cancelled}),
      );
      expect(RideStateMachine.nextStatuses(RideStatus.completed), isEmpty);
      expect(RideStateMachine.isTerminal(RideStatus.completed), isTrue);
      expect(RideStateMachine.isTerminal(RideStatus.cancelled), isTrue);
      expect(RideStateMachine.isTerminal(RideStatus.inProgress), isFalse);
    });
  });
}
