import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class BattleLobbyEvent extends Equatable {
  const BattleLobbyEvent();

  @override
  List<Object> get props => [];
}

class LoadLobbyInfo extends BattleLobbyEvent {}
class StartGame extends BattleLobbyEvent {}

// States
abstract class BattleLobbyState extends Equatable {
  const BattleLobbyState();
  
  @override
  List<Object> get props => [];
}

class BattleLobbyInitial extends BattleLobbyState {}
class BattleLobbyLoading extends BattleLobbyState {}
class BattleLobbyLoaded extends BattleLobbyState {
  final String playerName;

  const BattleLobbyLoaded(this.playerName);

  @override
  List<Object> get props => [playerName];
}
class GameStarting extends BattleLobbyState {}

// BLoC
class BattleLobbyBloc extends Bloc<BattleLobbyEvent, BattleLobbyState> {
  BattleLobbyBloc() : super(BattleLobbyInitial()) {
    on<LoadLobbyInfo>((event, emit) async {
      emit(BattleLobbyLoading());
      await Future.delayed(const Duration(seconds: 1)); // Simulate loading
      emit(const BattleLobbyLoaded('Neon Striker'));
    });

    on<StartGame>((event, emit) async {
      emit(GameStarting());
    });
  }
}
