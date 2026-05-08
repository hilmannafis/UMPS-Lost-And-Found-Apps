import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

/// Default categories with subcategories
final defaultCategories = [
  Category(
    id: 'electronics',
    name: 'Electronics',
    iconName: 'phone_android',
    subcategories: [
      Subcategory(id: 'phone', name: 'Phone'),
      Subcategory(id: 'laptop', name: 'Laptop'),
      Subcategory(id: 'charger', name: 'Charger'),
      Subcategory(id: 'headphones', name: 'Headphones'),
      Subcategory(id: 'tablet', name: 'Tablet'),
      Subcategory(id: 'watch', name: 'Smart Watch'),
      Subcategory(id: 'other_electronics', name: 'Other'),
    ],
  ),
  Category(
    id: 'clothing',
    name: 'Clothing',
    iconName: 'checkroom',
    subcategories: [
      Subcategory(id: 'jacket', name: 'Jacket'),
      Subcategory(id: 'hat', name: 'Hat'),
      Subcategory(id: 'shoes', name: 'Shoes'),
      Subcategory(id: 'shirt', name: 'Shirt'),
      Subcategory(id: 'pants', name: 'Pants'),
      Subcategory(id: 'accessories_clothing', name: 'Accessories'),
      Subcategory(id: 'other_clothing', name: 'Other'),
    ],
  ),
  Category(
    id: 'documents',
    name: 'Documents',
    iconName: 'description',
    subcategories: [
      Subcategory(id: 'id_card', name: 'ID Card'),
      Subcategory(id: 'student_card', name: 'Student Card'),
      Subcategory(id: 'passport', name: 'Passport'),
      Subcategory(id: 'certificate', name: 'Certificate'),
      Subcategory(id: 'license', name: 'License'),
      Subcategory(id: 'other_documents', name: 'Other'),
    ],
  ),
  Category(
    id: 'accessories',
    name: 'Accessories',
    iconName: 'watch',
    subcategories: [
      Subcategory(id: 'watch', name: 'Watch'),
      Subcategory(id: 'jewelry', name: 'Jewelry'),
      Subcategory(id: 'glasses', name: 'Glasses'),
      Subcategory(id: 'wallet', name: 'Wallet'),
      Subcategory(id: 'keys', name: 'Keys'),
      Subcategory(id: 'other_accessories', name: 'Other'),
    ],
  ),
  Category(
    id: 'books',
    name: 'Books',
    iconName: 'menu_book',
    subcategories: [
      Subcategory(id: 'textbook', name: 'Textbook'),
      Subcategory(id: 'notebook', name: 'Notebook'),
      Subcategory(id: 'novel', name: 'Novel'),
      Subcategory(id: 'diary', name: 'Diary'),
      Subcategory(id: 'other_books', name: 'Other'),
    ],
  ),
  Category(
    id: 'bags',
    name: 'Bags',
    iconName: 'backpack',
    subcategories: [
      Subcategory(id: 'backpack', name: 'Backpack'),
      Subcategory(id: 'handbag', name: 'Handbag'),
      Subcategory(id: 'laptop_bag', name: 'Laptop Bag'),
      Subcategory(id: 'wallet_bag', name: 'Wallet/Purse'),
      Subcategory(id: 'other_bags', name: 'Other'),
    ],
  ),
  Category(
    id: 'other',
    name: 'Other',
    iconName: 'category',
    subcategories: [],
  ),
];

/// Provider for all categories (default + custom)
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final firestore = FirebaseFirestore.instance;
  
  // Combine default categories with custom categories from Firestore
  return firestore
      .collection('categories')
      .where('isCustom', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    final customCategories = snapshot.docs
        .map((doc) => Category.fromMap(doc.id, doc.data()))
        .toList();
    
    // Merge default and custom categories
    return [...defaultCategories, ...customCategories];
  });
});

/// Provider for getting a category by ID
final categoryByIdProvider = Provider.family<Category?, String>((ref, categoryId) {
  final categories = ref.watch(categoriesProvider);
  return categories.when(
    data: (cats) => cats.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => defaultCategories.firstWhere((c) => c.id == 'other'),
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Helper function to get Material icon from icon name
IconData getIconFromName(String iconName) {
  switch (iconName) {
    case 'phone_android':
      return Icons.phone_android;
    case 'checkroom':
      return Icons.checkroom;
    case 'description':
      return Icons.description;
    case 'watch':
      return Icons.watch;
    case 'menu_book':
      return Icons.menu_book;
    case 'backpack':
      return Icons.backpack;
    case 'category':
    default:
      return Icons.category;
  }
}

