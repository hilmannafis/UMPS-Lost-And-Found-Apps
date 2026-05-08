import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/item.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/item_providers.dart';
import '../../core/widgets/web_compatible_image.dart';

class ItemDetailPage extends ConsumerStatefulWidget {
  const ItemDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('HH:mm:ss').format(date);
  }

  String _getLocation(Item item) {
    final tower = item.towerNumber.isNotEmpty ? item.towerNumber : '';
    final room = item.roomNumber.isNotEmpty ? item.roomNumber : '';
    if (tower.isEmpty && room.isEmpty) return 'N/A';
    if (tower.isEmpty) return room;
    if (room.isEmpty) return tower;
    return '$tower, $room';
  }

  void _claimItem(Item item) {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to claim items')),
      );
      return;
    }

    if (profile.id == item.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot claim your own item')),
      );
      return;
    }

    context.push('/home/items/${item.id}/claim');
  }

  Future<void> _contactOwner(Item item) async {
    try {
      // Get owner profile from Firestore
      final firestore = FirebaseFirestore.instance;
      final ownerDoc = await firestore.collection('users').doc(item.ownerId).get();
      
      if (!ownerDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Owner information not available')),
          );
        }
        return;
      }

      final ownerData = ownerDoc.data();
      final phoneNumber = ownerData?['phoneNumber'] as String?;
      final email = ownerData?['email'] as String?;

      if (phoneNumber == null && email == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact information not available')),
          );
        }
        return;
      }

      if (!mounted) return;

      final currentProfile = ref.read(authControllerProvider).profile;
      if (currentProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to contact owner')),
          );
        }
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Contact Owner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message Owner Button
              ListTile(
                leading: const Icon(Icons.message, color: Color(0xFF00857A)),
                title: const Text('Message Owner'),
                subtitle: const Text('Send a message to the owner'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/home/chat/${item.ownerId}/${item.id}');
                },
              ),
              const Divider(),
              if (phoneNumber != null && phoneNumber.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('Phone'),
                  subtitle: Text(phoneNumber),
                  onTap: () async {
                    final uri = Uri.parse('tel:$phoneNumber');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
              if (email != null && email.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Email'),
                  subtitle: Text(email),
                  onTap: () async {
                    final uri = Uri.parse('mailto:$email');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(itemStreamProvider(widget.itemId));
    final profile = ref.watch(authControllerProvider).profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Item Details',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (profile?.role == UserRole.admin) {
              context.go('/admin/items'); // Admin goes back to manage items
            } else {
              Navigator.of(context).pop(); // Regular users go back normally
            }
          },
        ),
        actions: [
          // Show Edit button only if user is owner AND item is NOT claimed
          if (profile != null && profile.id == item.valueOrNull?.ownerId)
            Builder(
              builder: (context) {
                final currentItem = item.valueOrNull;
                if (currentItem == null) return const SizedBox.shrink();
                final isClaimed = currentItem.status == ItemStatus.claimed || currentItem.claimedBy != null;
                
                if (!isClaimed) {
                  return IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.black87),
                    onPressed: () => context.push('/home/items/${currentItem.id}/edit'),
                    tooltip: 'Edit Item',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
      body: item.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Item not found'));
          }
          
          final isOwner = profile != null && profile.id == data.ownerId;
          final isClaimed = data.status == ItemStatus.claimed || data.claimedBy != null;
          final isAdmin = profile?.role == UserRole.admin;
          
          return Column(
            children: [
              Expanded(
                child: _buildItemDetail(data),
              ),
              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show claim status if item is claimed
                      if (isClaimed) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'This item has been claimed',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    if (isOwner)
                                      Text(
                                        'You can view details but cannot edit this item.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Claim This Item Button - disabled if already claimed, if owner, or if admin (view only)
                      if (isAdmin) ...[
                        // Admin view only - no claim button
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'View Only (Admin)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (isClaimed || isOwner) ? null : () => _claimItem(data),
                            icon: const Icon(Icons.check_circle_outline, size: 20),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isClaimed || isOwner) 
                                  ? Colors.grey.shade300 
                                  : const Color(0xFF00857A),
                              foregroundColor: (isClaimed || isOwner) 
                                  ? Colors.grey.shade600 
                                  : Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            label: Text(
                              isClaimed 
                                  ? 'Already Claimed' 
                                  : isOwner 
                                      ? 'Cannot Claim Own Item'
                                      : 'Claim This Item',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Contact Owner Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _contactOwner(data),
                          icon: const Icon(Icons.message_outlined, size: 20),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00857A),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: const BorderSide(color: Color(0xFF00857A), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          label: const Text(
                            'Contact Owner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildItemDetail(Item item) {
    final isFound = item.type == ItemType.found;
    final dateLabel = isFound ? 'Date Found' : 'Date Lost';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item Image with Status Badge
          Stack(
            children: [
              Builder(
                builder: (context) {
                  if (item.photos.isNotEmpty) {
                    final imageUrl = item.photos.first;
                    final uri = Uri.tryParse(imageUrl);
                    if (imageUrl.isEmpty || uri == null || !uri.hasAbsolutePath) {
                      return Container(
                        width: double.infinity,
                        height: 350,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                      );
                    }
                    
                    return WebCompatibleImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: 350,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        width: double.infinity,
                        height: 350,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: Container(
                        width: double.infinity,
                        height: 350,
                        color: Colors.grey.shade200,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Image failed to load',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Container(
                    width: double.infinity,
                    height: 350,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, size: 64, color: Colors.grey),
                  );
                },
              ),
              // Status Badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: item.type == ItemType.lost 
                        ? Colors.orange.shade700 
                        : const Color(0xFF00857A),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    item.type.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Title Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00857A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getCategoryName(item.categoryId),
                            style: const TextStyle(
                              color: Color(0xFF00857A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Details Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00857A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.info_outline, color: Color(0xFF00857A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: _getCategoryName(item.categoryId),
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: dateLabel,
                          value: _formatDate(item.lostFoundDate ?? item.createdAt),
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.access_time_outlined,
                          label: 'Time',
                          value: item.lostFoundTime ?? _formatTime(item.createdAt),
                        ),
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: _getLocation(item),
                        ),
                        if (item.contactNumber != null && item.contactNumber!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Contact',
                            value: item.contactNumber!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00857A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.description_outlined, color: Color(0xFF00857A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.description.isEmpty ? 'No description provided' : item.description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
        ],
        SizedBox(
          width: icon != null ? 90 : 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
