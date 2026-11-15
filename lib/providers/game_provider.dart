import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/math_engine.dart';

class UserProgressData {
  final int score;
  final List<String> solvedNumbers;

  const UserProgressData({
    required this.score,
    required this.solvedNumbers,
  });
}

class FirestoreGameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  dynamic _userDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return _db.collection('users').doc(user.uid);
  }

  /// Busca progresso do usuário no Firestore (usado no FutureBuilder)
  Future<UserProgressData> fetchUserProgress() async {
    final docRef = _userDoc();
    if (docRef == null) {
      return const UserProgressData(score: 0, solvedNumbers: []);
    }

    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) {
      await docRef.set({
        'score': 0,
        'solvedNumbers': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const UserProgressData(score: 0, solvedNumbers: []);
    }

    final data = snapshot.data()!;
    final score = (data['score'] as num?)?.toInt() ?? 0;
    final solved = List<String>.from(data['solvedNumbers'] ?? []);
    return UserProgressData(score: score, solvedNumbers: solved);
  }

  /// Registra número resolvido e soma pontos no Firestore
  Future<void> recordSolvedNumber(String plateNumber, int pointsEarned) async {
    final docRef = _userDoc();
    if (docRef == null) return;

    await docRef.set({
      'score': FieldValue.increment(pointsEarned),
      'solvedNumbers': FieldValue.arrayUnion([plateNumber]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Gera um número de 4 dígitos (0000 a 9999) garantidamente não resolvido
  String generateUnsolvedPlate(List<String> solvedNumbers) {
    final solvedSet = solvedNumbers.toSet();
    final rng = Random();

    for (int i = 0; i < 500; i++) {
      final candidate = rng.nextInt(10000).toString().padLeft(4, '0');
      if (!solvedSet.contains(candidate)) {
        return candidate;
      }
    }

    for (int n = 0; n < 10000; n++) {
      final candidate = n.toString().padLeft(4, '0');
      if (!solvedSet.contains(candidate)) {
        return candidate;
      }
    }
    return '1234';
  }
}

final firestoreServiceProvider = Provider<FirestoreGameService>((ref) {
  return FirestoreGameService();
});

class DifficultyNotifier extends Notifier<DifficultyLevel> {
  @override
  DifficultyLevel build() => DifficultyLevel.easy;

  void setDifficulty(DifficultyLevel level) => state = level;
}

final difficultyProvider =
    NotifierProvider<DifficultyNotifier, DifficultyLevel>(
  DifficultyNotifier.new,
);

class CurrentPlateNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setPlate(String? plate) => state = plate;
}

final currentPlateProvider = NotifierProvider<CurrentPlateNotifier, String?>(
  CurrentPlateNotifier.new,
);