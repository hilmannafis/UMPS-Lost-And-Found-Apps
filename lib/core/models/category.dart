import 'package:cloud_firestore/cloud_firestore.dart';

/// Category model with support for subcategories
class Category {
  Category({
    required this.id,
    required this.name,
    required this.iconName,
    this.subcategories = const [],
    this.isCustom = false,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String iconName; // Material icon name (e.g., 'phone_android')
  final List<Subcategory> subcategories;
  final bool isCustom; // True if created by admin
  final String? createdBy; // Admin user ID who created this
  final DateTime? createdAt;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'subcategories': subcategories.map((s) => s.toMap()).toList(),
      'isCustom': isCustom,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  factory Category.fromMap(String id, Map<String, dynamic> data) {
    return Category(
      id: id,
      name: data['name'] ?? '',
      iconName: data['iconName'] ?? 'category',
      subcategories: (data['subcategories'] as List<dynamic>?)
              ?.map((s) => Subcategory.fromMap(s as Map<String, dynamic>))
              .toList() ??
          [],
      isCustom: data['isCustom'] ?? false,
      createdBy: data['createdBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Subcategory model
class Subcategory {
  Subcategory({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Subcategory.fromMap(Map<String, dynamic> data) {
    return Subcategory(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
    );
  }
}

