import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/claim.dart';
import '../../core/models/item.dart';
import '../../core/models/message.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/providers/claim_providers.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/message_providers.dart';
import '../../core/providers/user_providers.dart';
import '../claims/claim_review_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.itemId,
  });

  final String otherUserId;
  final String itemId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  bool _hasMarkedAsRead = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await ref.read(messageRepositoryProvider).sendMessage(
            senderId: profile.id,
            receiverId: widget.otherUserId,
            itemId: widget.itemId,
            text: text,
          );

      // Mark messages as read when sending
      await ref.read(messageRepositoryProvider).markAsRead(
            profile.id,
            widget.otherUserId,
            widget.itemId,
          );

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null || _isUploadingImage) return;

    try {
      // Show image source dialog
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      setState(() => _isUploadingImage = true);

      // Pick image
      final pickedImage = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (pickedImage == null) {
        setState(() => _isUploadingImage = false);
        return;
      }

      // Show sending indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Uploading image...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Send image message
      final text = _messageController.text.trim();
      await ref.read(messageRepositoryProvider).sendImageMessage(
            senderId: profile.id,
            receiverId: widget.otherUserId,
            itemId: widget.itemId,
            text: text,
            image: pickedImage,
          );

      _messageController.clear();

      // Mark messages as read when sending
      await ref.read(messageRepositoryProvider).markAsRead(
            profile.id,
            widget.otherUserId,
            widget.itemId,
          );

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () => _scrollToBottom());

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image sent successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat (will be done in build)
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    final item = ref.watch(itemStreamProvider(widget.itemId));
    final otherUser = ref.watch(userProfileProvider(widget.otherUserId));
    final messagesQuery = MessageQuery(
      userId1: profile.id,
      userId2: widget.otherUserId,
      itemId: widget.itemId,
    );
    final messages = ref.watch(messagesStreamProvider(messagesQuery));

    // Mark messages as read when chat is opened (only once)
    if (messages.hasValue && !_hasMarkedAsRead) {
      _hasMarkedAsRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(messageRepositoryProvider).markAsRead(
              profile.id,
              widget.otherUserId,
              widget.itemId,
            );
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00857A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: otherUser.when(
          data: (user) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user != null ? '${user.firstName} ${user.lastName}' : 'User',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              item.when(
                data: (itemData) => Text(
                  itemData?.title ?? 'Item',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('User'),
        ),
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: messages.when(
              data: (messagesList) {
                if (messagesList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation!',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messagesList.length,
                  itemBuilder: (context, index) {
                    final message = messagesList[index];
                    final isMe = message.senderId == profile.id;
                    
                    // Handle claim messages specially
                    if (message.type == MessageType.claim && message.claimId != null) {
                      return _buildClaimMessage(context, message, isMe, profile.id);
                    }
                    
                    // Handle image messages
                    if (message.type == MessageType.image && message.imageUrl != null) {
                      return _buildImageMessage(context, message, isMe, profile, otherUser);
                    }
                    
                    // Check if this is a meet details message (contains meet location/time)
                    final isMeetDetailsMessage = message.text.contains('📍 Meet Location:') ||
                        message.text.contains('🕐 Meet Date:') ||
                        message.text.contains('Your claim has been approved');
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey.shade300,
                              child: Text(
                                otherUser.when(
                                  data: (user) => user != null ? user.firstName[0].toUpperCase() : '?',
                                  loading: () => '?',
                                  error: (_, __) => '?',
                                ),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMeetDetailsMessage
                                    ? (isMe ? Colors.green.shade600 : Colors.green.shade50)
                                    : (isMe ? const Color(0xFF00857A) : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 20),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isMeetDetailsMessage && !isMe
                                    ? Border.all(color: Colors.green.shade300, width: 1.5)
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isMeetDetailsMessage) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: isMe ? Colors.white : Colors.green.shade700,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Claim Approved',
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.green.shade700,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    message.text,
                                    style: TextStyle(
                                      color: isMeetDetailsMessage
                                          ? (isMe ? Colors.white : Colors.black87)
                                          : (isMe ? Colors.white : Colors.black87),
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.createdAt != null
                                        ? DateFormat('HH:mm').format(message.createdAt!)
                                        : '',
                                    style: TextStyle(
                                      color: isMeetDetailsMessage
                                          ? (isMe ? Colors.white70 : Colors.grey.shade600)
                                          : (isMe ? Colors.white70 : Colors.grey.shade600),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF00857A).withOpacity(0.1),
                              child: Text(
                                profile.firstName.isNotEmpty ? profile.firstName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF00857A),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Image picker button
                  IconButton(
                    onPressed: _isUploadingImage ? null : _pickAndSendImage,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate, color: Color(0xFF00857A)),
                    tooltip: 'Send image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isUploadingImage,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Color(0xFF00857A), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00857A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00857A).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isUploadingImage ? null : _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimMessage(BuildContext context, Message message, bool isMe, String currentUserId) {
    final claimId = message.claimId!;
    final claim = ref.watch(claimStreamProvider(claimId));
    final item = ref.watch(itemStreamProvider(message.itemId));
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: claim.when(
          data: (claimData) {
            if (claimData == null) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('Claim not found'),
              );
            }

            // Check if current user is the owner (can accept/reject)
            final isOwner = item.maybeWhen(
              data: (itemData) => itemData?.ownerId == currentUserId,
              orElse: () => false,
            );

            return GestureDetector(
              onTap: () {
                // Navigate to claim review page
                context.push('/home/claims/$claimId/review');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF00857A) : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show full claim message content (combines status and details)
                    if (claimData.status == ClaimStatus.pending)
                      // Pending: Show claim request
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claim the item',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to view details',
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else if (claimData.status == ClaimStatus.approved)
                      // Approved: Show status and meeting details
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Claim Approved',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your claim has been approved!',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (claimData.meetLocation != null && claimData.meetTime != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Meet Location: ${claimData.meetLocation}',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Meet Date: ${DateFormat('MMM dd, yyyy').format(claimData.meetTime!)}',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.access_time, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Meet Time: ${DateFormat('hh:mm a').format(claimData.meetTime!)}',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please arrive on time to collect your item.',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.white70,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      // Rejected: Show rejection status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cancel, color: Colors.red, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Claim Rejected',
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your claim has been rejected.',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    // Show accept/reject buttons if owner and pending
                    if (isOwner && claimData.status == ClaimStatus.pending) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => _handleClaimDecision(context, claimData, ClaimStatus.approved),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _handleClaimDecision(context, claimData, ClaimStatus.rejected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    // Timestamp
                    Text(
                      message.createdAt != null
                          ? DateFormat('HH:mm').format(message.createdAt!)
                          : '',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text('Error loading claim: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildImageMessage(
    BuildContext context,
    Message message,
    bool isMe,
    UserProfile profile,
    AsyncValue<UserProfile?> otherUser,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              child: Text(
                otherUser.when(
                  data: (user) => user != null ? user.firstName[0].toUpperCase() : '?',
                  loading: () => '?',
                  error: (_, __) => '?',
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
                maxHeight: 220,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF00857A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.text.isNotEmpty ? 0 : (isMe ? 20 : 4)),
                  bottomRight: Radius.circular(message.text.isNotEmpty ? 0 : (isMe ? 4 : 20)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.text.isNotEmpty ? 0 : (isMe ? 20 : 4)),
                      bottomRight: Radius.circular(message.text.isNotEmpty ? 0 : (isMe ? 4 : 20)),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        // Show full screen image
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: Stack(
                              children: [
                                Center(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      message.imageUrl!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 40,
                                  right: 20,
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        height: 180,
                        child: Image.network(
                          message.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.error_outline, color: Colors.red),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  // Text caption (if any)
                  if (message.text.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  // Timestamp
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 8,
                      top: message.text.isNotEmpty ? 0 : 8,
                    ),
                    child: Text(
                      message.createdAt != null
                          ? DateFormat('HH:mm').format(message.createdAt!)
                          : '',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF00857A).withOpacity(0.1),
              child: Text(
                profile.firstName.isNotEmpty ? profile.firstName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00857A),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleClaimDecision(BuildContext context, Claim claim, ClaimStatus status) async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;

    // For rejection, show simple confirmation
    if (status == ClaimStatus.rejected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject Claim?'),
          content: const Text('Are you sure you want to reject this claim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        await ref.read(claimRepositoryProvider).decide(
              claimId: claim.id,
              status: status,
              decidedBy: profile.id,
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Claim rejected successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
      return;
    }

    // For approval, show meet time and location form
    final meetInfo = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MeetInfoDialog(),
    );

    if (meetInfo == null) return; // User cancelled

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Claim?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to approve this claim?'),
            const SizedBox(height: 12),
            Text('📍 Location: ${meetInfo['location']}'),
            const SizedBox(height: 4),
            Text('🕐 Time: ${meetInfo['time']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(claimRepositoryProvider).decide(
            claimId: claim.id,
            status: status,
            decidedBy: profile.id,
            meetLocation: meetInfo['location'] as String?,
            meetTime: meetInfo['dateTime'] as DateTime?,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim approved successfully! Meet details sent to claimant.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// Meet info dialog for chat page
class _MeetInfoDialog extends StatefulWidget {
  @override
  State<_MeetInfoDialog> createState() => _MeetInfoDialogState();
}

class _MeetInfoDialogState extends State<_MeetInfoDialog> {
  final _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDateTime() {
    if (_selectedDate == null || _selectedTime == null) return 'Not selected';
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }

  DateTime? _getDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Meet Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Meet Location *',
                hintText: 'e.g., Library Entrance, Tower A Lobby',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMM dd, yyyy').format(_selectedDate!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime == null
                        ? 'Select Time'
                        : _selectedTime!.format(context)),
                  ),
                ),
              ],
            ),
            if (_selectedDate != null && _selectedTime != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_formatDateTime())),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _locationController.text.trim().isEmpty ||
                  _selectedDate == null ||
                  _selectedTime == null
              ? null
              : () {
                  Navigator.pop(context, {
                    'location': _locationController.text.trim(),
                    'time': _formatDateTime(),
                    'dateTime': _getDateTime(),
                  });
                },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00857A)),
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

