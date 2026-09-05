import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../demo_config.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/presentation/pan_ui.dart';
import '../core/supabase/supabase.dart';
import '../features/auth/data/local_account_store.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/bible/data/daily_bible_notification_service.dart';
import '../features/bible/presentation/screens/bible_verses_screen.dart';
import '../features/chat/presentation/screens/private_chat_screen.dart';
import '../features/dates/data/couple_date_notification_service.dart';
import '../features/dates/presentation/screens/couple_dates_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/more_screen.dart';
import '../features/journal/presentation/screens/shared_journal_screen.dart';
import '../features/mini_game/presentation/screens/daily_duo_screen.dart';
import '../features/mini_game/presentation/screens/cozy_garden_screen.dart';
import '../features/magnetic_hearts/presentation/screens/magnetic_hearts_screen.dart';
import '../features/mood/presentation/screens/mood_status_screen.dart';
import '../features/question/presentation/screens/daily_question_screen.dart';
import '../features/reminders/presentation/screens/reminders_screen.dart';
import '../features/send_love/presentation/screens/love_letters_screen.dart';
import '../features/thoughts/presentation/screens/write_thoughts_screen.dart';
import '../features/widget_notes/presentation/screens/widget_note_canvas_screen.dart';
import '../features/widget_notes/presentation/screens/widget_note_diagnostics_screen.dart';
import '../features/wisdom/presentation/screens/communal_wisdom_screen.dart';
import '../features/photobooth/presentation/screens/photobooth_screen.dart';
import '../features/photobooth/presentation/screens/photobooth_gallery_screen.dart';

class PanpanskiiApp extends StatefulWidget {
  const PanpanskiiApp({super.key});

  @override
  State<PanpanskiiApp> createState() => _PanpanskiiAppState();
}

class _PanpanskiiAppState extends State<PanpanskiiApp>
    with WidgetsBindingObserver {
  static const _themeModeKey = 'panpanskii_theme_mode';
  static const _backgroundLockGracePeriod = Duration(minutes: 2);

  final _accountStore = LocalAccountStore();
  final _localAuthentication = LocalAuthentication();
  Timer? _backgroundLockTimer;
  DateTime? _backgroundedAt;
  ThemeMode _themeMode = ThemeMode.light;
  LocalAccount? _account;
  RealtimeChannel? _realtimeNotificationChannel;
  RealtimeChannel? _dateNotificationChannel;
  DateTime? _lastMoodNotificationAt;
  bool _isLoadingAccount = true;
  bool _isUnlocked = false;

  bool get _isDarkMode => _themeMode == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
    _loadAccount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearBackgroundLockState();
    _stopRealtimeNotifications();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeFromBackground();
      return;
    }

    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _startBackgroundLockCountdown();
    }
  }

  void _startBackgroundLockCountdown() {
    if (_account == null || !_isUnlocked || _backgroundedAt != null) {
      return;
    }

    _backgroundedAt = DateTime.now();
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = Timer(_backgroundLockGracePeriod, () {
      if (!mounted || _backgroundedAt == null || !_isUnlocked) {
        return;
      }
      _backgroundLockTimer = null;
      setState(() => _isUnlocked = false);
    });
  }

  void _resumeFromBackground() {
    final backgroundedAt = _backgroundedAt;
    _clearBackgroundLockState();

    if (backgroundedAt == null || _account == null || !_isUnlocked) {
      return;
    }

    if (DateTime.now().difference(backgroundedAt) >=
        _backgroundLockGracePeriod) {
      setState(() => _isUnlocked = false);
    }
  }

  void _clearBackgroundLockState() {
    _backgroundLockTimer?.cancel();
    _backgroundLockTimer = null;
    _backgroundedAt = null;
  }

  Future<void> _loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final savedMode = preferences.getString(_themeModeKey);
    if (!mounted || savedMode == null) {
      return;
    }
    setState(() {
      _themeMode = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final nextMode = _isDarkMode ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themeModeKey,
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> _loadAccount() async {
    if (isPortfolioDemo) {
      _clearBackgroundLockState();
      setState(() {
        _account = const LocalAccount(
          username: 'Guest Owner',
          mascot: AccountMascot.panda,
          isBiometricEnabled: false,
        );
        _isUnlocked = true;
        _isLoadingAccount = false;
      });
      return;
    }

    final account = await _accountStore.loadAccount();
    if (!mounted) {
      return;
    }
    _clearBackgroundLockState();
    setState(() {
      _account = account;
      _isUnlocked = false;
      _isLoadingAccount = false;
    });
  }

  Future<void> _createAccount({
    required String username,
    required String password,
    required AccountMascot mascot,
    required bool enableBiometric,
  }) async {
    await _accountStore.createAccount(
      username: username,
      password: password,
      mascot: mascot,
      enableBiometric: enableBiometric,
    );
    if (enableBiometric) {
      final didAuthenticate = await _authenticateWithBiometrics();
      await _accountStore.setBiometricEnabled(didAuthenticate);
    }
    final account = await _accountStore.loadAccount();
    if (!mounted) {
      return;
    }
    _clearBackgroundLockState();
    setState(() {
      _account = account;
      _isUnlocked = true;
    });
    if (account != null) {
      _startRealtimeNotifications(account);
    }
  }

  Future<bool> _login({
    required String username,
    required String password,
  }) async {
    final success = await _accountStore.verifyLogin(
      username: username,
      password: password,
    );
    if (success && mounted) {
      var account = _account ?? await _accountStore.loadAccount();
      if (account != null && !account.isBiometricEnabled) {
        final didAuthenticate = await _authenticateWithBiometrics();
        if (didAuthenticate) {
          await _accountStore.setBiometricEnabled(true);
          account = await _accountStore.loadAccount() ?? account;
        }
      }
      _clearBackgroundLockState();
      setState(() {
        _account = account ?? _account;
        _isUnlocked = true;
      });
      if (account != null) {
        _startRealtimeNotifications(account);
      }
    }
    return success;
  }

  Future<bool> _loginWithBiometric() async {
    final account = _account;
    if (account == null || !account.isBiometricEnabled) {
      return false;
    }
    final didAuthenticate = await _authenticateWithBiometrics();
    if (didAuthenticate && mounted) {
      _clearBackgroundLockState();
      setState(() => _isUnlocked = true);
      _startRealtimeNotifications(account);
    }
    return didAuthenticate;
  }

  void _startRealtimeNotifications(LocalAccount account) {
    if (isPortfolioDemo) {
      return;
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    unawaited(CoupleDateNotificationService.syncUpcomingPlans());
    if (_realtimeNotificationChannel == null) {
      PushNotificationService.registerDevice(account);

      _realtimeNotificationChannel = supabase
          .channel('panpanskii-realtime-notifications-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'private_chat_messages',
            callback: (payload) => _notifyFromRealtimePayload(
              payload: payload,
              currentUserId: userId,
              fallbackUsername: account.username,
              title: 'New private chat',
              bodyBuilder: (username, row) {
                final message = row['message']?.toString().trim() ?? '';
                return message.isEmpty
                    ? '$username sent a message.'
                    : '$username: ${_clipNotificationText(message)}';
              },
            ),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'send_love_letters',
            callback: (payload) => _notifyFromRealtimePayload(
              payload: payload,
              currentUserId: userId,
              fallbackUsername: account.username,
              title: 'New love letter',
              bodyBuilder: (username, row) {
                final hasAttachment =
                    (row['attachment_path']?.toString().isNotEmpty ?? false);
                return hasAttachment
                    ? '$username sent love with a photo.'
                    : '$username sent a love letter.';
              },
            ),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'thought_posts',
            callback: (payload) => _notifyFromRealtimePayload(
              payload: payload,
              currentUserId: userId,
              fallbackUsername: account.username,
              title: 'New shared thought',
              bodyBuilder: (username, row) {
                final body = row['body']?.toString().trim() ?? '';
                return body.isEmpty
                    ? '$username posted a thought.'
                    : '$username: ${_clipNotificationText(body)}';
              },
            ),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'shared_journal_entries',
            callback: (payload) => _notifyFromRealtimePayload(
              payload: payload,
              currentUserId: userId,
              fallbackUsername: account.username,
              title: 'New journal entry',
              bodyBuilder: (username, row) {
                final title = row['title']?.toString().trim() ?? '';
                return title.isEmpty
                    ? '$username wrote tonight\'s diary.'
                    : '$username wrote "$title".';
              },
            ),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'mood_statuses',
            callback: (payload) => _notifyMoodStatus(
              payload: payload,
              currentUserId: userId,
            ),
          )
          .subscribe();
    }

    _dateNotificationChannel ??= supabase
        .channel('panpanskii-date-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'couple_dates',
          callback: (_) => unawaited(
            CoupleDateNotificationService.syncUpcomingPlans(),
          ),
        )
        .subscribe();
  }

  void _notifyMoodStatus({
    required PostgresChangePayload payload,
    required String currentUserId,
  }) {
    final row = payload.newRecord;
    if (row['user_id'] == currentUserId) {
      return;
    }

    final now = DateTime.now();
    final lastNotification = _lastMoodNotificationAt;
    if (lastNotification != null &&
        now.difference(lastNotification) < const Duration(minutes: 10)) {
      return;
    }
    _lastMoodNotificationAt = now;

    final username = row['username']?.toString().trim();
    final mood = row['mood']?.toString().trim();
    DailyBibleNotificationService.showRealtimeNotification(
      title: 'Mood update',
      body: username?.isNotEmpty == true && mood?.isNotEmpty == true
          ? '$username is feeling ${mood!.toLowerCase()}.'
          : 'Your person shared a new mood.',
      seed: 'mood_status'.hashCode ^ (username ?? '').hashCode,
    );
  }

  void _notifyFromRealtimePayload({
    required PostgresChangePayload payload,
    required String currentUserId,
    required String fallbackUsername,
    required String title,
    required String Function(String username, Map<String, dynamic> row)
        bodyBuilder,
  }) {
    final row = payload.newRecord;
    if (row['user_id'] == currentUserId) {
      return;
    }

    final usernameText = row['username']?.toString().trim();
    final username =
        usernameText?.isNotEmpty == true ? usernameText! : fallbackUsername;
    DailyBibleNotificationService.showRealtimeNotification(
      title: title,
      body: bodyBuilder(username, row),
      seed: title.hashCode ^ username.hashCode,
    );
  }

  String _clipNotificationText(String text) {
    const maxLength = 72;
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength).trim()}...';
  }

  void _stopRealtimeNotifications() {
    final channel = _realtimeNotificationChannel;
    if (channel != null) {
      _realtimeNotificationChannel = null;
      supabase.removeChannel(channel);
    }

    final dateChannel = _dateNotificationChannel;
    if (dateChannel != null) {
      _dateNotificationChannel = null;
      supabase.removeChannel(dateChannel);
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      final canAuthenticate = await _localAuthentication.canCheckBiometrics ||
          await _localAuthentication.isDeviceSupported();
      if (!canAuthenticate) {
        return false;
      }
      return _localAuthentication.authenticate(
        localizedReason:
            'Allow Panpanskii to use the fingerprint or face unlock saved on this phone.',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      redirect: (context, state) {
        if (_isLoadingAccount) {
          return null;
        }

        final isAuthRoute = state.matchedLocation == '/auth';
        if (!_isUnlocked && !isAuthRoute) {
          return '/auth';
        }
        if (_isUnlocked && isAuthRoute) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/auth',
          pageBuilder: (context, state) => _page(
            state,
            AuthScreen(
              account: _account,
              onCreateAccount: _createAccount,
              onLogin: _login,
              onBiometricLogin: _loginWithBiometric,
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _PrimaryNavigationShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  pageBuilder: (context, state) => _page(
                    state,
                    _isLoadingAccount
                        ? const _AppLoadingScreen()
                        : HomeScreen(
                            account: _account!,
                            isDarkMode: _isDarkMode,
                            onToggleTheme: _toggleTheme,
                          ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/private-chat',
                  pageBuilder: (context, state) =>
                      _page(state, PrivateChatScreen(account: _account!)),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cozy-garden',
                  pageBuilder: (context, state) =>
                      _page(state, CozyGardenScreen(account: _account!)),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  pageBuilder: (context, state) =>
                      _page(state, const MoreScreen()),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/love-letters',
          pageBuilder: (context, state) =>
              _page(state, LoveLettersScreen(account: _account!)),
        ),
        GoRoute(
          path: '/bible-verses',
          pageBuilder: (context, state) =>
              _page(state, const BibleVersesScreen()),
        ),
        GoRoute(
          path: '/wisdom',
          pageBuilder: (context, state) =>
              _page(state, const CommunalWisdomScreen()),
        ),
        GoRoute(
          path: '/shared-journal',
          pageBuilder: (context, state) =>
              _page(state, SharedJournalScreen(account: _account!)),
        ),
        GoRoute(
          path: '/mood-status',
          pageBuilder: (context, state) =>
              _page(state, MoodStatusScreen(account: _account!)),
        ),
        GoRoute(
          path: '/daily-question',
          pageBuilder: (context, state) =>
              _page(state, DailyQuestionScreen(account: _account!)),
        ),
        GoRoute(
          path: '/reminders',
          pageBuilder: (context, state) =>
              _page(state, const RemindersScreen()),
        ),
        GoRoute(
          path: '/dates',
          pageBuilder: (context, state) =>
              _page(state, CoupleDatesScreen(account: _account!)),
        ),
        GoRoute(
          path: '/panpans-home',
          pageBuilder: (context, state) =>
              _page(state, DailyDuoScreen(account: _account!)),
        ),
        GoRoute(
          path: '/magnetic-hearts',
          pageBuilder: (context, state) =>
              _page(state, MagneticHeartsScreen(account: _account!)),
        ),
        GoRoute(
          path: '/photobooth',
          pageBuilder: (context, state) =>
              _page(state, PhotoBoothScreen(account: _account!)),
        ),
        GoRoute(
          path: '/photobooth-gallery',
          pageBuilder: (context, state) =>
              _page(state, PhotoBoothGalleryScreen(account: _account!)),
        ),
        GoRoute(
          path: '/write-thoughts',
          pageBuilder: (context, state) =>
              _page(state, WriteThoughtsScreen(account: _account!)),
        ),
        GoRoute(
          path: '/widget-notes',
          pageBuilder: (context, state) =>
              _page(state, WidgetNoteCanvasScreen(account: _account!)),
        ),
        GoRoute(
          path: '/widget-notes-diagnostics',
          pageBuilder: (context, state) =>
              _page(state, const WidgetNoteDiagnosticsScreen()),
        ),
        for (final destination in _FeatureDestination.values.where(
          (destination) =>
              destination != _FeatureDestination.miniGame &&
              destination != _FeatureDestination.mood &&
              destination != _FeatureDestination.wisdom &&
              destination != _FeatureDestination.question &&
              destination != _FeatureDestination.reminders,
        ))
          GoRoute(
            path: destination.path,
            pageBuilder: (context, state) => _page(
              state,
              _FeaturePlaceholderScreen(destination: destination),
            ),
          ),
      ],
    );

    return MaterialApp.router(
      title: 'Panpanskii',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _PanpanskiiTheme.light(),
      darkTheme: _PanpanskiiTheme.dark(),
      routerConfig: router,
    );
  }

  CustomTransitionPage<void> _page(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.018),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.985,
                end: 1,
              ).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _PrimaryNavigationShell extends StatelessWidget {
  const _PrimaryNavigationShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_florist_outlined),
                selectedIcon: Icon(Icons.local_florist_rounded),
                label: 'Garden',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PanLoadingState(
        title: 'Opening Panpanskii',
        message: 'Getting your space ready.',
      ),
    );
  }
}

class _PanpanskiiTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFFF7888),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFDDE1),
    onPrimaryContainer: Color(0xFF4A151E),
    secondary: Color(0xFF9AD9B8),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD7F1E1),
    onSecondaryContainer: Color(0xFF123427),
    tertiary: Color(0xFFB8AEFF),
    onTertiary: Color(0xFF272052),
    tertiaryContainer: Color(0xFFE5E1FF),
    onTertiaryContainer: Color(0xFF322A68),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF7F4EE),
    onSurface: Color(0xFF25242A),
    surfaceContainerHighest: Color(0xFFFFFEFA),
    onSurfaceVariant: Color(0xFF4F4D56),
    outline: Color(0xFF77757E),
    outlineVariant: Color(0xFFC9C6CC),
    shadow: Color(0xFF25242A),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF25242A),
    onInverseSurface: Color(0xFFF7F4EE),
    inversePrimary: Color(0xFFFF5F72),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF8795),
    onPrimary: Color(0xFF48151F),
    primaryContainer: Color(0xFF6E2734),
    onPrimaryContainer: Color(0xFFFFDDE1),
    secondary: Color(0xFF9AD9B8),
    onSecondary: Color(0xFF123427),
    secondaryContainer: Color(0xFF24513C),
    onSecondaryContainer: Color(0xFFD7F1E1),
    tertiary: Color(0xFFB8AEFF),
    onTertiary: Color(0xFF272052),
    tertiaryContainer: Color(0xFF48417C),
    onTertiaryContainer: Color(0xFFE5E1FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF111318),
    onSurface: Color(0xFFF7F4EE),
    surfaceContainerHighest: Color(0xFF252A33),
    onSurfaceVariant: Color(0xFFB7BBC5),
    outline: Color(0xFF8B909B),
    outlineVariant: Color(0xFF444954),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF7F4EE),
    onInverseSurface: Color(0xFF111318),
    inversePrimary: Color(0xFFB73E52),
  );

  static ThemeData light() => _build(_lightScheme);

  static ThemeData dark() => _build(_darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final roundedText = GoogleFonts.nunitoTextTheme(base.textTheme);
    final pixelDisplay = GoogleFonts.pressStart2pTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.82),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: 0.96),
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          roundedText.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      textTheme: roundedText.copyWith(
        displayLarge: pixelDisplay.displayLarge?.copyWith(
          color: scheme.onSurface,
          height: 1.25,
          letterSpacing: 0,
        ),
        displayMedium: pixelDisplay.displayMedium?.copyWith(
          color: scheme.onSurface,
          height: 1.25,
          letterSpacing: 0,
        ),
        headlineSmall: pixelDisplay.headlineSmall?.copyWith(
          color: scheme.onSurface,
          height: 1.35,
          letterSpacing: 0,
        ),
        titleLarge: roundedText.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: scheme.onSurface,
        ),
        bodyLarge: roundedText.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
        bodyMedium: roundedText.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
        labelLarge: roundedText.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: roundedText.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: roundedText.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
        prefixIconColor: scheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: roundedText.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: roundedText.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: roundedText.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

enum _FeatureDestination {
  miniGame(
    '/panpans-home',
    'Mini Game',
    'A tiny playable corner is ready for the next build.',
  ),
  wisdom(
    '/wisdom',
    'Communal Wisdom',
    'Collected encouragement will live here.',
  ),
  reminders('/reminders', 'Reminders', 'Gentle reminders will land here.'),
  question(
    '/daily-question',
    'Daily Question',
    'One sweet question per day belongs here.',
  ),
  mood('/mood-status', 'Mood Status', 'Mood check-ins will bloom here.'),
  notifications(
    '/notifications',
    'Notifications',
    'Soft app notices will appear here.',
  );

  const _FeatureDestination(this.path, this.title, this.subtitle);

  final String path;
  final String title;
  final String subtitle;
}

class _FeaturePlaceholderScreen extends StatelessWidget {
  const _FeaturePlaceholderScreen({required this.destination});

  final _FeatureDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.primaryContainer,
              theme.colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Back home',
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const Spacer(),
                Text(destination.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 14),
                Text(destination.subtitle, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Back to garden'),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
