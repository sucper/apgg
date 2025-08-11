// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:agropilot/features/connection/bloc/connection_bloc/connection_bloc.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/repositories/iconnection_repository.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

part 'connections_manager_event.dart';
part 'connections_manager_state.dart';

class ConnectionsManagerBloc extends Bloc<ConnectionsManagerEvent, ConnectionsManagerState> {
  ConnectionsManagerBloc({required final IConnectionRepository connectionRepository})
    : _connectionRepository = connectionRepository,
      super(const ConnectionsManagerState()) {
    on<ConnectionAdded>(_onConnectionAdded);
    on<ConnectionRemoved>(_onConnectionRemoved);
  }

  final IConnectionRepository _connectionRepository;

  void _onConnectionAdded(final ConnectionAdded event, final Emitter<ConnectionsManagerState> emit) {
    // Check if a connection with the same ID already exists
    if (state.activeConnections.any((final ConnectionBloc bloc) => bloc.state.details.id == event.details.id)) {
      // Optionally, handle this case, e.g., by logging or showing an error
      return;
    }

    // Create a new ConnectionBloc for the new connection
    final ConnectionBloc newConnectionBloc = ConnectionBloc(
      connectionRepository: _connectionRepository,
      initialDetails: event.details,
    );

    // Immediately request it to connect
    newConnectionBloc.add(ConnectRequested());

    // Add the new bloc to the list of active connections
    final List<ConnectionBloc> updatedConnections = List<ConnectionBloc>.of(state.activeConnections)..add(newConnectionBloc);

    emit(state.copyWith(activeConnections: updatedConnections));
  }

  Future<void> _onConnectionRemoved(final ConnectionRemoved event, final Emitter<ConnectionsManagerState> emit) async {
    final ConnectionBloc connectionToRemove = state.activeConnections.firstWhere(
      (final ConnectionBloc bloc) => bloc.state.details.id == event.connectionId,
      orElse: () => throw Exception('Connection with id ${event.connectionId} not found'), // Should not happen
    );

    // Properly close the bloc to cancel its subscriptions and resources
    await connectionToRemove.close();

    // Create a new list without the removed connection
    final List<ConnectionBloc> updatedConnections = state.activeConnections
        .where((final ConnectionBloc bloc) => bloc.state.details.id != event.connectionId)
        .toList();

    emit(state.copyWith(activeConnections: updatedConnections));
  }

  @override
  Future<void> close() {
    // Ensure all managed blocs are closed when the manager is closed
    for (final ConnectionBloc bloc in state.activeConnections) {
      bloc.close();
    }
    return super.close();
  }
}
