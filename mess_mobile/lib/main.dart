import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'platform/record_web_init_stub.dart'
    if (dart.library.html) 'platform/record_web_init_web.dart';
import 'repositories/mess_repository.dart';
import 'services/local_notification_service.dart';
import 'session_gate.dart';
import 'theme/app_theme.dart';
import 'widgets/app_update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initRecordWeb();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationService.instance.init();

  final repo = MessRepository();

  runApp(
    Provider<MessRepository>.value(
      value: repo,
      child: const AlphaMessMobileApp(),
    ),
  );
}

class AlphaMessMobileApp extends StatelessWidget {
  const AlphaMessMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<MessRepository>();

    return MaterialApp(
      title: 'Alpha Mess',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppUpdateGate(
        child: SessionGate(repo: repo),
      ),
    );
  }
}
