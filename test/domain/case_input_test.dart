import 'package:characters/characters.dart';
import 'package:fee_app/features/cases/domain/case_input.dart';
import 'package:fee_app/features/cases/domain/privacy_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CaseInput input({String title = 'Caso', String notes = ''}) => CaseInput(
    title: title,
    sourceUrl: '  https://example.com/post?item=1  ',
    category: CaseCategory.personalData,
    notes: notes,
  );

  test('normalizes input without losing the URL query or note contents', () {
    final value = input(
      title: '  Mi caso  ',
      notes: '  Una nota\ncon líneas  ',
    );
    expect(value.title, 'Mi caso');
    expect(value.notes, 'Una nota\ncon líneas');
    expect(value.sourceUrl.toString(), 'https://example.com/post?item=1');
    expect(value.category, CaseCategory.personalData);
  });

  test('title is required and accepts exactly its documented limit', () {
    expect(() => input(title: ' \n '), throwsFormatException);
    expect(input(title: 'a' * CaseInput.maxTitleLength).title.length, 80);
    expect(
      () => input(title: 'a' * (CaseInput.maxTitleLength + 1)),
      throwsFormatException,
    );
  });

  test('notes are optional and bounded', () {
    expect(input().notes, isEmpty);
    expect(input(notes: 'a' * CaseInput.maxNotesLength).notes.length, 2000);
    expect(
      () => input(notes: 'a' * (CaseInput.maxNotesLength + 1)),
      throwsFormatException,
    );
  });

  for (final grapheme in ['🔒', 'e\u0301', '👩🏽‍💻']) {
    test('title counts $grapheme as one visible character', () {
      final title = grapheme * CaseInput.maxTitleLength;
      expect(input(title: title).title.characters.length, 80);
      expect(input(title: title).title, title);
      expect(() => input(title: '$title$grapheme'), throwsFormatException);
    });
  }

  for (final grapheme in ['🔒', 'e\u0301']) {
    test('notes accept 2000 $grapheme graphemes and reject 2001', () {
      final notes = grapheme * CaseInput.maxNotesLength;
      expect(input(notes: notes).notes.characters.length, 2000);
      expect(input(notes: notes).notes, notes);
      expect(() => input(notes: '$notes$grapheme'), throwsFormatException);
    });
  }

  test(
    'a huge grapheme cluster reports data size, not the character limit',
    () {
      final hugeCluster = 'a${'\u0301' * 20000}';
      expect(hugeCluster.characters.length, 1);
      final sizeError = throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'size message',
          'El texto es demasiado grande para guardarlo en el dispositivo.',
        ),
      );
      expect(() => input(title: hugeCluster), sizeError);
      expect(() => input(notes: hugeCluster), sizeError);
    },
  );

  test('factory validates source links even without a form', () {
    expect(
      () => CaseInput(
        title: 'Caso',
        sourceUrl: 'https://user:password@example.com/private',
        category: CaseCategory.other,
      ),
      throwsFormatException,
    );
  });

  test('validation errors never echo rejected data', () {
    const privateMarker = 'do-not-echo-this';
    try {
      input(title: privateMarker * 10);
      fail('Expected invalid input');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains(privateMarker)));
      expect(error.source, isNull);
    }
  });
}
