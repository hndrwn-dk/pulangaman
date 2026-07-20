import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/features/parent/kabar_models.dart';

void main() {
  ChildKabarMessage msg({
    required String id,
    required String childId,
    required String name,
    required DateTime at,
    String? preset,
  }) {
    return ChildKabarMessage(
      id: id,
      childId: childId,
      childName: name,
      text: 't',
      preset: preset,
      sentAt: at,
    );
  }

  test('latestKabarPerChild keeps one newest per child, urgent first', () {
    final now = DateTime(2026, 7, 20, 12);
    final list = latestKabarPerChild([
      msg(id: '1', childId: 'a', name: 'Andi', at: now.subtract(const Duration(hours: 2))),
      msg(id: '2', childId: 'a', name: 'Andi', at: now.subtract(const Duration(minutes: 5))),
      msg(
        id: '3',
        childId: 'b',
        name: 'Budi',
        at: now.subtract(const Duration(minutes: 10)),
        preset: 'need_help',
      ),
      msg(id: '4', childId: 'b', name: 'Budi', at: now.subtract(const Duration(hours: 1))),
    ]);

    expect(list.length, 2);
    expect(list.first.childId, 'b');
    expect(list.first.isUrgent, true);
    expect(list.first.id, '3');
    expect(list.last.childId, 'a');
    expect(list.last.id, '2');
  });
}
