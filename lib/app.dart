import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'screens/more_screen.dart';
import 'screens/prayer_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/tasbih_screen.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'state/settings.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class AzkarApp extends StatelessWidget {
  const AzkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'أذكار المسلم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Respect system font scaling but keep layouts sane on very large settings.
        final mq = MediaQuery.of(context);
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Theme.of(context).colorScheme.surface,
          ),
          child: MediaQuery(
            data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
            child: child!,
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Lets other screens switch the bottom tab (e.g. "open tasbih").
  static final tab = ValueNotifier<int>(0);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    final n = NotificationService.instance.tappedPayload;
    n.addListener(_onPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPayload());
  }

  @override
  void dispose() {
    NotificationService.instance.tappedPayload.removeListener(_onPayload);
    super.dispose();
  }

  void _onPayload() {
    final payload = NotificationService.instance.tappedPayload.value;
    if (payload == null) return;
    NotificationService.instance.tappedPayload.value = null;
    final state = context.read<AppState>();
    if (payload.startsWith('cat:')) {
      final c = state.categoryByKey(payload.substring(4));
      if (c != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => ReaderScreen(category: c)));
      }
    } else if (payload.startsWith('zekr:')) {
      final id = int.tryParse(payload.substring(5));
      final z = state.allAzkar.where((e) => e.id == id).firstOrNull;
      if (z != null) {
        navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => ReaderScreen.single(zekr: z)));
      }
    } else if (payload == 'tasbih') {
      HomeShell.tab.value = 2;
    } else if (payload == 'prayer') {
      HomeShell.tab.value = 3;
    } else {
      HomeShell.tab.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: HomeShell.tab,
      builder: (context, index, _) => Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            CategoriesScreen(),
            TasbihScreen(),
            PrayerScreen(),
            MoreScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => HomeShell.tab.value = i,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'الأذكار'),
            NavigationDestination(
                icon: Icon(Icons.radio_button_checked_outlined),
                selectedIcon: Icon(Icons.radio_button_checked_rounded),
                label: 'المسبحة'),
            NavigationDestination(
                icon: Icon(Icons.access_time_outlined),
                selectedIcon: Icon(Icons.access_time_filled_rounded),
                label: 'المواقيت'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}
