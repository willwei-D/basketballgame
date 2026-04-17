import 'package:equatable/equatable.dart';

class Player extends Equatable {
  final String id;
  final String name;
  final int score;
  final int health;

  const Player({
    required this.id,
    required this.name,
    required this.score,
    required this.health,
  });

  @override
  List<Object?> get props => [id, name, score, health];
}
