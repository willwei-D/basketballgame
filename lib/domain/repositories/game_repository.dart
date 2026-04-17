import '../entities/player.dart';

abstract class GameRepository {
  Future<Player> getPlayerInfo(String playerId);
  Future<void> startMatch();
  Future<void> quitMatch();
}
