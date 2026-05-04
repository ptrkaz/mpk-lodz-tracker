import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpk_lodz_tracker/ui/core/app_lifecycle_notifier.dart';

void main() {
  testWidgets('notifies on lifecycle change', (tester) async {
    final n = AppLifecycleNotifier()..attach();
    addTearDown(n.detach);
    var fired = 0;
    n.addListener(() => fired++);

    n.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(n.state, AppLifecycleState.paused);
    expect(fired, 1);

    n.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(n.state, AppLifecycleState.resumed);
    expect(fired, 2);
  });

  test('attach is idempotent', () {
    final n = AppLifecycleNotifier();
    n.attach();
    n.attach(); // second call is no-op
    n.detach();
  });
}
