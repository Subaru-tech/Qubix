import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/utils/api_client.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/auth/server_config_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/chat/chat_list_screen.dart';
import '../presentation/screens/chat/chat_thread_screen.dart';
import '../presentation/screens/agents/agent_list_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';

/// Route name constants.
class Routes {
  Routes._();
  static const String splash = '/';
  static const String serverConfig = '/server-config';
  static const String login = '/login';
  static const String register = '/register';
  static const String chatList = '/chats';
  static const String chatThread = '/chats/:threadId';
  static const String agents = '/agents';
  static const String settings = '/settings';
}

/// GoRouter provider — depends on auth state.
final routerProvider = Provider<GoRouter>((ref) {
  final token = ref.watch(authTokenProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = token != null && token.isNotEmpty;
      final isAuthRoute = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register ||
          state.matchedLocation == Routes.serverConfig ||
          state.matchedLocation == Routes.splash;

      // If not authenticated and trying to access protected route → login
      if (!isAuthenticated && !isAuthRoute) {
        return Routes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.serverConfig,
        builder: (context, state) => const ServerConfigScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.chatList,
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: Routes.chatThread,
        builder: (context, state) {
          final threadId = state.pathParameters['threadId']!;
          return ChatThreadScreen(threadId: threadId);
        },
      ),
      GoRoute(
        path: Routes.agents,
        builder: (context, state) => const AgentListScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
