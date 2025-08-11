import 'dart:async';
import 'dart:typed_data';

import 'package:agropilot/features/connection/data/datasources/iscannable_connection_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/serial_connection_details.dart';
import 'package:agropilot/features/parsing/domain/entities/parser_type.dart';
import 'package:fpdart/fpdart.dart';
import 'package:usb_serial/usb_serial.dart';

class SerialDataSource implements IScannableConnectionDataSource {
  // --- Maps for Multi-Connection ---
  final Map<String, UsbPort> _ports = <String, UsbPort>{};
  final Map<String, StreamSubscription<Uint8List>> _subscriptions = <String, StreamSubscription<Uint8List>>{};
  final Map<String, StreamController<Either<Error, List<int>>>> _dataControllers =
      <String, StreamController<Either<Error, List<int>>>>{};
  final Map<String, StreamController<Either<Error, ConnectionStatus>>> _statusControllers =
      <String, StreamController<Either<Error, ConnectionStatus>>>{};

  @override
  Type get connectionDetailsType => SerialConnectionDetails;

  @override
  Future<void> startScan() async {
    // For usb_serial, scanning is a one-shot operation via `listDevices`.
    // This method is here to comply with the interface. No action needed.
  }

  @override
  Future<void> stopScan() async {
    // No continuous scanning to stop for usb_serial.
  }

  @override
  Stream<Either<Error, List<ConnectionDetails>>> scanForDevices() =>
      Stream<List<UsbDevice>>.fromFuture(UsbSerial.listDevices()).map((final List<UsbDevice> devices) {
        try {
          final List<SerialConnectionDetails> serialDetailsList = devices
              .map(
                (final UsbDevice device) => SerialConnectionDetails(
                  id: device.deviceId.toString(),
                  name: device.productName ?? 'Unknown Serial Device',
                  portName: device.deviceName,
                  deviceId: device.deviceId.toString(), // Сохраняем deviceId
                  parserType: ParserType.unknown,
                ),
              )
              .toList();
          return Right<Error, List<ConnectionDetails>>(serialDetailsList);
        } catch (e) {
          return Left<Error, List<ConnectionDetails>>(e is Error ? e : Error());
        }
      });

  @override
  Future<Either<Error, void>> connect(final ConnectionDetails details) async {
    if (details is! SerialConnectionDetails) {
      return Left<Error, void>(ArgumentError('Details must be of type SerialConnectionDetails'));
    }
    final String connectionId = details.id;

    // ignore: close_sinks
    final StreamController<Either<Error, ConnectionStatus>> statusController = _getOrAddStatusController(connectionId);
    _getOrAddDataController(connectionId);

    try {
      statusController.add(const Right<Error, ConnectionStatus>(ConnectionStatus.connecting));
      final UsbPort? port = await UsbSerial.createFromDeviceId(int.parse(details.deviceId));
      if (port == null) {
        throw 'Failed to create port';
      }

      final bool isOpen = await port.open();
      if (!isOpen) {
        throw 'Failed to open port';
      }

      await port.setPortParameters(details.baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

      _ports[connectionId] = port;
      statusController.add(const Right<Error, ConnectionStatus>(ConnectionStatus.connected));

      _subscriptions[connectionId] = port.inputStream!.listen(
        (final Uint8List data) {
          _dataControllers[connectionId]?.add(Right<Error, List<int>>(data));
        },
        onError: (final error) {
          final Error err = error is Error ? error : Error();
          statusController.add(Left<Error, ConnectionStatus>(err));
          _dataControllers[connectionId]?.add(Left<Error, List<int>>(err));
          disconnect(details);
        },
      );

      return const Right(null);
    } catch (e) {
      final Error error = e is Error ? e : Error();
      statusController
        ..add(Left(error))
        ..add(const Right(ConnectionStatus.disconnected));
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
    final UsbPort? port = _ports[details.id];
    if (port != null) {
      try {
        await port.write(data);
        return const Right(null);
      } catch (e) {
        return Left(e is Error ? e : Error());
      }
    } else {
      return Left(StateError('Port not open for ${details.id}'));
    }
  }

  @override
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails details) =>
      _getOrAddDataController(details.id).stream;

  @override
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details) =>
      _getOrAddStatusController(details.id).stream;

  // --- Helpers ---
  StreamController<Either<Error, List<int>>> _getOrAddDataController(final String id) =>
      _dataControllers.putIfAbsent(id, () => StreamController.broadcast());

  StreamController<Either<Error, ConnectionStatus>> _getOrAddStatusController(final String id) =>
      _statusControllers.putIfAbsent(id, () => StreamController.broadcast());

  Future<void> _removeConnection(final String id) async {
    await _subscriptions.remove(id)?.cancel();
    await _ports.remove(id)?.close();

    await _dataControllers.remove(id)?.close();
    await _statusControllers.remove(id)?.close();
  }

  void dispose() {
    final List<String> allIds = _ports.keys.toList();
    for (final String id in allIds) {
      _removeConnection(id);
    }
  }
}
