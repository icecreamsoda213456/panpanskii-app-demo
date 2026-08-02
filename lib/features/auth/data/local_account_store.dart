import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase.dart';

enum AccountMascot {
  panda('Panda'),
  koala('Koala');

  const AccountMascot(this.label);

  final String label;

  static AccountMascot fromName(String name) {
    return AccountMascot.values.firstWhere(
      (mascot) => mascot.name == name,
      orElse: () => AccountMascot.panda,
    );
  }
}

class LocalAccount {
  const LocalAccount({
    required this.username,
    required this.mascot,
    required this.isBiometricEnabled,
  });

  final String username;
  final AccountMascot mascot;
  final bool isBiometricEnabled;
}

class LocalAccountStore {
  static const _usernameKey = 'account_username';
  static const _mascotKey = 'account_mascot';
  static const _biometricEnabledKey = 'account_biometric_enabled';

  Future<LocalAccount?> loadAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    final preferences = await SharedPreferences.getInstance();
    final profile = await supabase
        .from('profiles')
        .select('username, avatar')
        .eq('id', user.id)
        .maybeSingle();

    final username = profile?['username'] as String? ??
        preferences.getString(_usernameKey) ??
        user.email?.split('@').first ??
        'panpanskii';
    final mascotName = profile?['avatar'] as String? ??
        preferences.getString(_mascotKey) ??
        AccountMascot.panda.name;

    return LocalAccount(
      username: username,
      mascot: AccountMascot.fromName(mascotName),
      isBiometricEnabled: preferences.getBool(_biometricEnabledKey) ?? false,
    );
  }

  Future<void> createAccount({
    required String username,
    required String password,
    required AccountMascot mascot,
    required bool enableBiometric,
  }) async {
    final cleanUsername = username.trim();
    final email = _usernameToEmail(cleanUsername);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': cleanUsername,
          'avatar': mascot.name,
        },
      );
      final user = response.user;
      if (user == null) {
        throw Exception('Hindi nagawa ang Supabase account.');
      }
      if (response.session == null) {
        throw Exception(
          'Naka-on ang email confirmation sa Supabase. I-off muna ito sa Auth settings kung username/password lang ang gusto mo.',
        );
      }

      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': cleanUsername,
        'avatar': mascot.name,
      });
    } on AuthException catch (error) {
      throw Exception(error.message);
    } on PostgrestException catch (error) {
      throw Exception(
        'Hindi maisulat sa profiles table. Check RLS policies. ${error.message}',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_usernameKey, cleanUsername);
    await preferences.setString(_mascotKey, mascot.name);
    await preferences.setBool(_biometricEnabledKey, enableBiometric);
  }

  Future<bool> verifyLogin({
    required String username,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _usernameToEmail(username.trim()),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return false;
      }

      final account = await loadAccount();
      final preferences = await SharedPreferences.getInstance();
      if (account != null) {
        await preferences.setString(_usernameKey, account.username);
        await preferences.setString(_mascotKey, account.mascot.name);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool isEnabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_biometricEnabledKey, isEnabled);
  }

  String _usernameToEmail(String username) {
    final normalized = username.trim().toLowerCase();
    return '$normalized@panpanskii.app';
  }
}
