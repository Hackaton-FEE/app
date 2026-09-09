import 'package:fee_app/features/cases/data/in_memory_case_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'drafts can be removed independently and do not survive a new session',
    () {
      final repository = InMemoryCaseRepository();
      final first = repository.addDraft(Uri.parse('https://example.com/first'));
      final second = repository.addDraft(
        Uri.parse('https://example.com/second'),
      );

      expect(repository.drafts.map((draft) => draft.id), [second.id, first.id]);
      expect(() => repository.drafts.clear(), throwsUnsupportedError);
      repository.removeDraft(first.id);
      expect(repository.drafts.single.id, second.id);
      expect(InMemoryCaseRepository().drafts, isEmpty);
    },
  );
}
