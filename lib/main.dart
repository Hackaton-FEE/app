import 'package:flutter/widgets.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const FeeApp(
      testingAccessEnabled: bool.fromEnvironment(
        'FEE_TESTING_ACCESS',
        defaultValue: true,
      ),
    ),
  );
}
