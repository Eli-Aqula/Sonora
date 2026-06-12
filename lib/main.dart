import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' if (dart.library.js) 'package:sonora/providers/player_provider_mobile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/core_providers.dart';
import 'providers/genius_provider.dart';
import 'providers/library_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/player_state_restorer.dart';
import 'providers/playlist_provider.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/app_shell_mobile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sqflite on desktop only works via FFI: Windows/Linux/macOS have no
  // built-in native driver, so we explicitly initialize sqflite_common_ffi
  // and swap in databaseFactoryFfi — otherwise any openDatabase() throws
  // "Bad state: databaseFactory not initialized".
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    // MediaKit might fail on some platforms
  }
  runApp(const ProviderScope(child: SonoraApp()));
}

class SonoraApp extends ConsumerStatefulWidget {
  const SonoraApp({super.key});

  @override
  ConsumerState<SonoraApp> createState() => _SonoraAppState();
}

class _SonoraAppState extends ConsumerState<SonoraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(playerServiceProvider).init();
      ref.read(playlistsProvider);
      // Eagerly load the Genius token from SharedPreferences. Without
      // this, the StateNotifier isn't created until the first
      // `ref.watch`, and the "Find on Genius" menu item won't appear
      // until the user opens Settings.
      ref.read(geniusTokenProvider);
      ref.read(geniusAutoEnrichProvider);
      await ref.read(playerStateRestorerProvider).tryRestore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      ref.read(playerServiceProvider).flushState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 720;
    return MaterialApp(
      title: 'Sonora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: ref.watch(localeProvider),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _SmoothScrollBehavior(),
      home: Builder(
        builder: (context) {
          // On first build, show what we have - let MobileAppShell handle empty state
          final lib = ref.watch(libraryControllerProvider);
          if (lib.loading && lib.tracks.isEmpty) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return isDesktop ? const AppShell() : const MobileAppShell();
        },
      ),
    );
  }
}

class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.normal,
    );
  }
}
