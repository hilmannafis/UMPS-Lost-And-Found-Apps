import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models/user_profile.dart';
import 'core/providers/auth_controller.dart';
import 'core/repositories/auth_repository.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/admin/admin_register_student_page.dart';
import 'features/admin/firebase_test_page.dart';
import 'features/admin/create_admin_page.dart';
import 'features/admin/admin_users_page.dart';
import 'features/admin/admin_edit_user_page.dart';
import 'features/admin/admin_items_page.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/home/home_page.dart';
import 'features/items/report_item_page.dart';
import 'features/items/item_detail_page.dart';
import 'features/claims/claims_page.dart';
import 'features/claims/claim_form_page.dart';
import 'features/claims/claim_review_page.dart';
import 'features/home/my_posts_page.dart';
import 'features/home/account_page.dart';
import 'features/home/messages_page.dart';
import 'features/items/edit_item_page.dart';
import 'features/chat/chat_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final authUser = ref.watch(authStateProvider).value;
  final authStream = ref.watch(authRepositoryProvider).authState;

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final loggedIn = authUser != null || authState.profile != null;
      final isAdmin = authState.profile?.role == UserRole.admin;
      final isLoginPage = state.matchedLocation == '/login';
      final isRegisterPage = state.matchedLocation == '/register';
      
      if (!loggedIn && (isLoginPage || isRegisterPage)) {
        return null;
      }
      
      if (state.matchedLocation.startsWith('/admin') || state.matchedLocation.startsWith('/home')) {
        return null;
      }

      if (!loggedIn && !isLoginPage && !isRegisterPage) {
        return '/login';
      }
      
      if (loggedIn && (isLoginPage || isRegisterPage)) {
        return isAdmin ? '/admin' : '/home';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, _) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, _) => const RegisterPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, _) => const HomePage(),
        routes: [
          GoRoute(
            path: 'report',
            builder: (context, _) => const ReportItemPage(),
          ),
          GoRoute(
            path: 'items/:id',
            builder: (context, state) => ItemDetailPage(itemId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'claim',
                builder: (context, state) => ClaimFormPage(itemId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'claims',
            builder: (context, _) => const ClaimsPage(),
            routes: [
              GoRoute(
                path: ':id/review',
                builder: (context, state) => ClaimReviewPage(claimId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'my-posts',
            builder: (context, _) => const MyPostsPage(),
          ),
          GoRoute(
            path: 'items/:id/edit',
            builder: (context, state) => EditItemPage(itemId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'account',
            builder: (context, _) => const AccountPage(),
          ),
          GoRoute(
            path: 'messages',
            builder: (context, _) => const MessagesPage(),
          ),
          GoRoute(
            path: 'chat/:otherUserId/:itemId',
            builder: (context, state) => ChatPage(
              otherUserId: state.pathParameters['otherUserId']!,
              itemId: state.pathParameters['itemId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, _) => const AdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'register-student',
            builder: (context, _) => const AdminRegisterStudentPage(),
          ),
          GoRoute(
            path: 'firebase-test',
            builder: (context, _) => const FirebaseTestPage(),
          ),
          GoRoute(
            path: 'create-admin',
            builder: (context, _) => const CreateAdminPage(),
          ),
          GoRoute(
            path: 'items',
            builder: (context, _) => const AdminItemsPage(),
          ),
          GoRoute(
            path: 'users',
            builder: (context, _) => const AdminUsersPage(),
            routes: [
              GoRoute(
                path: ':userId/edit',
                builder: (context, state) => AdminEditUserPage(
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this.stream) {
    _sub = stream?.listen((_) => notifyListeners());
  }

  final Stream<dynamic>? stream;
  StreamSubscription<dynamic>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

