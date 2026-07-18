import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulangaman/app.dart';
import 'package:pulangaman/core/strings.dart';

void main() {
  testWidgets('home shows PulangAman brand', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PulangAmanApp()));
    expect(find.text(AppStrings.brand), findsOneWidget);
    expect(find.text(AppStrings.roleParent), findsOneWidget);
  });
}
