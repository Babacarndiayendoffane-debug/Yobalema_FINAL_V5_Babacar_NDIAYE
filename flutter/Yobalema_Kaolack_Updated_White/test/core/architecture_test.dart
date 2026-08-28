import 'package:flutter_test/flutter_test.dart';
import 'package:yobalema/core/models/ride.dart';
import 'package:yobalema/core/state/ride_state_machine.dart';

void main() {
  test('ride state machine exposes the complete production lifecycle', () {
    expect(
      RideStateMachine.canTransition(
        RideStatus.requested,
        RideStatus.driverAssigned,
      ),
      isTrue,
    );
    expect(
      RideStateMachine.canTransition(
        RideStatus.driverAssigned,
        RideStatus.driverArriving,
      ),
      isTrue,
    );
    expect(
      RideStateMachine.canTransition(
        RideStatus.driverArriving,
        RideStatus.inProgress,
      ),
      isTrue,
    );
    expect(
      RideStateMachine.canTransition(
        RideStatus.inProgress,
        RideStatus.paymentPending,
      ),
      isTrue,
    );
    expect(
      RideStateMachine.canTransition(
        RideStatus.paymentPending,
        RideStatus.completed,
      ),
      isTrue,
    );
  });

  test('terminal states cannot be reopened', () {
    for (final terminal in [RideStatus.completed, RideStatus.cancelled]) {
      for (final target in RideStatus.values) {
        expect(
          RideStateMachine.canTransition(terminal, target),
          isFalse,
          reason: '$terminal must remain terminal',
        );
      }
    }
  });

  test('API values round-trip for ride statuses and payment methods', () {
    for (final status in RideStatus.values) {
      expect(RideStatusX.fromApi(status.apiValue), status);
    }

    for (final method in PaymentMethod.values) {
      expect(PaymentMethodX.fromApi(method.apiValue), method);
    }
  });
}
