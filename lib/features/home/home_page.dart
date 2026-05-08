import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/item.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_controller.dart';
import '../../core/services/image_hash_service.dart';
import '../../core/providers/image_classifier_provider.dart';
import '../../core/providers/item_providers.dart';
import '../../core/providers/notification_providers.dart';
import '../../core/widgets/web_compatible_image.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  ItemType? _filterType;
  String? _selectedCategory;
  final _search = TextEditingController();
  
  // Image Hash-based Search state
  XFile? _searchImage;
  bool _isSearchingByImage = false;
  bool _isGeneratingHash = false;
  String? _searchImageHash; // Image hash from search image
  final ImageHashService _hashService = ImageHashService();
  
  // ML Kit labels for category detection
  List<Map<String, dynamic>>? _detectedLabels;
  String? _suggestedCategory;

  // Available categories with icons
  final List<Map<String, dynamic>> _categories = [
    {'id': 'electronics', 'name': 'Electronics', 'icon': Icons.phone_android},
    {'id': 'clothing', 'name': 'Clothing', 'icon': Icons.checkroom},
    {'id': 'documents', 'name': 'Documents', 'icon': Icons.description},
    {'id': 'accessories', 'name': 'Accessories', 'icon': Icons.watch},
    {'id': 'books', 'name': 'Books', 'icon': Icons.menu_book},
    {'id': 'bags', 'name': 'Bags', 'icon': Icons.backpack},
    {'id': 'other', 'name': 'Other', 'icon': Icons.category},
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickSearchImage() async {
    final ImagePicker picker = ImagePicker();
    XFile? image;
    
    // Show dialog to choose source
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search by Image'),
        content: const Text('Choose image source'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
          ),
          if (!kIsWeb)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
        ],
      ),
    );

    if (source == null) return;

    try {
      image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _searchImage = image;
          _isSearchingByImage = true;
          _isGeneratingHash = true;
          _searchImageHash = null;
          _search.clear(); // Clear text search when using image search
        });
        await _generateSearchImageHash(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _generateSearchImageHash(XFile image) async {
    try {
      print('🔍 Processing search image with ML Kit and hash generation...');
      
      // Step 1: Get ML Kit labels for category detection
      final classifier = ref.read(imageClassifierServiceProvider);
      final labels = await classifier.getAllLabels(image);
      
      if (mounted && labels.isNotEmpty) {
        setState(() {
          _detectedLabels = labels;
        });
        
        // Step 2: Get suggested category from labels
        final suggestedCategory = await classifier.classifyImage(image);
        if (suggestedCategory != null) {
          setState(() {
            _suggestedCategory = suggestedCategory;
            _selectedCategory = suggestedCategory; // Auto-select the detected category
          });
          
          // Show dialog with detected labels and category suggestion
          _showMLKitResultsDialog(labels, suggestedCategory);
        } else {
          // Show labels even if no category match
          _showMLKitResultsDialog(labels, null);
        }
      }
      
      // Step 3: Generate image hash for similarity search
      print('🔍 Generating image hash from search image...');
      final hash = await _hashService.generateImageHash(image);
      
      if (mounted) {
        setState(() {
          _isGeneratingHash = false;
          _searchImageHash = hash;
        });
        
        print('✅ Generated image hash: ${hash.substring(0, 16)}... (${hash.length} bits)');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.image_search, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _suggestedCategory != null
                        ? 'Category detected: ${_categories.firstWhere((c) => c['id'] == _suggestedCategory)['name']}'
                        : 'Image processed. Searching for similar items...',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00857A),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Clear',
              textColor: Colors.white,
              onPressed: _clearImageSearch,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error processing image: $e');
      if (mounted) {
        setState(() {
          _isGeneratingHash = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  void _showMLKitResultsDialog(List<Map<String, dynamic>> labels, String? suggestedCategory) {
    if (!mounted) return;
    
    final categoryName = suggestedCategory != null
        ? _categories.firstWhere((c) => c['id'] == suggestedCategory, orElse: () => {'name': 'Unknown'})['name']
        : null;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF00857A)),
            const SizedBox(width: 8),
            const Text('AI Detection Results', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (suggestedCategory != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00857A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00857A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category, color: Color(0xFF00857A), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Suggested Category:',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              categoryName as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00857A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Detected Items:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...labels.take(5).map((label) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label['label'] as String,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${((label['confidence'] as double) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (labels.length > 5)
                Text(
                  '... and ${labels.length - 5} more',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          if (suggestedCategory != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Category is already set, just close dialog
              },
              child: const Text('Use This Category'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Expand labels with synonyms and variations for better matching
  /// e.g., "phone" -> ["phone", "smartphone", "iphone", "mobile"]
  List<String> _expandLabelsWithSynonyms(List<String> labels) {
    final Set<String> expanded = {};
    
    // Synonym map for common items - more specific mappings
    final Map<String, List<String>> synonyms = {
      'phone': ['phone', 'smartphone', 'iphone', 'mobile', 'mobile phone', 'cell phone', 'cellphone'],
      'smartphone': ['phone', 'smartphone', 'iphone', 'mobile', 'mobile phone'],
      'iphone': ['phone', 'smartphone', 'iphone', 'mobile', 'apple'],
      'mobile': ['phone', 'smartphone', 'iphone', 'mobile', 'mobile phone'],
      'laptop': ['laptop', 'computer', 'notebook', 'macbook'],
      'computer': ['laptop', 'computer', 'pc', 'desktop'],
      'headphones': ['headphones', 'earphones', 'earbuds', 'earbud', 'headphone'],
      'earbuds': ['earbuds', 'earbud', 'earpods', 'earpod', 'earphones'],
      'earpods': ['earpods', 'earpod', 'earbuds', 'earbud', 'earphones'],
      'earpod': ['earpod', 'earpods', 'earbuds', 'earbud', 'earphones'],
      'earphones': ['earphones', 'earbuds', 'earbud', 'earpods', 'earpod', 'headphones'],
      'watch': ['watch', 'smartwatch', 'wristwatch'],
      'smartwatch': ['watch', 'smartwatch', 'wristwatch'],
      'backpack': ['backpack', 'bag', 'rucksack', 'knapsack'],
      'bag': ['backpack', 'bag', 'handbag', 'purse'],
      'wallet': ['wallet', 'purse', 'billfold'],
      'charger': ['charger', 'adapter', 'power adapter', 'cable'],
      'power bank': ['power bank', 'powerbank', 'battery', 'portable charger'],
      'powerbank': ['powerbank', 'power bank', 'battery', 'portable charger'],
      'keyboard': ['keyboard', 'keypad'],
      'mouse': ['mouse', 'computer mouse'],
      'water bottle': ['water bottle', 'bottle', 'waterbottle', 'drink bottle'],
      'bottle': ['bottle', 'water bottle', 'waterbottle', 'drink bottle'],
      'card': ['card', 'id card', 'credit card', 'debit card', 'student card', 'identity card'],
      'id card': ['card', 'id card', 'credit card', 'debit card', 'student card', 'identity card'],
      'credit card': ['card', 'id card', 'credit card', 'debit card', 'student card'],
    };
    
    for (final label in labels) {
      expanded.add(label); // Add original label
      
      // Check for synonyms
      for (final entry in synonyms.entries) {
        if (label.contains(entry.key) || entry.key.contains(label)) {
          expanded.addAll(entry.value);
        }
      }
      
      // Also add variations (remove spaces, handle plurals)
      expanded.add(label.replaceAll(' ', ''));
      expanded.add(label.replaceAll(' ', '-'));
      if (label.endsWith('s')) {
        expanded.add(label.substring(0, label.length - 1)); // Remove 's'
      } else {
        expanded.add('${label}s'); // Add 's'
      }
    }
    
    return expanded.toList();
  }

  List<String> _getKeywordsFromCategory(String? category) {
    if (category == null) return [];
    
    final Map<String, List<String>> keywordMap = {
      'electronics': ['phone', 'smartphone', 'laptop', 'tablet', 'computer', 'headphone', 'earbud', 'watch', 'camera', 'charger', 'device', 'gadget'],
      'clothing': ['shirt', 'pants', 'jeans', 'dress', 'jacket', 'shoes', 'sneakers', 'boots', 'hat', 'cap'],
      'accessories': ['wallet', 'purse', 'sunglasses', 'glasses', 'jewelry', 'necklace', 'bracelet', 'ring', 'belt'],
      'bags': ['bag', 'backpack', 'handbag', 'suitcase', 'luggage', 'briefcase'],
      'documents': ['document', 'paper', 'book', 'notebook', 'folder', 'id', 'card', 'license', 'passport'],
      'books': ['book', 'textbook', 'notebook', 'diary', 'journal'],
      'other': [],
    };
    
    return keywordMap[category] ?? <String>[];
  }

  /// Check if two words are similar (for fuzzy matching)
  /// e.g., "iphone" and "phone" are similar
  bool _areSimilarWords(String word1, String word2) {
    if (word1.length < 3 || word2.length < 3) return false;
    
    // Check if one word contains the other (with at least 3 char overlap)
    if (word1.contains(word2) || word2.contains(word1)) {
      return true;
    }
    
    // Check for common variations
    final variations = {
      'iphone': ['phone', 'smartphone'],
      'phone': ['iphone', 'smartphone', 'mobile'],
      'smartphone': ['phone', 'iphone', 'mobile'],
      'earbuds': ['earbud', 'earpods', 'earpod', 'earphones', 'headphones'],
      'earpods': ['earpod', 'earbuds', 'earbud', 'earphones'],
      'earpod': ['earpods', 'earbuds', 'earbud', 'earphones'],
      'earphones': ['earbuds', 'earbud', 'earpods', 'earpod', 'headphones'],
      'headphones': ['earbuds', 'earbud', 'earphones'],
      'powerbank': ['power bank', 'battery', 'portable charger'],
      'power bank': ['powerbank', 'battery', 'portable charger'],
      'water bottle': ['bottle', 'waterbottle', 'drink bottle'],
      'bottle': ['water bottle', 'waterbottle', 'drink bottle'],
      'mouse': ['computer mouse', 'mouse'],
      'card': ['id card', 'credit card', 'debit card', 'student card', 'identity card'],
    };
    
    for (final entry in variations.entries) {
      if ((word1.contains(entry.key) || entry.key.contains(word1)) &&
          entry.value.any((v) => word2.contains(v) || v.contains(word2))) {
        return true;
      }
    }
    
    return false;
  }

  void _clearImageSearch() {
    setState(() {
      _searchImage = null;
      _isSearchingByImage = false;
      _isGeneratingHash = false;
      _searchImageHash = null;
      _detectedLabels = null;
      // Only reset category if it was auto-selected from ML Kit
      if (_selectedCategory == _suggestedCategory) {
        _selectedCategory = null;
      }
      _suggestedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final authUser = ref.watch(authStateProvider);
    
    // Only query items if user is authenticated in Firebase Auth
    // Include userId in query to force recreation when user changes
    final itemsQuery = authUser.when(
      data: (user) => ItemsQuery(
        type: _filterType,
        categoryId: _selectedCategory,
        userId: user?.uid, // Include userId to force provider recreation on user change
      ),
      loading: () => ItemsQuery(
        type: _filterType,
        categoryId: _selectedCategory,
        userId: null,
      ),
      error: (_, __) => ItemsQuery(
        type: _filterType,
        categoryId: _selectedCategory,
        userId: null,
      ),
    );
    
    final items = authUser.when(
      data: (user) => user != null
          ? ref.watch(itemsStreamProvider(itemsQuery))
          : const AsyncValue<List<Item>>.loading(),
      loading: () => const AsyncValue<List<Item>>.loading(),
      error: (_, __) => const AsyncValue<List<Item>>.loading(),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Greeting
            if (profile != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.displaySmall?.copyWith(
                        height: 1.2,
                      ),
                      children: [
                        const TextSpan(text: 'Welcome '),
                        TextSpan(
                          text: profile.username,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: '!'),
                      ],
                    ),
                  ),
                ),
              ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _SearchBar(
                controller: _search,
                onChanged: (_) {
                  setState(() {
                    // Clear image search when typing
                    if (_search.text.isNotEmpty) {
                      _isSearchingByImage = false;
                      _searchImage = null;
                      _searchImageHash = null;
                    }
                  });
                },
                searchImage: _searchImage,
                isClassifying: _isGeneratingHash,
                onImagePick: _pickSearchImage,
                onClearImage: _clearImageSearch,
              ),
            ),
            // Show Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextButton.icon(
                onPressed: () => _showFilterSheet(context),
                icon: Icon(Icons.tune, size: 18, color: colorScheme.primary),
                label: Text(
                  'Show Filters',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: profile == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading...'),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Categories
                    Text(
                      'Quick Categories',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryButton(
                            label: 'all',
                            icon: Icons.arrow_upward,
                            selected: _selectedCategory == null,
                            onTap: () => setState(() => _selectedCategory = null),
                          ),
                          const SizedBox(width: 8),
                          // Generate category buttons dynamically
                          ..._categories.map((category) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _CategoryButton(
                                label: category['name'] as String,
                                icon: category['icon'] as IconData,
                                selected: _selectedCategory == category['id'],
                                onTap: () => setState(() => _selectedCategory = category['id'] as String),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // All Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'All Items',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_isSearchingByImage && _searchImageHash != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00857A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF00857A), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image_search, size: 14, color: Color(0xFF00857A)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Image Search',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00857A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'View All',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Items List
                    items.when(
                      data: (data) {
                        if (data.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No items found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No items found. Start by reporting a lost or found item.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // Filter items based on text search or color-based image search
                        List<Item> filtered = data;
                        
                        // Use image hash matching (EASIEST AI approach - perceptual hashing)
                        if (_isSearchingByImage && _searchImageHash != null && _searchImageHash!.isNotEmpty) {
                          print('🔍 Using image hash matching (perceptual hashing)');
                          print('🔍 Search image hash: ${_searchImageHash!.substring(0, 16)}...');
                          print('🔍 Total items in database: ${data.length}');
                          
                          // Calculate similarity scores for all items with hash data
                          final List<Map<String, dynamic>> scoredItems = data
                              .where((item) => item.imageHash != null && item.imageHash!.isNotEmpty)
                              .map((item) {
                                try {
                                  // Calculate Hamming distance (lower = more similar)
                                  final distance = _hashService.hammingDistance(_searchImageHash!, item.imageHash!);
                                  // Convert to similarity score (0-1, where 1 = identical)
                                  final similarity = _hashService.calculateSimilarity(_searchImageHash!, item.imageHash!);
                                  
                                  return {
                                    'item': item,
                                    'distance': distance,
                                    'similarity': similarity,
                                  };
                                } catch (e) {
                                  print('⚠️ Error processing item ${item.id}: $e');
                                  return {
                                    'item': item,
                                    'distance': 64, // Maximum distance
                                    'similarity': 0.0,
                                  };
                                }
                              })
                              .toList();
                          
                          // Sort by distance (lowest = most similar)
                          scoredItems.sort((a, b) => 
                              (a['distance'] as int).compareTo(b['distance'] as int));
                          
                          print('🔍 Calculated hash distance for ${scoredItems.length} items');
                          if (scoredItems.isNotEmpty) {
                            print('🔍 Top 5 most similar items:');
                            for (int i = 0; i < (scoredItems.length > 5 ? 5 : scoredItems.length); i++) {
                              final distance = scoredItems[i]['distance'] as int;
                              final similarity = scoredItems[i]['similarity'] as double;
                              final item = scoredItems[i]['item'] as Item;
                              print('   ${i + 1}. ${item.title}: distance=$distance, similarity=${similarity.toStringAsFixed(3)}');
                            }
                          }
                          
                          // Filter items with distance <= 10 (similar images)
                          // Lower threshold = stricter matching
                          const maxDistance = 10;
                          filtered = scoredItems
                              .where((entry) => (entry['distance'] as int) <= maxDistance)
                              .map((entry) => entry['item'] as Item)
                              .toList();
                          
                          print('🔍 Found ${filtered.length} items with hash distance <= $maxDistance');
                          
                          if (filtered.isEmpty) {
                            print('⚠️ No similar items found (all items have hash distance > $maxDistance)');
                            // Schedule snackbar after build completes
                            if (mounted) {
                              SchedulerBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No similar items found. Try uploading a more similar image or create new items with photos.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              });
                            }
                          }
                        } else {
                          // Filter by text search
                          final query = _search.text.trim().toLowerCase();
                          if (query.isNotEmpty) {
                            filtered = data.where((i) => 
                              i.title.toLowerCase().contains(query) || 
                              i.description.toLowerCase().contains(query)
                            ).toList();
                          }
                        }
                        
                        if (filtered.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No items match your filters')),
                          );
                        }
                        return ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return _ItemCard(item: item);
                          },
                        );
                      },
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )),
                      error: (e, stackTrace) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading items: $e',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "add_item",
        backgroundColor: const Color(0xFF00857A),
        onPressed: () => context.go('/home/report'),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Report Item',
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by Type',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterType == null,
                  onSelected: (_) => setState(() {
                    _filterType = null;
                    Navigator.pop(context);
                  }),
                ),
                ChoiceChip(
                  label: const Text('Lost'),
                  selected: _filterType == ItemType.lost,
                  onSelected: (_) => setState(() {
                    _filterType = ItemType.lost;
                    Navigator.pop(context);
                  }),
                ),
                ChoiceChip(
                  label: const Text('Found'),
                  selected: _filterType == ItemType.found,
                  onSelected: (_) => setState(() {
                    _filterType = ItemType.found;
                    Navigator.pop(context);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final profile = ref.read(authControllerProvider).profile;
    final unreadCount = profile != null 
        ? ref.watch(unreadNotificationsProvider(profile.id))
        : const AsyncValue.data(0);

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            context.go('/home/messages');
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
        const BottomNavigationBarItem(
          icon: Icon(Icons.list),
          label: 'My Post',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    this.searchImage,
    this.isClassifying = false,
    this.onImagePick,
    this.onClearImage,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final XFile? searchImage;
  final bool isClassifying;
  final VoidCallback? onImagePick;
  final VoidCallback? onClearImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Image search button
          IconButton(
            icon: isClassifying
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  )
                : Icon(
                    searchImage != null ? Icons.image_search : Icons.camera_alt_outlined,
                    color: searchImage != null ? colorScheme.primary : Colors.grey.shade600,
                  ),
            onPressed: onImagePick,
            tooltip: 'Search by image',
          ),
          // Search image preview
          if (searchImage != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: searchImage!.readAsBytes().then((bytes) => Uint8List.fromList(bytes)),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 32,
                                height: 32,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          )
                        : Image.file(
                            File(searchImage!.path),
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
                          ),
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: GestureDetector(
                      onTap: onClearImage,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              enabled: !isClassifying,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: searchImage != null ? 'Searching by image...' : 'Search items...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: searchImage != null
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade600),
                        onPressed: onClearImage,
                      )
                    : Icon(Icons.search, color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colorScheme.primary : Colors.grey.shade300,
            width: selected ? 0 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final Item item;

  String _getCategoryName(String categoryId) {
    // Map category IDs to names
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

  String _getLocation() {
    final tower = item.towerNumber.isNotEmpty ? item.towerNumber : '';
    final room = item.roomNumber.isNotEmpty ? item.roomNumber : '';
    if (tower.isEmpty && room.isEmpty) return 'N/A';
    if (tower.isEmpty) return room;
    if (room.isEmpty) return tower;
    return '$tower, $room';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLost = item.type == ItemType.lost;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/home/items/${item.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.photos.isNotEmpty && item.photos.first.isNotEmpty
                    ? WebCompatibleImage(
                        imageUrl: item.photos.first,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade100,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                            ),
                          ),
                        ),
                        errorWidget: Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400),
                        ),
                      )
                    : Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade100,
                        child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
                      ),
              ),
              const SizedBox(width: 16),
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _getCategoryName(item.categoryId),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _getLocation(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLost 
                            ? Colors.orange.shade50 
                            : colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLost 
                              ? Colors.orange.shade200 
                              : colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLost ? Icons.search_off : Icons.check_circle_outline,
                            size: 14,
                            color: isLost ? Colors.orange.shade700 : colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLost ? 'Lost' : 'Found',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isLost ? Colors.orange.shade700 : colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
