import 'package:go_router/go_router.dart';
import 'package:magent_app/app/root_shell.dart';
import 'package:magent_app/features/agents/connect/agent_connect_page.dart';
import 'package:magent_app/features/agents/edit/agent_edit_page.dart';
import 'package:magent_app/features/agents/list/agent_list_page.dart';
import 'package:magent_app/features/projects/list/project_list_page.dart';
import 'package:magent_app/features/projects/detail/project_detail_page.dart';
import 'package:magent_app/features/sessions/create/session_create_page.dart';
import 'package:magent_app/features/sessions/chat/chat_page.dart';
import 'package:magent_app/features/git/manage/git_manage_page.dart';
import 'package:magent_app/features/settings/settings_page.dart';
import 'package:magent_app/features/settings/cache_settings_page.dart';
import 'package:magent_app/features/settings/providers_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/projects'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          RootShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/projects',
              builder: (context, state) => const ProjectListPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/agents',
              builder: (context, state) => const AgentListPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/agents/connect',
      builder: (context, state) => const AgentConnectPage(),
    ),
    GoRoute(
      path: '/agents/edit/:agentId',
      builder: (context, state) =>
          AgentEditPage(agentId: state.pathParameters['agentId']!),
    ),
    GoRoute(
      path: '/projects/:id',
      builder: (context, state) =>
          ProjectDetailPage(projectId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'sessions/create',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return SessionCreatePage(
              projectId: state.pathParameters['id']!,
              provider: extra['provider'] as String? ?? '',
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/sessions/:id',
      builder: (context, state) =>
          ChatPage(sessionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/git/manage',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return GitManagePage(projectId: extra['projectId'] ?? '');
      },
    ),
    GoRoute(
      path: '/settings/providers',
      builder: (context, state) => const ProvidersPage(),
    ),
    GoRoute(
      path: '/settings/cache',
      builder: (context, state) => const CacheSettingsPage(),
    ),
  ],
);
