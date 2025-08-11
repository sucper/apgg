import 'dart:async';
import 'dart:typed_data';

import 'package:agropilot/features/connection/data/datasources/iscannable_connection_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/ble_connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/parsing/domain/entities/parser_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDataSource implements IScannableConnectionDataSource {
  final String serviceUUID = "0000ffe0-0000-1000-8000-00805f9b34fb";
  final String characteristicWriteUUID = "0000ffe1-0000-1000-8000-00805f9b34fb";
  final String characteristicReadUUID = "0000ffe2-0000-1000-8000-00805f9b34fb";

  final Map<String, BluetoothDevice> _devices = <String, BluetoothDevice>{};
  final Map<String, ConnectionDetails> _connectionDetails = <String, ConnectionDetails>{};
  final Map<String, StreamSubscription<BluetoothConnectionState>> _connectionSubscriptions =
      <String, StreamSubscription<BluetoothConnectionState>>{};
  final Map<String, StreamSubscription<List<int>>> _characteristicSubscriptions =
      <String, StreamSubscription<List<int>>>{};
  final Map<String, BluetoothCharacteristic> _writeCharacteristics = <String, BluetoothCharacteristic>{};

  final Map<String, StreamController<Either<Error, Uint8List>>> _dataControllers =
      <String, StreamController<Either<Error, Uint8List>>>{};
  final Map<String, StreamController<Either<Error, ConnectionStatus>>> _statusControllers =
      <String, StreamController<Either<Error, ConnectionStatus>>>{};

  @override
  Type get connectionDetailsType => BleConnectionDetails;

  @override
  Future<void> startScan() async {
    final Map<Permission, PermissionStatus> statuses = await <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    // Проверяем, что КАЖДЫЙ из запрошенных статусов является 'granted'
    final bool allGranted = statuses.values.every((final PermissionStatus status) => status.isGranted);

    if (!allGranted) {
      throw StateError('Bluetooth permissions not granted');
    }
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Stream<Either<Error, List<ConnectionDetails>>> scanForDevices() => FlutterBluePlus.scanResults
      .map((final List<ScanResult> results) {
        final List<BleConnectionDetails> bleDetailsList = results
            .where((final ScanResult r) => r.device.platformName.isNotEmpty)
            .map(
              (final ScanResult result) => BleConnectionDetails(
                id: result.device.remoteId.toString(),
                name: result.device.platformName,
                deviceIdentifier: result.device.remoteId.toString(),
                parserType: ParserType.unknown,
              ),
            )
            .toList();
        return Right<Error, List<ConnectionDetails>>(bleDetailsList);
      })
      .handleError((final Object error, final StackTrace stackTrace) {
        final StateError descriptiveError = StateError('Error in stream: $error\nStack trace:\n$stackTrace');
        return Left<Error, List<ConnectionDetails>>(descriptiveError);
      });

  @override
  Future<Either<Error, void>> connect(final ConnectionDetails details) async {
    if (details is! BleConnectionDetails) {
      return Left<Error, void>(ArgumentError('Details must be of type BleConnectionDetails'));
    }
    await stopScan();

    final String connectionId = details.id;

    // ignore: close_sinks
    final StreamController<Either<Error, ConnectionStatus>> statusController = _getOrAddStatusController(connectionId);
    _getOrAddDataController(connectionId);

    try {
      statusController.add(const Right<Error, ConnectionStatus>(ConnectionStatus.connecting));
      final BluetoothDevice device = BluetoothDevice.fromId(details.deviceIdentifier);

      _devices[connectionId] = device;
      _connectionDetails[connectionId] = details;

      _connectionSubscriptions[connectionId] = device.connectionState.listen(
        (final BluetoothConnectionState state) async {
          final ConnectionStatus newStatus = _mapBleStatus(state);
          statusController.add(Right<Error, ConnectionStatus>(newStatus));

          if (state == BluetoothConnectionState.connected) {
            await _discoverServices(connectionId, device);
          } else if (state == BluetoothConnectionState.disconnected) {
            await _removeConnection(connectionId);
          }
        },
        onError: (final Object e, final StackTrace stackTrace) {
          final StateError descriptiveError = StateError(
            'Error in connection status stream: $e\nStack trace:\n$stackTrace',
          );
          statusController.add(Left<Error, ConnectionStatus>(descriptiveError));
        },
      );

      await device.connect();
      return const Right<Error, void>(null);
    } catch (e) {
      final Error error = e is Error ? e : Error();
      statusController
        ..add(Left<Error, ConnectionStatus>(error))
        ..add(const Right<Error, ConnectionStatus>(ConnectionStatus.disconnected));
      await _removeConnection(connectionId);
      return Left<Error, void>(error);
    }
  }

  Future<void> _discoverServices(final String connectionId, final BluetoothDevice device) async {
    try {
      final List<BluetoothService> services = await device.discoverServices();
      final BluetoothService service = services.firstWhere(
        (final BluetoothService s) => s.uuid.toString() == serviceUUID,
      );
      final BluetoothCharacteristic writeCharacteristic = service.characteristics.firstWhere(
        (final BluetoothCharacteristic c) => c.uuid.toString() == characteristicWriteUUID,
      );
      final BluetoothCharacteristic readCharacteristic = service.characteristics.firstWhere(
        (final BluetoothCharacteristic c) => c.uuid.toString() == characteristicReadUUID,
      );

      _writeCharacteristics[connectionId] = writeCharacteristic;

      await readCharacteristic.setNotifyValue(true);
      _characteristicSubscriptions[connectionId] = readCharacteristic.lastValueStream.listen((final List<int> value) {
        _dataControllers[connectionId]?.add(Right<Error, Uint8List>(Uint8List.fromList(value)));
      });
    } catch (e) {
      _statusControllers[connectionId]?.add(Left<Error, ConnectionStatus>(e is Error ? e : Error()));
      final ConnectionDetails? originalDetails = _connectionDetails[connectionId];
      if (originalDetails != null) {
        await disconnect(originalDetails);
      }
    }
  }

  @override
  Future<Either<Error, void>> disconnect(final ConnectionDetails details) async {
    if (_statusControllers.containsKey(details.id)) {
      _statusControllers[details.id]?.add(const Right<Error, ConnectionStatus>(ConnectionStatus.disconnected));
    }
    await _removeConnection(details.id);
    return const Right<Error, void>(null);
  }

  @override
  Future<Either<Error, void>> sendData(final ConnectionDetails details, final Uint8List data) async {
    final BluetoothCharacteristic? characteristic = _writeCharacteristics[details.id];
    if (characteristic != null) {
      try {
        await characteristic.write(data, withoutResponse: true);
        return const Right<Error, void>(null);
      } catch (e) {
        return Left<Error, void>(e is Error ? e : Error());
      }
    } else {
      return Left<Error, void>(StateError('No write characteristic for ${details.id}'));
    }
  }

  @override
  Stream<Either<Error, Uint8List>> listenToData(final ConnectionDetails details) =>
      _getOrAddDataController(details.id).stream;

  @override
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details) =>
      _getOrAddStatusController(details.id).stream;

  StreamController<Either<Error, Uint8List>> _getOrAddDataController(final String id) =>
      _dataControllers.putIfAbsent(id, () => StreamController<Either<Error, Uint8List>>.broadcast());

  StreamController<Either<Error, ConnectionStatus>> _getOrAddStatusController(final String id) =>
      _statusControllers.putIfAbsent(id, () => StreamController<Either<Error, ConnectionStatus>>.broadcast());

  Future<void> _removeConnection(final String id) async {
    _connectionDetails.remove(id);
    await _connectionSubscriptions.remove(id)?.cancel();
    await _characteristicSubscriptions.remove(id)?.cancel();
    _writeCharacteristics.remove(id);

    final BluetoothDevice? device = _devices.remove(id);
    if (device != null && device.isConnected) {
      try {
        await device.disconnect();
      } catch (e) {
        debugPrint("Ignoring error during cleanup disconnect: $e");
      }
    }

    await _dataControllers.remove(id)?.close();
    await _statusControllers.remove(id)?.close();
  }

  void dispose() {
    final List<String> allIds = _devices.keys.toList();
    for (final String id in allIds) {
      _removeConnection(id);
    }
    stopScan();
  }

  ConnectionStatus _mapBleStatus(final BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connecting:
        return ConnectionStatus.connecting;
      case BluetoothConnectionState.connected:
        return ConnectionStatus.connected;
      case BluetoothConnectionState.disconnecting:
      case BluetoothConnectionState.disconnected:
        return ConnectionStatus.disconnected;
    }
  }
}
