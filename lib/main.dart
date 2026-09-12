import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'app/app.dart';
import 'core/demo/demo_store.dart';
import 'demo_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isPortfolioDemo) {
    await DemoStore.instance.initialize();
    // Enable web semantics after the navigator has completed its first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsBinding.instance.ensureSemantics();
    });
  }

  runApp(const PanpanskiiApp());
}
