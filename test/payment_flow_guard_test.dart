import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wali_santri/utils/payment_flow_guard.dart';

void main() {
  test('ignores a second payment flow while the first is active', () async {
    final release = Completer<void>();
    var opened = 0;

    final first = PaymentFlowGuard.run(() async {
      opened++;
      await release.future;
      return true;
    });

    final second = await PaymentFlowGuard.run(() async {
      opened++;
      return true;
    });

    expect(second, isNull);
    expect(opened, 1);
    expect(PaymentFlowGuard.isLocked, isTrue);

    release.complete();
    expect(await first, isTrue);
    expect(PaymentFlowGuard.isLocked, isFalse);
  });

  test('releases the lock when a payment flow throws', () async {
    await expectLater(
      PaymentFlowGuard.run<void>(() async => throw StateError('gagal')),
      throwsStateError,
    );

    expect(PaymentFlowGuard.isLocked, isFalse);
  });
}
