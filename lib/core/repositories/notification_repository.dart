import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('notifications').doc(userId).collection('items');

  Stream<List<AppNotification>> watchForUser(String userId) {
    return _collection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> add({
    required String userId,
    required AppNotification notification,
  }) {
    return _collection(userId).doc(notification.id).set(notification.toMap());
  }

  Future<void> markRead({required String userId, required String notificationId}) {
    return _collection(userId).doc(notificationId).update({'read': true});
  }
}

