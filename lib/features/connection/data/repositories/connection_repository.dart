import 'dart:async';
import 'dart:typed_data';

import 'package:agropilot/features/connection/data/datasources/ble_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/iconnection_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/iscannable_connection_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/serial_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/tcp_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/udp_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/ble_connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';
import 'package:agropilot/features/connection/domain/entities/serial_connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/tcp_connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/udp_connection_details.dart';
import 'package:agropilot/features/connection/domain/repositories/iconnection_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Конкретная реализация [IConnectionRepository].
/// Является "дирижером" для всех [IConnectionDataSource].
class ConnectionRepository implements IConnectionRepository {
  // Конструктор, который позволяет передать все наши DataSource.
  // Позже мы будем использовать get_it для их автоматического внедрения.
  ConnectionRepository(this._dataSources);
  // Список всех доступных источников данных.
  final List<IConnectionDataSource> _dataSources;

  /// Находит подходящий DataSource в списке по типу деталей.
  IConnectionDataSource _getDataSource(final ConnectionType type) {
    Type targetEntityType;
    switch (type) {
      case ConnectionType.tcp:
        targetEntityType = TcpConnectionDetails;
        break;
      case ConnectionType.udp:
        targetEntityType = UdpConnectionDetails;
        break;
      case ConnectionType.ble:
        targetEntityType = BleConnectionDetails;
        break;
      case ConnectionType.serial:
        targetEntityType = SerialConnectionDetails;
        break;
    }
    return _dataSources.firstWhere(
      (ds) => ds.connectionDetailsType == targetEntityType,
      orElse: () => throw UnimplementedError('No data source for $type registered or provided.'),
    );
  }

  IScannableConnectionDataSource _getScannableDataSource(final ConnectionType type) {
    final IConnectionDataSource dataSource = _getDataSource(type);
    if (dataSource is IScannableConnectionDataSource) {
      return dataSource;
    }
    throw UnimplementedError('Data source for $type is not scannable');
  }

  @override
  Future<Either<Error, void>> connect(final ConnectionDetails details) => _getDataSource(details.type).connect(details);

  @override
  Future<Either<Error, void>> disconnect(final ConnectionDetails details) =>
      _getDataSource(details.type).disconnect(details);

  @override
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails details) =>
      _getDataSource(details.type).listenToData(details);

  @override
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details) =>
      _getDataSource(details.type).listenToStatus(details);

  @override
  Future<Either<Error, void>> sendData(final ConnectionDetails details, final Uint8List data) =>
      _getDataSource(details.type).sendData(details, data);

  @override
  Stream<Either<Error, List<ConnectionDetails>>> scanForDevices(final ConnectionType connectionDetailsType) {
    try {
      final IConnectionDataSource dataSource = _getDataSource(connectionDetailsType);
      if (dataSource is IScannableConnectionDataSource) {
        return dataSource.scanForDevices();
      } else {
        return Stream.value(Left(StateError('$connectionDetailsType does not support scanning')));
      }
    } catch (e) {
      return Stream.value(Left(StateError('No DataSource found for type $connectionDetailsType')));
    }
  }

  @override
  Future<Either<Error, void>> startScan(final ConnectionType type) async {
    try {
      final IScannableConnectionDataSource dataSource = _getScannableDataSource(type);
      await dataSource.startScan();
      return const Right(null);
    } catch (e) {
      return Left(e is Error ? e : StateError(e.toString()));
    }
  }

  @override
  Future<Either<Error, void>> stopScan(final ConnectionType type) async {
    try {
      final IScannableConnectionDataSource dataSource = _getScannableDataSource(type);
      await dataSource.stopScan();
      return const Right(null);
    } catch (e) {
      return Left(e is Error ? e : StateError(e.toString()));
    }
  }

  @override
  void dispose() {
    for (final IConnectionDataSource ds in _dataSources) {
      if (ds is TcpDataSource) ds.dispose();
      if (ds is UdpDataSource) ds.dispose();
      if (ds is BleDataSource) ds.dispose();
      if (ds is SerialDataSource) ds.dispose();
    }
  }
}
