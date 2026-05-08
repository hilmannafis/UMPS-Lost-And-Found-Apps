import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/item.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/user_providers.dart';
import '../../core/repositories/item_repository.dart';
import '../../core/widgets/web_compatible_image.dart';

class AdminItemsPage extends ConsumerWidget {
  const AdminItemsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get all items (both lost and found, regardless of status) - for admin view
    final allLostItems = ref.watch(allItemsForAdminProvider(ItemType.lost));
    final allFoundItems = ref.watch(allItemsForAdminProvider(ItemType.found));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Items', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF00857A),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF00857A),
              tabs: [
                Tab(text: 'All Items', icon: Icon(Icons.grid_view)),
                Tab(text: 'Lost Items', icon: Icon(Icons.shopping_bag)),
                Tab(text: 'Found Items', icon: Icon(Icons.handshake)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // All Items Tab
                  _AllItemsTab(),
                  // Lost Items Tab
                  _ItemsListTab(
                    itemsAsync: allLostItems,
                    type: ItemType.lost,
                  ),
                  // Found Items Tab
                  _ItemsListTab(
                    itemsAsync: allFoundItems,
                    type: ItemType.found,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllItemsTab extends ConsumerWidget {
  const _AllItemsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allLostItems = ref.watch(allItemsForAdminProvider(ItemType.lost));
    final allFoundItems = ref.watch(allItemsForAdminProvider(ItemType.found));

    return allLostItems.when(
      data: (lostItems) => allFoundItems.when(
        data: (foundItems) {
          // Combine all items and sort by creation date
          final allItems = [...lostItems, ...foundItems];
          allItems.sort((a, b) {
            final dateA = a.createdAt ?? DateTime(0);
            final dateB = b.createdAt ?? DateTime(0);
            return dateB.compareTo(dateA);
          });

          if (allItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Items Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items posted by users will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: allItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = allItems[index];
              return _ItemCard(item: item);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ItemsListTab extends ConsumerWidget {
  const _ItemsListTab({required this.itemsAsync, required this.type});

  final AsyncValue<List<Item>> itemsAsync;
  final ItemType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == ItemType.lost ? Icons.shopping_bag : Icons.handshake,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${type == ItemType.lost ? 'Lost' : 'Found'} Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${type == ItemType.lost ? 'Lost' : 'Found'} items will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ItemCard(item: item);
            },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item});

  final Item item;

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Item item) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Item', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this item?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Posted by: ${item.ownerId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteItem(context, ref, item);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, Item item) async {
    try {
      final repository = ref.read(itemRepositoryProvider);
      await repository.delete(item.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Item "${item.title}" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting item: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfile = ref.watch(userProfileProvider(item.ownerId));
    final ownerName = ownerProfile.maybeWhen(
      data: (profile) => profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim().isNotEmpty
              ? '${profile.firstName} ${profile.lastName}'.trim()
              : profile.username
          : item.ownerId,
      orElse: () => item.ownerId,
    );

    final isClaimed = item.status == ItemStatus.claimed || item.claimedBy != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.go('/home/items/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: item.photos.isNotEmpty && item.photos.first.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: WebCompatibleImage(
                            imageUrl: item.photos.first,
                            height: 180,
                            fit: BoxFit.cover,
                            errorWidget: const Icon(Icons.image_not_supported, size: 48),
                          ),
                        )
                      : const Icon(Icons.image, size: 48, color: Colors.grey),
                ),
                // Status badges
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.type == ItemType.lost 
                          ? Colors.orange 
                          : const Color(0xFF00857A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.type == ItemType.lost ? 'LOST' : 'FOUND',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (isClaimed)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CLAIMED',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ownerName,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(item.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      if (item.towerNumber.isNotEmpty || item.roomNumber.isNotEmpty) ...[
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'T${item.towerNumber}-R${item.roomNumber}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => context.go('/home/items/${item.id}'),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00857A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showDeleteDialog(context, ref, item),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

