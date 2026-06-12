import 'package:flutter_test/flutter_test.dart';
import 'package:kterm/src/ui/pointer_input.dart';

void main() {
  group('PointerInput', () {
    test('has all expected values', () {
      expect(PointerInput.values, hasLength(4));
      expect(
          PointerInput.values,
          containsAll([
            PointerInput.tap,
            PointerInput.scroll,
            PointerInput.drag,
            PointerInput.move,
          ]));
    });

    test('values are distinct', () {
      expect(PointerInput.values.toSet(), hasLength(4));
    });

    test('tap has correct name', () {
      expect(PointerInput.tap.name, equals('tap'));
    });

    test('scroll has correct name', () {
      expect(PointerInput.scroll.name, equals('scroll'));
    });

    test('drag has correct name', () {
      expect(PointerInput.drag.name, equals('drag'));
    });

    test('move has correct name', () {
      expect(PointerInput.move.name, equals('move'));
    });
  });

  group('PointerInputs', () {
    test('none() creates empty set', () {
      const inputs = PointerInputs.none();
      expect(inputs.inputs, isEmpty);
    });

    test('all() creates set with all values', () {
      const inputs = PointerInputs.all();
      expect(
          inputs.inputs,
          containsAll([
            PointerInput.tap,
            PointerInput.scroll,
            PointerInput.drag,
            PointerInput.move,
          ]));
      expect(inputs.inputs, hasLength(4));
    });

    test('constructor accepts custom set', () {
      const inputs = PointerInputs({PointerInput.tap, PointerInput.drag});
      expect(inputs.inputs, hasLength(2));
      expect(inputs.inputs, contains(PointerInput.tap));
      expect(inputs.inputs, contains(PointerInput.drag));
      expect(inputs.inputs, isNot(contains(PointerInput.scroll)));
    });

    test('none() and all() are const', () {
      // Compile-time verification — these must not produce a runtime error
      const none = PointerInputs.none();
      const all = PointerInputs.all();
      expect(none, isA<PointerInputs>());
      expect(all, isA<PointerInputs>());
    });

    test('none() equals another none()', () {
      const a = PointerInputs.none();
      const b = PointerInputs.none();
      expect(a.inputs, equals(b.inputs));
    });

    test('all() equals another all()', () {
      const a = PointerInputs.all();
      const b = PointerInputs.all();
      expect(a.inputs, equals(b.inputs));
    });

    test('identical sets have equal contents', () {
      const a = PointerInputs({PointerInput.tap, PointerInput.scroll});
      const b = PointerInputs({PointerInput.scroll, PointerInput.tap});
      expect(a.inputs, equals(b.inputs));
    });

    test('different sets are not equal', () {
      const a = PointerInputs({PointerInput.tap});
      const b = PointerInputs({PointerInput.scroll});
      expect(a, isNot(equals(b)));
    });
  });
}
