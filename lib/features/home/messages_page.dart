import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_notification.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/providers/message_providers.dart';
import '../../core/providers/user_providers.dart';
import '../../core/providers/item_providers.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final authUser = ref.watch(authStateProvider);
    final chats = profile != null ? ref.watch(userChatsProvider(profile.id)) : const AsyncValue.data(<Map<String, dynamic>>[]);
    
    // Wait for auth state and profile to be loaded
    if (profile == null || authUser.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Only query if user is authenticated
    final userId = authUser.value?.uid;
    if (userId == null || userId != profile.id) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view messages')),
      );
    }

    final notifications = ref.watch(notificationsProvider(profile.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inbox_outlined, size: 20), text: 'All'),
            Tab(icon: Icon(Icons.assignment_outlined, size: 20), text: 'Claims'),
            Tab(icon: Icon(Icons.chat_bubble_outline, size: 20), text: 'Chat'),
          ],
        ),
      ),
      body: notifications.when(
        data: (allNotifications) {
          final claimNotifications = allNotifications.where((n) => n.type == 'claim_request' || n.type == 'claim_response').toList();

          return TabBarView(
            controller: _tab,
            children: [
              _buildList(context, ref, allNotifications, profile.id),
              _buildList(context, ref, claimNotifications, profile.id),
              _buildChatList(context, ref, chats, profile.id),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, 1),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<AppNotification> notifications, String userId) {
    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re all caught up!',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationCard(
          notification: notification,
          onTap: () => _handleNotificationTap(context, ref, notification, userId),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: notifications.length,
    );
  }

  Widget _buildChatList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Map<String, dynamic>>> chats,
    String currentUserId,
  ) {
    return chats.when(
      data: (chatList) {
        if (chatList.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No chats yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation from an item or claim',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chatList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final chat = chatList[index];
            final participants = (chat['participants'] as List).cast<String>();
            final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
            final itemId = chat['itemId'] as String? ?? '';
            final lastMessage = chat['lastMessage'] as String? ?? '';
            final lastMessageAt = chat['lastMessageAt'] as DateTime?;

            final otherUser = otherUserId.isNotEmpty ? ref.watch(userProfileProvider(otherUserId)) : const AsyncValue.data(null);
            final item = itemId.isNotEmpty ? ref.watch(itemStreamProvider(itemId)) : const AsyncValue.data(null);

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (otherUserId.isNotEmpty && itemId.isNotEmpty) {
                    context.push('/home/chat/$otherUserId/$itemId');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00857A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00857A), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: otherUser.when(
                                    data: (user) => Text(
                                      user != null
                                          ? '${user.firstName} ${user.lastName}'.trim().isNotEmpty
                                              ? '${user.firstName} ${user.lastName}'
                                              : 'User'
                                          : 'User',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    loading: () => Container(height: 14, width: 80, color: Colors.grey.shade200),
                                    error: (_, __) => const Text('User'),
                                  ),
                                ),
                                if (lastMessageAt != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimeShort(lastMessageAt),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            item.when(
                              data: (itemData) => Text(
                                itemData?.title ?? 'Item',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              loading: () => Container(height: 12, width: 100, color: Colors.grey.shade200),
                              error: (_, __) => const Text('Item'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lastMessage.isEmpty ? 'Tap to open chat' : lastMessage,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    String userId,
  ) async {
    // Mark as read
    if (!notification.read) {
      await ref.read(notificationRepositoryProvider).markRead(
            userId: userId,
            notificationId: notification.id,
          );
    }

    // Navigate based on notification type
    if (notification.type == 'claim_request') {
      // Navigate to claim review page
      context.push('/home/claims/${notification.refId}/review');
    } else if (notification.type == 'claim_response') {
      // Navigate to item detail or claim detail
      if (notification.itemId != null) {
        context.push('/home/items/${notification.itemId}');
      }
    } else if (notification.type == 'message') {
      // Navigate to chat page
      // refId contains the senderId, itemId contains the itemId
      if (notification.itemId != null && notification.refId.isNotEmpty) {
        context.push('/home/chat/${notification.refId}/${notification.itemId}');
      }
    } else {
      // Show notification details
      _showNotificationDetails(context, notification);
    }
  }

  String _formatTimeShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('dd MMM').format(dateTime);
    }
  }

  void _showNotificationDetails(BuildContext context, AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(notification.body),
            const SizedBox(height: 12),
            if (notification.createdAt != null)
              Text(
                'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(notification.createdAt!)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, int currentIndex) {
    final profile = ref.watch(authControllerProvider).profile;
    final unreadCount = profile != null 
        ? ref.watch(unreadNotificationsProvider(profile.id))
        : const AsyncValue.data(0);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            // Already on messages
            break;
          case 2:
            context.go('/home/my-posts');
            break;
          case 3:
            context.go('/home/account');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF00857A),
      unselectedItemColor: Colors.grey,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: unreadCount.when(
            data: (count) => count > 0
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.mail_outline),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: count > 9 
                              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                              : const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: count > 9
                              ? const Text(
                                  '9+',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              : count > 0
                                  ? Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : null,
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.mail_outline),
            loading: () => const Icon(Icons.mail_outline),
            error: (_, __) => const Icon(Icons.mail_outline),
          ),
          label: 'Message',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'My Post',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String tag;

    switch (notification.type) {
      case 'claim_request':
        icon = Icons.assignment;
        iconColor = Colors.orange;
        tag = 'Claim Request';
        break;
      case 'claim_response':
        icon = Icons.check_circle;
        iconColor = notification.title.contains('Approved') ? Colors.green : Colors.red;
        tag = 'Claim Response';
        break;
      default:
        icon = Icons.notifications;
        iconColor = const Color(0xFF00857A);
        tag = 'System';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notification.read ? Colors.grey.shade200 : Colors.blue.shade200,
          width: notification.read ? 1 : 2,
        ),
      ),
      color: notification.read ? Colors.white : Colors.blue.shade50,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  if (!notification.read)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.read ? FontWeight.w500 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (notification.createdAt != null)
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(notification.createdAt!),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd MMM').format(dateTime);
    }
  }

  String _formatTimeShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m';
      }
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return '1d';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('dd MMM').format(dateTime);
    }
  }
}
