import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/claim.dart';
import '../../core/models/item.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/claim_providers.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/user_providers.dart';
import '../../core/widgets/web_compatible_image.dart';
import 'claim_review_page.dart';

class ClaimsPage extends ConsumerStatefulWidget {
  const ClaimsPage({super.key});

  @override
  ConsumerState<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends ConsumerState<ClaimsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final authUser = ref.watch(authStateProvider);
    
    if (profile == null || authUser.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Get claims for items owned by user (claims they need to review)
    final claimsForMyItems = ref.watch(claimsForOwnerItemsProvider(profile.id));
    // Get claims submitted by user
    final myClaims = ref.watch(claimsByUserProvider(profile.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Claims & Verification', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending Review', icon: Icon(Icons.pending_actions, size: 20)),
            Tab(text: 'My Claims', icon: Icon(Icons.assignment, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingClaimsTab(claimsForMyItems, profile.id),
          _buildMyClaimsTab(myClaims),
        ],
      ),
    );
  }

  Widget _buildPendingClaimsTab(AsyncValue<List<Claim>> claimsAsync, String userId) {
    return claimsAsync.when(
      data: (claims) {
        // Filter to only show pending claims
        final pendingClaims = claims.where((c) => c.status == ClaimStatus.pending).toList();
        
        if (pendingClaims.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Claims',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All claims have been reviewed',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pendingClaims.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final claim = pendingClaims[index];
            return _ClaimCard(claim: claim, userId: userId, isPending: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error loading claims: $e', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyClaimsTab(AsyncValue<List<Claim>> claimsAsync) {
    return claimsAsync.when(
      data: (claims) {
        if (claims.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: claims.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final claim = claims[index];
            return _ClaimCard(claim: claim, userId: '', isPending: false);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error loading claims: $e', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimCard extends ConsumerWidget {
  final Claim claim;
  final String userId;
  final bool isPending;

  const _ClaimCard({
    required this.claim,
    required this.userId,
    required this.isPending,
  });

  String _getStatusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return 'orange';
      case ClaimStatus.approved:
        return 'green';
      case ClaimStatus.rejected:
        return 'red';
    }
  }

  String _getStatusText(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.pending:
        return 'Pending';
      case ClaimStatus.approved:
        return 'Approved';
      case ClaimStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemStreamProvider(claim.itemId));
    final claimant = ref.watch(userProfileProvider(claim.claimantId));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: claim.status == ClaimStatus.pending 
              ? Colors.orange.shade200 
              : Colors.grey.shade200,
          width: claim.status == ClaimStatus.pending ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/home/claims/${claim.id}/review'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Item Image
                  item.when(
                    data: (itemData) {
                      if (itemData == null) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: itemData.photos.isNotEmpty
                            ? WebCompatibleImage(
                                imageUrl: itemData.photos.first,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.image_not_supported, size: 24),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image, size: 24),
                              ),
                      );
                    },
                    loading: () => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, __) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.error, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        item.when(
                          data: (itemData) => Text(
                            itemData?.title ?? 'Item',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          loading: () => Container(
                            height: 16,
                            width: 100,
                            color: Colors.grey.shade300,
                          ),
                          error: (_, __) => const Text('Item not found'),
                        ),
                        const SizedBox(height: 4),
                        claimant.when(
                          data: (user) => Text(
                            user != null 
                                ? 'Claimed by: ${user.firstName} ${user.lastName}'
                                : 'Claimed by: Unknown',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          loading: () => Container(
                            height: 13,
                            width: 150,
                            color: Colors.grey.shade300,
                          ),
                          error: (_, __) => const Text('Unknown user'),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(claim.status) == 'orange'
                          ? Colors.orange.shade50
                          : _getStatusColor(claim.status) == 'green'
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(claim.status),
                      style: TextStyle(
                        color: _getStatusColor(claim.status) == 'orange'
                            ? Colors.orange.shade700
                            : _getStatusColor(claim.status) == 'green'
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Claim Message Preview
              Text(
                claim.message.length > 100 
                    ? '${claim.message.substring(0, 100)}...'
                    : claim.message,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    claim.createdAt != null
                        ? DateFormat('MMM dd, yyyy • hh:mm a').format(claim.createdAt!)
                        : 'Unknown date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  if (isPending && claim.status == ClaimStatus.pending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00857A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Review',
                        style: TextStyle(
                          color: Color(0xFF00857A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

