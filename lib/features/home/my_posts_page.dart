import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/claim.dart';
import '../../core/models/item.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/claim_providers.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/repositories/item_repository.dart';
import '../../core/widgets/web_compatible_image.dart';

class MyPostsPage extends ConsumerWidget {
  const MyPostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final authUser = ref.watch(authStateProvider);
    
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
        body: Center(child: Text('Please log in to view your posts')),
      );
    }

    final myItems = ref.watch(itemsByOwnerProvider(profile.id));
    final myClaims = ref.watch(claimsByUserProvider(profile.id));
    final myClaimedItems = ref.watch(claimedItemsByUserProvider(profile.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Posts', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.go('/home/report'),
            tooltip: 'Post lost/found item',
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(context, ref, 2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // My Items Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00857A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF00857A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('My Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              myItems.when(
                data: (data) {
                  // Filter out claimed items - only show unclaimed items in "My Items"
                  final unclaimedItems = data.where((item) {
                    final isClaimed = item.status == ItemStatus.claimed || item.claimedBy != null;
                    return !isClaimed;
                  }).toList();
                  
                  return unclaimedItems.isEmpty
                      ? Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No Items Posted',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start by posting a lost or found item',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.58,
                          ),
                          itemCount: unclaimedItems.length,
                          itemBuilder: (context, index) {
                            final item = unclaimedItems[index];
                            return _ItemCard(item: item, profileId: profile.id);
                          },
                        );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading items: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // My Claimed Items Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('My Claimed Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              // Combine items: items the user has claimed + items owned by user but claimed by others
              Builder(
                builder: (context) {
                  final myItemsAsync = ref.watch(itemsByOwnerProvider(profile.id));
                  final myClaimedItemsAsync = ref.watch(claimedItemsByUserProvider(profile.id));
                  
                  return myItemsAsync.when(
                    data: (allMyItems) {
                      // Get items owned by user that are claimed by someone else
                      final myClaimedByOthers = allMyItems.where((item) {
                        final isClaimed = item.status == ItemStatus.claimed || item.claimedBy != null;
                        return isClaimed && item.claimedBy != profile.id; // Claimed by someone else, not self
                      }).toList();
                      
                      // Now combine with items the user has claimed
                      return myClaimedItemsAsync.when(
                        data: (userClaimedItems) {
                          // Combine both lists and remove duplicates by item ID
                          final combinedList = <Item>[];
                          final itemIds = <String>{};
                          
                          // Add items owned by user that are claimed by others
                          for (final item in myClaimedByOthers) {
                            if (!itemIds.contains(item.id)) {
                              combinedList.add(item);
                              itemIds.add(item.id);
                            }
                          }
                          
                          // Add items the user has claimed
                          for (final item in userClaimedItems) {
                            if (!itemIds.contains(item.id)) {
                              combinedList.add(item);
                              itemIds.add(item.id);
                            }
                          }
                          
                          return combinedList.isEmpty
                              ? Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No Claimed Items',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Claimed items will appear here',
                                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.58,
                                  ),
                                  itemCount: combinedList.length,
                                  itemBuilder: (context, index) {
                                    final item = combinedList[index];
                                    return _ItemCard(item: item, profileId: profile.id);
                                  },
                                );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error loading claimed items: $e', style: const TextStyle(color: Colors.red)),
                          ),
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading items: $e', style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // My Claims Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_outlined, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('My Claims', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              // My Claims - show items as cards like My Items
              Builder(
                builder: (context) {
                  final myClaimsAsync = ref.watch(claimsByUserProvider(profile.id));
                  
                  return myClaimsAsync.when(
                    data: (claims) {
                      if (claims.isEmpty) {
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No Claims Submitted',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Claims you submit will appear here',
                                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      // Get unique item IDs from claims
                      final itemIds = claims.map((claim) => claim.itemId).toSet().toList();
                      
                      // Create a map of itemId to claim for quick lookup
                      final claimMap = {for (var claim in claims) claim.itemId: claim};
                      
                      // Fetch items using repository watchItem stream - get first value
                      return FutureBuilder<List<Item>>(
                        future: () async {
                          final repository = ref.read(itemRepositoryProvider);
                          final items = <Item>[];
                          final futures = itemIds.map((itemId) async {
                            try {
                              // Use watchItem stream and get first value
                              final item = await repository.watchItem(itemId).first;
                              return item;
                            } catch (e) {
                              return null;
                            }
                          });
                          final results = await Future.wait(futures);
                          items.addAll(results.whereType<Item>());
                          return items;
                        }(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final items = snapshot.data ?? [];
                          
                          if (items.isEmpty) {
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Claims Submitted',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          return GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final claim = claimMap[item.id];
                              return _ItemCard(item: item, profileId: profile.id, claim: claim);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error loading claims: $e', style: const TextStyle(color: Colors.red)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context, WidgetRef ref, int currentIndex) {
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
            context.go('/home/messages');
            break;
          case 2:
            // Already on my posts
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

class _ItemCard extends ConsumerWidget {
  final Item item;
  final String profileId;
  final Claim? claim; // Optional claim to show claim status

  const _ItemCard({required this.item, required this.profileId, this.claim});

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

  String _formatDateTime(Item item) {
    String dateStr = 'N/A';
    String timeStr = '';
    
    if (item.lostFoundDate != null) {
      dateStr = DateFormat('dd/MM/yyyy').format(item.lostFoundDate!);
    }
    
    if (item.lostFoundTime != null && item.lostFoundTime!.isNotEmpty) {
      final parts = item.lostFoundTime!.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        timeStr = ' ${displayHour.toString().padLeft(2, '0')}:${parts[1]} $period';
      }
    }
    
    return '$dateStr$timeStr';
  }

  String _getCategoryName(String categoryId) {
    final categoryMap = {
      'electronics': 'Electronics',
      'clothing': 'Clothing',
      'accessories': 'Accessories',
      'documents': 'Documents',
      'other': 'Other',
    };
    return categoryMap[categoryId.toLowerCase()] ?? categoryId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = item.ownerId == profileId;
    // Check if item is claimed by another user
    final isClaimed = item.status == ItemStatus.claimed || item.claimedBy != null;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/home/items/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: item.photos.isNotEmpty && item.photos.first.isNotEmpty
                      ? WebCompatibleImage(
                          imageUrl: item.photos.first,
                          height: 100,
                          fit: BoxFit.cover,
                          errorWidget: const Icon(Icons.image_not_supported, size: 32),
                        )
                      : const Icon(Icons.image, size: 32, color: Colors.grey),
                ),
                // Status badge - show claim status if claim exists, otherwise item status
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      claim != null 
                          ? claim!.status.name.toUpperCase()
                          : item.status.name.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lost/Found label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.type == ItemType.lost 
                            ? Colors.orange.shade50 
                            : const Color(0xFF00857A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item.type == ItemType.lost ? 'LOST' : 'FOUND',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: item.type == ItemType.lost 
                              ? Colors.orange.shade700 
                              : const Color(0xFF00857A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.category_outlined, size: 10, color: Colors.grey.shade600),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _getCategoryName(item.categoryId),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time_outlined, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _formatDate(item.createdAt),
                            style: TextStyle(fontSize: 8, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isOwner) ...[
                      const Spacer(),
                      // Only show Edit/Delete buttons if item is NOT claimed
                      if (!isClaimed) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 10),
                                label: const Text('Edit', style: TextStyle(fontSize: 8)),
                                onPressed: () => context.go('/home/items/${item.id}/edit'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  minimumSize: const Size(0, 22),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.delete_outline, size: 10),
                                label: const Text('Del', style: TextStyle(fontSize: 8)),
                                onPressed: () => _showDeleteDialog(context, ref, item.id),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  minimumSize: const Size(0, 22),
                                  side: const BorderSide(color: Colors.red),
                                  foregroundColor: Colors.red,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Show "Claimed" badge if item is claimed
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Claimed',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(itemRepositoryProvider).delete(itemId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete item: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
