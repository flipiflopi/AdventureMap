// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

// 🌍 Localización - Estos imports son vitales
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'firebase_options.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/map/presentation/home_screen.dart';
import 'features/favorites/presentation/shared_folder_screen.dart';
import 'services/deep_link_service.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'providers/providers.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';

// Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📨 Notificación en background: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración de Mapbox
  MapboxOptions.setAccessToken(
      const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
  );

  // Inicialización de Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: AdventureMapApp(),
    ),
  );
}

class AdventureMapApp extends ConsumerStatefulWidget {
  const AdventureMapApp({Key? key}) : super(key: key);

  @override
  ConsumerState<AdventureMapApp> createState() => _AdventureMapAppState();
}

class _AdventureMapAppState extends ConsumerState<AdventureMapApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _deepLinkSubscription;
  final NotificationService _notificationService = NotificationService();
  

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initNotifications();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    ref.listenManual(currentUserProvider, (previous, next) async {
      if (next != null) {
        await _notificationService.initialize(
          next.uid,
          navigatorKey: navigatorKey,
        );
        await FirebaseMessaging.instance.subscribeToTopic('global_notifications');
      }
    });

    final user = ref.read(currentUserProvider);
    if (user != null) {
      await _notificationService.initialize(
        user.uid,
        navigatorKey: navigatorKey,
      );
      await FirebaseMessaging.instance.subscribeToTopic('global_notifications');
    }
  }

  Future<void> _initDeepLinks() async {
    final deepLinkService = DeepLinkService();
    try {
      final initialLink = await deepLinkService.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    _deepLinkSubscription = deepLinkService.deepLinkStream.listen(
      (link) => _handleDeepLink(link),
      onError: (error) => debugPrint('Deep link error: $error'),
    );
  }

  void _handleDeepLink(String link) {
    final folderId = DeepLinkService.extractFolderIdFromLink(link);
    if (folderId != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => SharedFolderScreen(folderId: folderId),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      locale: locale,
      title: 'AdventureMap',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      
      // CONFIGURACIÓN DE LOCALIZACIÓN ARREGLADA
      localizationsDelegates: const [
        AppLocalizations.delegate, 
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'), // Español
        Locale('en'), // Inglés
        Locale('it'), // Italiano
        Locale('de'), // Alemán
      ],

      themeMode: themeMode,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}