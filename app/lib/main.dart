import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const OmwaSaccoApp());
}

class OmwaSaccoApp extends StatelessWidget {
  const OmwaSaccoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omwa Sacco',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const ConnectivityBanner(child: AppShell()),
    );
  }
}
