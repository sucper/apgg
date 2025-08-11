import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agropilot/features/connection/data/datasources/iconnection_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/udp_connection_details.dart';
import 'package:fpdart/fpdart.dart';

/// Менеджер для всех активных UDP "подключений".
class UdpDataSource implements IConnectionDataSource {
  final Map<String, RawDatagramSocket> _sockets = <String, RawDatagramSocket>{};
  final Map<String, UdpConnectionDetails> _detailsMap = <String, UdpConnectionDetails>{};
  final Map<String, StreamSubscription> _subscriptions = <String, StreamSubscription>{};
  final Map<String, StreamController<Either<Error, List<int>>>> _dataControllers =
      <String, StreamController<Either<Error, List<int>>>>{};
  final Map<String, StreamController<Either<Error, ConnectionStatus>>> _statusControllers =
      <String, StreamController<Either<Error, ConnectionStatus>>>{};

  @override
  Type get connectionDetailsType => UdpConnectionDetails;

  @override
  Future<Either<Error, void>> connect(final ConnectionDetails details) async {
    if (details is! UdpConnectionDetails) {
      return Left(ArgumentError('Details must be of type UdpConnectionDetails'));
    }
    final String connectionId = details.id;
    final StreamController<Either<Error, ConnectionStatus>> statusController = _getOrAddStatusController(connectionId);
    _getOrAddDataController(connectionId);

    try {
      statusController.add(Right(ConnectionStatus.connecting));
      final RawDatagramSocket socket = await RawDatagramSocket.bind(details.bindHost, details.bindPort);
      _sockets[connectionId] = socket;
      _detailsMap[connectionId] = details; // Сохраняем детали для отправки
      statusController.add(Right(ConnectionStatus.connected));

      _subscriptions[connectionId] = socket.listen(
        (final RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final Datagram? datagram = socket.receive();
            if (datagram != null) {
              _dataControllers[connectionId]?.add(Right(datagram.data));
            }
          }
        },
        onDone: () => disconnect(details),
        onError: (final error) {
          final Error err = error is Error ? error : Error();
          statusController.add(Left(err));
          _dataControllers[connectionId]?.add(Left(err));
          disconnect(details);
        },
      );

      return const Right(null);
    } catch (e) {
      final Error error = e is Error ? e : Error();
      statusController
        ..add(Left(error))
        ..add(Right(ConnectionStatus.disconnected));
      _removeConnection(connectionId);
      return Left(error);
    }
  }

  @override
  Future<Either<Error, void>> disconnect(final ConnectionDetails details) async {
    _statusControllers[details.id]?.add(const Right(ConnectionStatus.disconnected));
    await _removeConnection(details.id);
    return const Right(null);
  }

  @override
  Future<Either<Error, void>> sendData(final ConnectionDetails details, final Uint8List data) async {
    final RawDatagramSocket? socket = _sockets[details.id];
    final UdpConnectionDetails? targetDetails = _detailsMap[details.id];

    if (socket != null && targetDetails != null) {
      try {
        socket.send(data, InternetAddress(targetDetails.host), targetDetails.port);
        return const Right(null);
      } catch (e) {
        return Left(e is Error ? e : Error());
      }
    } else {
      return Left(StateError('No active socket for ${details.id}'));
    }
  }

  @override
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails details) => _getOrAddDataController(details.id).stream;

  @override
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details) => _getOrAddStatusController(details.id).stream;

  StreamController<Either<Error, List<int>>> _getOrAddDataController(final String id) => _dataControllers.putIfAbsent(id, () => StreamController.broadcast());

  StreamController<Either<Error, ConnectionStatus>> _getOrAddStatusController(final String id) => _statusControllers.putIfAbsent(id, () => StreamController.broadcast());

  Future<void> _removeConnection(final String id) async {
    await _subscriptions.remove(id)?.cancel();
    _sockets.remove(id)?.close();
    _detailsMap.remove(id);
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
