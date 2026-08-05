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
          'Given listener added during notification, When notifyListeners called, '
          'Then new listener is not invoked until the next notification', () {
        final observer = TestObserver();
        var firstCalls = 0;
        var addedCalls = 0;
        void added() => addedCalls++;

        observer.addListener(() {
          firstCalls++;
          observer.addListener(added);
        });

        observer.trigger();
        expect(firstCalls, equals(1));
        expect(addedCalls, equals(0));

        observer.trigger();
        expect(addedCalls, equals(1));
      });

      test(
          'Given listener removed during notification, When notifyListeners called, '
          'Then does not crash and removed listener is still invoked for this pass',
          () {
        final observer = TestObserver();
        var removedCalls = 0;
        var keptCalls = 0;
        void removed() => removedCalls++;
        void kept() => keptCalls++;

        observer.addListener(removed);
        observer.addListener(() {
          observer.removeListener(removed);
          observer.addListener(kept);
        });

        observer.trigger();
        // Snapshot semantics: removed listener still invoked for this pass,
        // listener added mid-notification is deferred to the next pass.
        expect(removedCalls, equals(1));
        expect(keptCalls, equals(0));

        observer.trigger();
        expect(removedCalls, equals(1));
        expect(keptCalls, equals(1));
      });
    });
  });
}
