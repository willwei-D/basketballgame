import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class InGameUiEvent extends Equatable {
  const InGameUiEvent();

  @override
  List<Object> get props => [];
}

class StartMatchSession extends InGameUiEvent {}
class EndMatchSession extends InGameUiEvent {}

// States
abstract class InGameUiState extends Equatable {
  const InGameUiState();
  
  @override
  List<Object> get props => [];
}

class InGameInitial extends InGameUiState {}
class InGameActive extends InGameUiState {
  final int orbVelocity;
  final int hardwareStability;

  const InGameActive({required this.orbVelocity, required this.hardwareStability});

  @override
  List<Object> get props => [orbVelocity, hardwareStability];
}
class MatchEnding extends InGameUiState {}

// BLoC
class InGameUiBloc extends Bloc<InGameUiEvent, InGameUiState> {
  InGameUiBloc() : super(InGameInitial()) {
    on<StartMatchSession>((event, emit) {
      emit(const InGameActive(orbVelocity: 144, hardwareStability: 99));
    });

    on<EndMatchSession>((event, emit) async {
      emit(MatchEnding());
    });
  }
}
