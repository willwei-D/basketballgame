import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class PostGameResultsEvent extends Equatable {
  const PostGameResultsEvent();

  @override
  List<Object> get props => [];
}

class LoadResults extends PostGameResultsEvent {}
class ReturnToLobby extends PostGameResultsEvent {}
class Rematch extends PostGameResultsEvent {}

// States
abstract class PostGameResultsState extends Equatable {
  const PostGameResultsState();
  
  @override
  List<Object> get props => [];
}

class PostGameResultsInitial extends PostGameResultsState {}
class PostGameResultsLoaded extends PostGameResultsState {
  final int points;
  final int blocks;
  final int assists;
  final String rank;
  final int shotsFired;
  final int shotsScored;

  double get shootingPct =>
      shotsFired == 0 ? 0.0 : (shotsScored / shotsFired * 100);

  const PostGameResultsLoaded({
    required this.points,
    required this.blocks,
    required this.assists,
    required this.rank,
    this.shotsFired = 0,
    this.shotsScored = 0,
  });

  @override
  List<Object> get props => [points, blocks, assists, rank, shotsFired, shotsScored];
}
class NavigatingToLobby extends PostGameResultsState {}
class NavigatingToRematch extends PostGameResultsState {}

String calcRank(double pct) {
  if (pct >= 100) return 'S';
  if (pct >= 91) return 'A';
  if (pct >= 80) return 'B';
  if (pct >= 70) return 'C';
  if (pct >= 60) return 'D';
  if (pct >= 50) return 'E';
  return 'F';
}

// BLoC
class PostGameResultsBloc extends Bloc<PostGameResultsEvent, PostGameResultsState> {
  final int shotsFired;
  final int shotsScored;

  PostGameResultsBloc({this.shotsFired = 0, this.shotsScored = 0})
      : super(PostGameResultsInitial()) {
    on<LoadResults>((event, emit) {
      final pct = shotsFired == 0 ? 0.0 : shotsScored / shotsFired * 100;
      emit(PostGameResultsLoaded(
        points: shotsScored * 2,
        blocks: 0,
        assists: 0,
        rank: calcRank(pct),
        shotsFired: shotsFired,
        shotsScored: shotsScored,
      ));
    });

    on<ReturnToLobby>((event, emit) {
      emit(NavigatingToLobby());
    });

    on<Rematch>((event, emit) {
      emit(NavigatingToRematch());
    });
  }
}
