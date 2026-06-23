import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/base/observable.dart';

class TestObserver with Observable {
  void trigger() {
    notifyListeners();
  }
}

void main() {
  group('Observable', () {
    group('addListener', () {
      test(
          'Given no listeners, When addListener called, Then listener is registered',
          () {
        final observer = TestObserver();
        int callCount = 0;

        observer.addListener(() => callCount++);

        observer.trigger();
        expect(callCount, equals(1));
      });

      test(
          'Given multiple listeners, When addListener called, Then all listeners are registered',
          () {
        final observer = TestObserver();
        int callCount1 = 0;
        int callCount2 = 0;

        observer.addListener(() => callCount1++);
        observer.addListener(() => callCount2++);

        observer.trigger();
        expect(callCount1, equals(1));
        expect(callCount2, equals(1));
      });

      test(
          'Given duplicate listener, When addListener called, Then listener is only added once',
          () {
        final observer = TestObserver();
        int callCount = 0;
        void listener() => callCount++;

        observer.addListener(listener);
        observer.addListener(listener);

        observer.trigger();
        expect(callCount, equals(1));
      });
    });

    group('removeListener', () {
      test(
          'Given registered listener, When removeListener called, Then listener is removed',
          () {
        final observer = TestObserver();
        int callCount = 0;
        void listener() => callCount++;

        observer.addListener(listener);
        observer.removeListener(listener);

        observer.trigger();
        expect(callCount, equals(0));
      });

      test(
          'Given unregistered listener, When removeListener called, Then no error thrown',
          () {
        final observer = TestObserver();

        expect(() => observer.removeListener(() {}), returnsNormally);
      });
    });

    group('notifyListeners', () {
      test(
          'Given single listener, When notifyListeners called, Then listener is invoked',
          () {
        final observer = TestObserver();
        int callCount = 0;

        observer.addListener(() => callCount++);
        observer.trigger();

        expect(callCount, equals(1));
      });

      test(
          'Given multiple listeners, When notifyListeners called, Then all listeners are invoked',
          () {
        final observer = TestObserver();
        int callCount1 = 0;
        int callCount2 = 0;

        observer.addListener(() => callCount1++);
        observer.addListener(() => callCount2++);
        observer.trigger();

        expect(callCount1, equals(1));
        expect(callCount2, equals(1));
      });

      test(
          'Given listener removed during notification, When notifyListeners called, Then does not crash',
          () {
        final observer = TestObserver();
        void listener2() {}

        observer.addListener(listener2);
      });
    });
  });
}
