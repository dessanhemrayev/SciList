import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scilist/core/utils/issn_input_formatter.dart';

TextEditingValue _format(TextEditingValue current, TextEditingValue edited) {
  return const IssnInputFormatter().formatEditUpdate(current, edited);
}

TextEditingValue _insert(TextEditingValue current, int caret, String insert) {
  return _format(
    current,
    TextEditingValue(
      text: current.text.replaceRange(caret, caret, insert),
      selection: TextSelection.collapsed(offset: caret + insert.length),
    ),
  );
}

TextEditingValue _backspace(TextEditingValue current, int caret) {
  return _format(
    current,
    TextEditingValue(
      text: current.text.replaceRange(caret - 1, caret, ''),
      selection: TextSelection.collapsed(offset: caret - 1),
    ),
  );
}

TextEditingValue _valueOf(String text, int caret) {
  return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: caret));
}

void main() {
  const empty = TextEditingValue();

  test('последовательный набор 8 цифр ставит курсор в конец', () {
    var value = empty;
    var caret = 0;

    for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8']) {
      value = _insert(value, caret, digit);
      caret = value.selection.baseOffset;
    }

    expect(value.text, '1234-5678');
    expect(value.selection.baseOffset, 9);
  });

  test('дефис добавляется после 4-й цифры без скачка курсора', () {
    final value = _insert(_valueOf('1234', 4), 4, '5');
    expect(value.text, '1234-5');
    expect(value.selection.baseOffset, 6);
  });

  test('вставка цифры перед последней позицией', () {
    final value = _insert(_valueOf('1234-5678', 8), 8, '9');
    expect(value.text, '1234-5679');
    expect(value.selection.baseOffset, 9);
  });

  test('вставка цифры в начало', () {
    final value = _insert(_valueOf('1234-5678', 0), 0, '9');
    expect(value.text, '9123-4567');
    expect(value.selection.baseOffset, 1);
  });

  test('backspace убирает последнюю цифру и не трогает дефис', () {
    final value = _backspace(_valueOf('1234-5678', 9), 9);
    expect(value.text, '1234-567');
    expect(value.selection.baseOffset, 8);
  });

  test('backspace по дефису восстанавливает его и держит курсор', () {
    final value = _backspace(_valueOf('1234-5678', 5), 5);
    expect(value.text, '1234-5678');
    expect(value.selection.baseOffset, 5);
  });

  test('backspace по 5-й цифре', () {
    final value = _backspace(_valueOf('1234-5678', 6), 6);
    expect(value.text, '1234-678');
    expect(value.selection.baseOffset, 5);
  });

  test('backspace по 4-й цифре сдвигает маску', () {
    final value = _backspace(_valueOf('1234-5678', 4), 4);
    expect(value.text, '1235-678');
    expect(value.selection.baseOffset, 3);
  });

  test('backspace в середине', () {
    final value = _backspace(_valueOf('1234-5678', 8), 8);
    expect(value.text, '1234-568');
    expect(value.selection.baseOffset, 7);
  });

  test('вставка из буфера с дефисом', () {
    final value = _insert(empty, 0, '1234-5678');
    expect(value.text, '1234-5678');
    expect(value.selection.baseOffset, 9);
  });

  test('вставка из буфера без дефиса', () {
    final value = _insert(empty, 0, '12345678');
    expect(value.text, '1234-5678');
    expect(value.selection.baseOffset, 9);
  });

  test('лишние символы отбрасываются', () {
    final value = _insert(empty, 0, '12345678901');
    expect(value.text, '1234-5678');
    expect(value.selection.baseOffset, 9);
  });

  test('недопустимые символы фильтруются', () {
    final value = _insert(empty, 0, 'abc');
    expect(value.text, '');
  });

  test('строчная x превращается в X', () {
    final value = _insert(empty, 0, '1234567x');
    expect(value.text, '1234-567X');
    expect(value.selection.baseOffset, 9);
  });

  test('выделение и замена диапазона', () {
    final current = TextEditingValue(
      text: '1234-5678',
      selection: const TextSelection(baseOffset: 5, extentOffset: 8),
    );
    final value = _format(
      current,
      TextEditingValue(
        text: current.text.replaceRange(5, 8, '9'),
        selection: const TextSelection.collapsed(offset: 6),
      ),
    );
    expect(value.text, '1234-98');
    expect(value.selection.baseOffset, 6);
  });
}