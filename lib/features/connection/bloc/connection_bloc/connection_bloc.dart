import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/repositories/iconnection_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

part 'connection_event.dart';
part 'connection_state.dart';

class ConnectionBloc extends Bloc<ConnectionEvent, ConnectionState> {
  ConnectionBloc({required final IConnectionRepository connectionRepository, required final ConnectionDetails initialDetails})
    : _connectionRepository = connectionRepository,
      super(ConnectionState(details: initialDetails)) {
    on<ConnectRequested>(_onConnectRequested);
    on<DisconnectRequested>(_onDisconnectRequested);
    on<DataSent>(_onDataSent);
    on<_StatusChanged>(_onStatusChanged);
    on<_DataReceived>(_onDataReceived);
    on<_ErrorOccurred>(_onErrorOccurred);
  }

  final IConnectionRepository _connectionRepository;
  StreamSubscription<Either<Error, ConnectionStatus>>? _statusSubscription;
  StreamSubscription<Either<Error, List<int>>>? _dataSubscription;

  Future<void> _onConnectRequested(final ConnectRequested event, final Emitter<ConnectionState> emit) async {
    // Prevent reconnection if already connected or connecting
    if (state.status == ConnectionStatus.connected || state.status == ConnectionStatus.connecting) {
      return;
    }
    emit(state.copyWith(status: ConnectionStatus.connecting, clearError: true));

    final Either<Error, void> connectResult = await _connectionRepository.connect(state.details);
    connectResult.fold(
      (final Error error) {
        add(_ErrorOccurred(error));
        // Explicitly set status to disconnected on connection failure
        add(const _StatusChanged(ConnectionStatus.disconnected));
      },
      (_) {
        // Immediately emit the connected state because the repository call was successful.
        emit(state.copyWith(status: ConnectionStatus.connected));

        // Subscribe to status and data streams for future updates (e.g., disconnection)
        _statusSubscription = _connectionRepository.listenToStatus(state.details).listen((final Either<Error, ConnectionStatus> either) {
          either.fold((final Error err) => add(_ErrorOccurred(err)), (final ConnectionStatus status) => add(_StatusChanged(status)));
        });

        _dataSubscription = _connectionRepository.listenToData(state.details).listen((final Either<Error, List<int>> either) {
          either.fold((final Error err) => add(_ErrorOccurred(err)), (final List<int> data) => add(_DataReceived(data)));
        });
      },
    );
  }

  Future<void> _onDisconnectRequested(final DisconnectRequested event, final Emitter<ConnectionState> emit) async {
    await _connectionRepository.disconnect(state.details);
    // The status stream should emit 'disconnected', which will trigger cleanup.
    // However, to make the UI more responsive, we can immediately emit a disconnected state.
    add(const _StatusChanged(ConnectionStatus.disconnected));
  }

  Future<void> _onDataSent(final DataSent event, final Emitter<ConnectionState> emit) async {
    final Either<Error, void> result = await _connectionRepository.sendData(state.details, event.data);
    result.fold(
      (final Error error) => add(_ErrorOccurred(error)),
      (_) {
        final String sentMessage = '>> ${utf8.decode(event.data, allowMalformed: true)}';
        emit(state.copyWith(receivedMessages: List<String>.of(state.receivedMessages)..add(sentMessage)));
      },
    );
  }

  void _onStatusChanged(final _StatusChanged event, final Emitter<ConnectionState> emit) {
    // Avoid emitting the same status multiple times
    if (state.status == event.status) return;

    emit(state.copyWith(status: event.status));
    if (event.status == ConnectionStatus.disconnected || event.status == ConnectionStatus.error) {
      // Cleanup subscriptions when disconnected or an error occurs
      _statusSubscription?.cancel();
      _dataSubscription?.cancel();
      _statusSubscription = null;
      _dataSubscription = null;
    }
  }

  void _onDataReceived(final _DataReceived event, final Emitter<ConnectionState> emit) {
    final String message = '<< ${utf8.decode(event.data, allowMalformed: true)}';
    final List<String> updatedMessages = List<String>.of(state.receivedMessages)..add(message);
    // Optional: Limit the number of messages to avoid memory issues
    if (updatedMessages.length > 100) {
      updatedMessages.removeRange(0, updatedMessages.length - 100);
    }
    emit(state.copyWith(receivedMessages: updatedMessages));
  }

  void _onErrorOccurred(final _ErrorOccurred event, final Emitter<ConnectionState> emit) {
    emit(state.copyWith(error: event.error, status: ConnectionStatus.error));
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    _dataSubscription?.cancel();
    // Ensure we attempt to disconnect on close, if not already disconnected
    if (state.status == ConnectionStatus.connected) {
      _connectionRepository.disconnect(state.details);
    }
    return super.close();
  }
}
