import '../entities/player.dart';
import '../repositories/game_repository.dart';

class GetPlayerInfo {
  final GameRepository repository;

  GetPlayerInfo(this.repository);

  Future<Player> call(String playerId) async {
    return await repository.getPlayerInfo(playerId);
  }
}
