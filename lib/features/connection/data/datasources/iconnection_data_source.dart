import 'dart:async';
import 'dart:typed_data';

import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:fpdart/fpdart.dart';

/// Абстрактный класс (интерфейс), определяющий базовый контракт
/// для всех источников данных о соединении (TCP, UDP, BLE, Serial).
/// Это позволяет нам работать с ними единообразно.
abstract class IConnectionDataSource {
  /// The type of connection this data source handles.
  Type get connectionDetailsType;

  /// Метод для инициации подключения.
  /// Принимает [ConnectionDetails], чтобы знать, куда и как подключаться.
  Future<Either<Error, void>> connect(final ConnectionDetails connectionDetails);

  /// Метод для разрыва текущего соединения.
  Future<Either<Error, void>> disconnect(final ConnectionDetails connectionDetails);

  /// Метод для отправки данных на устройство.
  Future<Either<Error, void>> sendData(final ConnectionDetails connectionDetails, final Uint8List data);

  /// Поток (Stream) для получения данных от подключенного устройства.
  /// Мы используем Stream, чтобы асинхронно получать сообщения по мере их поступления.
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails connectionDetails);

  /// Поток для получения обновлений о статусе подключения (подключено, отключено и т.д.).
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails connectionDetails);
}
