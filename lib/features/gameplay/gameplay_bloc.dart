import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

enum PlayerAction {
  idle,
  moveLeft,
  moveRight,
  jump,
  blockLeft,
  blockRight,
  chargeShoot,
  stepBack,
  crouch,
  awakening,
  dunk,
}

// Game world constants (virtual 1200×640 world)
const double kGameW = 1200.0;
const double kFloorY = 0.0;
const double kGravity = -0.55;
const double kJumpForce = 14.0;
const double kMoveSpeed = 6.0;
const double kBallRadius = 15.0;

// Hoop geometry (world coords, y measured from floor up)
const double kHoopRimY = 200.0;
const double kHoopHalfGap = 22.0;
const double kLeftHoopX = 110.0;
const double kRightHoopX = kGameW - 110.0;

// Three-point line distance from each end
const double kThreePtX = 280.0;

// --------------- EVENTS ---------------

abstract class GameplayActionEvent extends Equatable {
  const GameplayActionEvent();
  @override
  List<Object> get props => [];
}

class KeyPressed extends GameplayActionEvent {
  final String key;
  const KeyPressed(this.key);
  @override
  List<Object> get props => [key];
}

class KeyReleased extends GameplayActionEvent {
  final String key;
  const KeyReleased(this.key);
  @override
  List<Object> get props => [key];
}

class GameTick extends GameplayActionEvent {}

// --------------- STATE ---------------

class GameplayActionState extends Equatable {
  // Player
  final double playerX;
  final double playerY;
  final double velocityX;
  final double velocityY;
  final PlayerAction action;
  final bool isFacingRight;

  // Ball
  final double ballX;
  final double ballY;
  final double ballVx;
  final double ballVy;
  final bool playerHasBall;
  final bool ballInFlight;
  final double chargeLevel; // 0.0–1.0
  final bool isCharging;

  // Game
  final int homeScore;
  final int guestScore;
  final double shotClock; // counts down from 24
  final double gameClock; // counts down from 120 (2 min per quarter)
  final int period;
  final bool justScored;

  // 投籃統計
  final int shotsFired;
  final int shotsScored;

  const GameplayActionState({
    required this.playerX,
    required this.playerY,
    required this.velocityX,
    required this.velocityY,
    required this.action,
    required this.isFacingRight,
    required this.ballX,
    required this.ballY,
    required this.ballVx,
    required this.ballVy,
    required this.playerHasBall,
    required this.ballInFlight,
    required this.chargeLevel,
    required this.isCharging,
    required this.homeScore,
    required this.guestScore,
    required this.shotClock,
    required this.gameClock,
    required this.period,
    required this.justScored,
    required this.shotsFired,
    required this.shotsScored,
  });

  GameplayActionState copyWith({
    double? playerX,
    double? playerY,
    double? velocityX,
    double? velocityY,
    PlayerAction? action,
    bool? isFacingRight,
    double? ballX,
    double? ballY,
    double? ballVx,
    double? ballVy,
    bool? playerHasBall,
    bool? ballInFlight,
    double? chargeLevel,
    bool? isCharging,
    int? homeScore,
    int? guestScore,
    double? shotClock,
    double? gameClock,
    int? period,
    bool? justScored,
    int? shotsFired,
    int? shotsScored,
  }) {
    return GameplayActionState(
      playerX: playerX ?? this.playerX,
      playerY: playerY ?? this.playerY,
      velocityX: velocityX ?? this.velocityX,
      velocityY: velocityY ?? this.velocityY,
      action: action ?? this.action,
      isFacingRight: isFacingRight ?? this.isFacingRight,
      ballX: ballX ?? this.ballX,
      ballY: ballY ?? this.ballY,
      ballVx: ballVx ?? this.ballVx,
      ballVy: ballVy ?? this.ballVy,
      playerHasBall: playerHasBall ?? this.playerHasBall,
      ballInFlight: ballInFlight ?? this.ballInFlight,
      chargeLevel: chargeLevel ?? this.chargeLevel,
      isCharging: isCharging ?? this.isCharging,
      homeScore: homeScore ?? this.homeScore,
      guestScore: guestScore ?? this.guestScore,
      shotClock: shotClock ?? this.shotClock,
      gameClock: gameClock ?? this.gameClock,
      period: period ?? this.period,
      justScored: justScored ?? this.justScored,
      shotsFired: shotsFired ?? this.shotsFired,
      shotsScored: shotsScored ?? this.shotsScored,
    );
  }

  @override
  List<Object> get props => [
        playerX, playerY, velocityX, velocityY, action, isFacingRight,
        ballX, ballY, ballVx, ballVy, playerHasBall, ballInFlight,
        chargeLevel, isCharging, homeScore, guestScore,
        shotClock, gameClock, period, justScored,
        shotsFired, shotsScored,
      ];
}

// --------------- BLOC ---------------

class GameplayActionBloc extends Bloc<GameplayActionEvent, GameplayActionState> {
  Timer? _gameLoop;
  final Set<String> _heldKeys = {};

  static const GameplayActionState _initial = GameplayActionState(
    playerX: 200,
    playerY: 0,
    velocityX: 0,
    velocityY: 0,
    action: PlayerAction.idle,
    isFacingRight: true,
    ballX: 245,
    ballY: 50,
    ballVx: 0,
    ballVy: 0,
    playerHasBall: true,
    ballInFlight: false,
    chargeLevel: 0.0,
    isCharging: false,
    homeScore: 0,
    guestScore: 0,
    shotClock: 24.0,
    gameClock: 120.0,
    period: 1,
    justScored: false,
    shotsFired: 0,
    shotsScored: 0,
  );

  GameplayActionBloc() : super(_initial) {
    on<KeyPressed>(_onKeyPressed);
    on<KeyReleased>(_onKeyReleased);
    on<GameTick>(_onGameTick);
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) => add(GameTick()));
  }

  void _onKeyPressed(KeyPressed event, Emitter<GameplayActionState> emit) {
    if (_heldKeys.contains(event.key)) return;
    _heldKeys.add(event.key);

    double nVx = state.velocityX;
    double nVy = state.velocityY;
    PlayerAction nAct = state.action;
    bool nFace = state.isFacingRight;

    if (event.key == 'A') {
      nVx = -kMoveSpeed;
      nFace = false;
      if (state.playerY <= kFloorY) nAct = PlayerAction.moveLeft;
    } else if (event.key == 'D') {
      nVx = kMoveSpeed;
      nFace = true;
      if (state.playerY <= kFloorY) nAct = PlayerAction.moveRight;
    }

    if (state.playerY <= kFloorY) {
      switch (event.key) {
        case 'W':
          // 靠近籃框且持球 → 灌籃
          final nearRight = (state.playerX - kRightHoopX).abs() < 120;
          final nearLeft = (state.playerX - kLeftHoopX).abs() < 120;
          if (state.playerHasBall && (nearRight || nearLeft)) {
            nVy = kJumpForce * 1.3;
            nAct = PlayerAction.dunk;
            nFace = nearRight ? true : false;
          } else {
            nVy = kJumpForce;
            nAct = PlayerAction.jump;
          }
          break;
        case 'Q':
          nVy = kJumpForce * 0.8;
          nVx = -kMoveSpeed * 1.5;
          nAct = PlayerAction.blockLeft;
          nFace = false;
          break;
        case 'E':
          nVy = kJumpForce * 0.8;
          nVx = kMoveSpeed * 1.5;
          nAct = PlayerAction.blockRight;
          nFace = true;
          break;
        case 'Z':
          nVy = kJumpForce * 0.4;
          nVx = state.isFacingRight ? -kMoveSpeed * 1.5 : kMoveSpeed * 1.5;
          nAct = PlayerAction.stepBack;
          break;
        case 'S':
          if (state.playerHasBall) {
            emit(state.copyWith(
              isCharging: true,
              action: PlayerAction.chargeShoot,
              velocityX: 0,
            ));
            return;
          }
          break;
        case 'X':
          nAct = PlayerAction.crouch;
          nVx = 0;
          break;
        case 'C':
          nAct = PlayerAction.awakening;
          nVx = 0;
          break;
      }
    }

    emit(state.copyWith(
      velocityX: nVx,
      velocityY: nVy,
      action: nAct,
      isFacingRight: nFace,
    ));
  }

  void _onKeyReleased(KeyReleased event, Emitter<GameplayActionState> emit) {
    _heldKeys.remove(event.key);

    if (event.key == 'S' && state.isCharging) {
      _shootBall(emit);
      return;
    }

    double nVx = state.velocityX;
    PlayerAction nAct = state.action;

    if (event.key == 'A' && state.velocityX < 0) nVx = 0;
    if (event.key == 'D' && state.velocityX > 0) nVx = 0;

    if (state.playerY <= kFloorY) {
      if (['X', 'C', 'Z'].contains(event.key)) nAct = PlayerAction.idle;
      if (nVx == 0 &&
          (nAct == PlayerAction.moveLeft || nAct == PlayerAction.moveRight)) {
        nAct = PlayerAction.idle;
      }
      if (_heldKeys.contains('A')) {
        nVx = -kMoveSpeed;
        nAct = PlayerAction.moveLeft;
      } else if (_heldKeys.contains('D')) {
        nVx = kMoveSpeed;
        nAct = PlayerAction.moveRight;
      }
    }

    emit(state.copyWith(velocityX: nVx, action: nAct));
  }

  void _shootBall(Emitter<GameplayActionState> emit) {
    final power = 18.0 + state.chargeLevel * 18.0;
    final dir = state.isFacingRight ? 1.0 : -1.0;
    const angle = 58 * pi / 180; // ~58° arc
    final vx = dir * power * cos(angle);
    final vy = power * sin(angle);

    // Ball leaves player's hand
    final bx = state.playerX + (state.isFacingRight ? 55.0 : -5.0);
    final by = state.playerY + 55.0;

    emit(state.copyWith(
      ballX: bx,
      ballY: by,
      ballVx: vx,
      ballVy: vy,
      ballInFlight: true,
      playerHasBall: false,
      isCharging: false,
      chargeLevel: 0.0,
      action: PlayerAction.idle,
      shotsFired: state.shotsFired + 1,
    ));
  }

  void _onGameTick(GameTick event, Emitter<GameplayActionState> emit) {
    // --- PLAYER PHYSICS ---
    double px = state.playerX + state.velocityX;
    double py = state.playerY + state.velocityY;
    double nVy = state.velocityY;
    PlayerAction nAct = state.action;

    if (px < 0) px = 0;
    if (px > kGameW - 50) px = kGameW - 50;

    if (py > kFloorY) {
      nVy += kGravity;
    } else {
      py = kFloorY;
      nVy = 0;
      if (nAct == PlayerAction.jump ||
          nAct == PlayerAction.blockLeft ||
          nAct == PlayerAction.blockRight ||
          nAct == PlayerAction.stepBack ||
          nAct == PlayerAction.dunk) {
        if (_heldKeys.contains('A')) {
          nAct = PlayerAction.moveLeft;
        } else if (_heldKeys.contains('D')) {
          nAct = PlayerAction.moveRight;
        } else {
          nAct = PlayerAction.idle;
        }
      }
    }

    // --- BALL PHYSICS ---
    double bx = state.ballX;
    double by = state.ballY;
    double bvx = state.ballVx;
    double bvy = state.ballVy;
    bool playerHasBall = state.playerHasBall;
    bool ballInFlight = state.ballInFlight;
    int homeScore = state.homeScore;
    int guestScore = state.guestScore;
    int shotsScored = state.shotsScored;
    int shotsFired = state.shotsFired;
    double shotClock = state.shotClock;
    bool justScored = false;

    // --- 灌籃判定：玩家到達籃框高度時得分 ---
    if (nAct == PlayerAction.dunk && playerHasBall && py >= kHoopRimY - 30) {
      final nearRight = (px - kRightHoopX).abs() < 150;
      if (nearRight) {
        homeScore += 2;
      } else {
        guestScore += 2;
      }
      justScored = true;
      shotClock = 24.0;
      shotsFired++;
      shotsScored++;
      nAct = PlayerAction.idle;
      nVy = -kJumpForce * 0.4;
      playerHasBall = false;
      ballInFlight = false;
    }

    if (playerHasBall) {
      // Ball sticks to player hand
      bx = px + (state.isFacingRight ? 50.0 : 0.0);
      by = py + 50.0;
    } else if (ballInFlight) {
      bvy += kGravity;
      bx += bvx;
      by += bvy;

      // Hoop collision
      final scored = _checkScore(bx, by, bvy);
      if (scored != 0) {
        final isThree = _isThreePointer(bx, scored > 0);
        if (scored > 0) {
          homeScore += isThree ? 3 : 2;
        } else {
          guestScore += isThree ? 3 : 2;
        }

        justScored = true;
        shotClock = 24.0;
        // Return ball to player
        bx = px + 30;
        by = py + 50;
        bvx = 0;
        bvy = 0;
        ballInFlight = false;
        playerHasBall = true;
        shotsScored++;
      } else if (by <= kFloorY || bx < -60 || bx > kGameW + 60) {
        // Out of bounds / hit ground — return ball
        bx = px + 30;
        by = py + 50;
        bvx = 0;
        bvy = 0;
        ballInFlight = false;
        playerHasBall = true;
        shotClock = 24.0;
      }
    }

    // --- CHARGE ---
    double chargeLevel = state.chargeLevel;
    if (state.isCharging) {
      chargeLevel = (chargeLevel + 0.012).clamp(0.0, 1.0); // ~1.3 秒蓄滿
    }

    // --- SHOT CLOCK (tick during live play) ---
    shotClock = (shotClock - 0.016).clamp(0.0, 24.0);
    if (shotClock <= 0) {
      // Shot clock violation — reset possession
      shotClock = 24.0;
      bx = px + 30;
      by = py + 50;
      bvx = 0;
      bvy = 0;
      ballInFlight = false;
      playerHasBall = true;
    }

    // --- GAME CLOCK ---
    double gameClock = (state.gameClock - 0.016).clamp(0.0, 120.0);
    int period = state.period;
    if (gameClock <= 0 && period < 4) {
      period += 1;
      gameClock = 120.0;
    }

    emit(state.copyWith(
      playerX: px,
      playerY: py,
      velocityY: nVy,
      action: nAct,
      ballX: bx,
      ballY: by,
      ballVx: bvx,
      ballVy: bvy,
      playerHasBall: playerHasBall,
      ballInFlight: ballInFlight,
      chargeLevel: chargeLevel,
      homeScore: homeScore,
      guestScore: guestScore,
      shotClock: shotClock,
      gameClock: gameClock,
      period: period,
      justScored: justScored,
      shotsFired: shotsFired,
      shotsScored: shotsScored,
    ));
  }

  // Returns +1 if home scores (right hoop), -1 if guest (left hoop), 0 otherwise
  int _checkScore(double bx, double by, double bvy) {
    // Ball must be moving downward to count
    if (bvy >= 0) return 0;

    // Right hoop
    if ((bx - kRightHoopX).abs() < kHoopHalfGap &&
        (by - kHoopRimY).abs() < 14) {
      return 1;
    }
    // Left hoop
    if ((bx - kLeftHoopX).abs() < kHoopHalfGap &&
        (by - kHoopRimY).abs() < 14) {
      return -1;
    }
    return 0;
  }

  bool _isThreePointer(double bx, bool homeScoredAtRight) {
    if (homeScoredAtRight) return bx < (kGameW - kThreePtX);
    return bx > kThreePtX;
  }

  @override
  Future<void> close() {
    _gameLoop?.cancel();
    return super.close();
  }
}
