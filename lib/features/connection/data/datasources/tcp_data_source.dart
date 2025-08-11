import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agropilot/features/connection/data/datasources/iconnection_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/tcp_connection_details.dart';
import 'package:fpdart/fpdart.dart';

/// Менеджер для всех активных TCP-подключений.
/// Реализует IConnectionDataSource и поддерживает мульти-подключения.
class TcpDataSource implements IConnectionDataSource {
  // Хранилища для активных подключений.
  final Map<String, Socket> _sockets = <String, Socket>{};
  final Map<String, StreamSubscription<Uint8List>> _subscriptions = <String, StreamSubscription<Uint8List>>{};
  final Map<String, StreamController<Either<Error, List<int>>>> _dataControllers =
      <String, StreamController<Either<Error, List<int>>>>{};
  final Map<String, StreamController<Either<Error, ConnectionStatus>>> _statusControllers =
      <String, StreamController<Either<Error, ConnectionStatus>>>{};

  @override
  Type get connectionDetailsType => TcpConnectionDetails;

  @override
  Future<Either<Error, void>> connect(final ConnectionDetails details) async {
    if (details is! TcpConnectionDetails) {
      final ArgumentError error = ArgumentError('Details must be of type TcpConnectionDetails');
      return Left<Error, void>(error);
    }
    final String connectionId = details.id;

    final StreamController<Either<Error, ConnectionStatus>> statusController = _getOrAddStatusController(connectionId);
    _getOrAddDataController(connectionId); // Убедимся, что контроллер данных тоже создан

    try {
      statusController.add(Right<Error, ConnectionStatus>(ConnectionStatus.connecting));
      // ignore: close_sinks
      final Socket socket = await Socket.connect(details.host, details.port);

      _sockets[connectionId] = socket;
      statusController.add(Right<Error, ConnectionStatus>(ConnectionStatus.connected));

      _subscriptions[connectionId] = socket.listen(
        (final Uint8List data) {
          _dataControllers[connectionId]?.add(Right<Error, List<int>>(data));
        },
        onDone: () {
          // Соединение было закрыто удаленной стороной
          disconnect(details);
        },
        onError: (final error) {
          final Error err = error is Error ? error : Error();
          _statusControllers[connectionId]?.add(Left<Error, ConnectionStatus>(err));
          _dataControllers[connectionId]?.add(Left<Error, List<int>>(err));
          disconnect(details);
        },
        cancelOnError: true,
      );
      return const Right<Error, void>(null);
    } catch (e) {
      final Error error = e is Error ? e : Error();
      statusController
        ..add(Left<Error, ConnectionStatus>(error))
        ..add(Right<Error, ConnectionStatus>(ConnectionStatus.disconnected));
      _removeConnection(connectionId); // Очищаем ресурсы
      return Left<Error, void>(error);
    }
  }

  @override
  Future<Either<Error, void>> disconnect(final ConnectionDetails details) async {
    final StreamController<Either<Error, ConnectionStatus>>? statusController = _statusControllers[details.id];
    // Отправляем статус, даже если контроллер уже был удален
    statusController?.add(const Right(ConnectionStatus.disconnected));
    await _removeConnection(details.id);
    return const Right(null);
  }

  @override
  Future<Either<Error, void>> sendData(final ConnectionDetails details, final Uint8List data) async {
    final Socket? socket = _sockets[details.id];
    if (socket != null) {
      try {
        socket.add(data);
        return const Right(null);
      } catch (e) {
        return Left(e is Error ? e : Error());
      }
    } else {
      return Left(StateError('No active socket for ${details.id}'));
    }
  }

  @override
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails details) =>
      _getOrAddDataController(details.id).stream;

  @override
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details) =>
      _getOrAddStatusController(details.id).stream;

  // --- Вспомогательные методы ---

  StreamController<Either<Error, List<int>>> _getOrAddDataController(final String id) =>
      _dataControllers.putIfAbsent(id, () => StreamController.broadcast());

  StreamController<Either<Error, ConnectionStatus>> _getOrAddStatusController(final String id) =>
      _statusControllers.putIfAbsent(id, () => StreamController.broadcast());

  Future<void> _removeConnection(final String id) async {
    await _subscriptions.remove(id)?.cancel();
    _sockets.remove(id)?.destroy();

    await _dataControllers.remove(id)?.close();
    await _statusControllers.remove(id)?.close();
  }

  void dispose() {
    final List<String> allIds = _sockets.keys.toList();
    for (final String id in allIds) {
      _removeConnection(id);
    }
  }
}
