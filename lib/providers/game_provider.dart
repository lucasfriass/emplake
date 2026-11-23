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

/// Um número resolvido, com a solução montada pelo usuário (se registrada).
class SolvedEntry {
  final String plate;
  final String? expression;
  final String? level;
  final int? points;
  final DateTime? solvedAt;

  const SolvedEntry({
    required this.plate,
    this.expression,
    this.level,
    this.points,
    this.solvedAt,
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

  /// Registra número resolvido, soma pontos e guarda a solução do usuário.
  /// A solução fica no mesmo documento (mapa `solutions`), então as regras
  /// atuais do Firestore para `users/{uid}` continuam valendo.
  Future<void> recordSolvedNumber(
    String plateNumber,
    int pointsEarned, {
    required String expression,
    required String level,
  }) async {
    final docRef = _userDoc();
    if (docRef == null) return;

    await docRef.set({
      'score': FieldValue.increment(pointsEarned),
      'solvedNumbers': FieldValue.arrayUnion([plateNumber]),
      'solutions': {
        plateNumber: {
          'expression': expression,
          'level': level,
          'points': pointsEarned,
          'solvedAt': FieldValue.serverTimestamp(),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Histórico: números resolvidos (mais recentes primeiro) com a solução.
  /// Números resolvidos antes do histórico existir aparecem sem solução.
  Future<List<SolvedEntry>> fetchHistory() async {
    final docRef = _userDoc();
    if (docRef == null) return [];

    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) return [];

    final solutions = Map<String, dynamic>.from(data['solutions'] ?? {});
    final solvedNumbers = List<String>.from(data['solvedNumbers'] ?? []);

    final withSolution = <SolvedEntry>[];
    solutions.forEach((plate, value) {
      final m = Map<String, dynamic>.from(value as Map);
      final ts = m['solvedAt'];
      withSolution.add(SolvedEntry(
        plate: plate,
        expression: m['expression'] as String?,
        level: m['level'] as String?,
        points: (m['points'] as num?)?.toInt(),
        solvedAt: ts is Timestamp ? ts.toDate() : null,
      ));
    });
    withSolution.sort((a, b) {
      final da = a.solvedAt, db = b.solvedAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    final legacy = solvedNumbers
        .where((n) => !solutions.containsKey(n))
        .map((n) => SolvedEntry(plate: n))
        .toList();

    return [...withSolution, ...legacy];
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

/// Mensagem persistente mostrada abaixo da placa após verificar.
class GameResultBanner {
  final bool success;
  final String message;
  final String? detail;
  final String hint;

  const GameResultBanner({
    required this.success,
    required this.message,
    this.detail,
    required this.hint,
  });
}

/// Estado da rodada em andamento (operadores, bloqueio e resultado).
/// Vive fora da tela para não se perder ao trocar de página (histórico,
/// configurações). É recriado ao sair da conta.
class GameSession {
  // Cada espaço guarda uma lista de operadores, na ordem em que aparecem
  List<List<String>> slots = [[], [], ['='], [], []];
  int selectedSlot = 1;
  bool locked = false;
  GameResultBanner? banner;
}

final gameSessionProvider = Provider<GameSession>((ref) => GameSession());