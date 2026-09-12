import 'package:supabase_flutter/supabase_flutter.dart';
import '../../demo_config.dart';
import '../demo/demo_store.dart';

export '../../demo_config.dart';
export '../demo/demo_store.dart';

SupabaseClient get supabase => Supabase.instance.client;
DemoStore get demo => DemoStore.instance;
String? get portfolioUserId =>
    isPortfolioDemo ? DemoStore.userId : supabase.auth.currentUser?.id;
