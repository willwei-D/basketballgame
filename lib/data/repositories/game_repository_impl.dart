import '../../domain/entities/player.dart';
import '../../domain/repositories/game_repository.dart';
import '../models/player_model.dart';

class GameRepositoryImpl implements GameRepository {
  @override
  Future<Player> getPlayerInfo(String playerId) async {
    // Simulate remote fetch
    await Future.delayed(const Duration(seconds: 1));
    return PlayerModel(id: playerId, name: 'Neon Striker', score: 0, health: 100);
  }

  @override
  Future<void> quitMatch() async {
    // Simulate quit
  }

  @override
  Future<void> startMatch() async {
    // Simulate start
  }
}
