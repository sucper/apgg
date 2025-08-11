
import 'dart:async';
import 'dart:typed_data';

import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';
import 'package:fpdart/fpdart.dart';

/// Абстрактный класс (интерфейс), определяющий единую точку входа
/// для управления всеми типами подключений в приложении.
///
/// Этот репозиторий является "фасадом" для слоя данных, скрывая
/// детали реализации (какой именно DataSource используется).
/// Слой представления (BLoC) будет взаимодействовать только с этим репозиторием.
abstract class IConnectionRepository {
  /// Инициирует подключение на основе предоставленных деталей.
  /// Репозиторий сам определит, какой DataSource использовать.
  Future<Either<Error, void>> connect(final ConnectionDetails details);

  /// Отключает указанное соединение.
  Future<Either<Error, void>> disconnect(final ConnectionDetails details);

  /// Отправляет данные через указанное соединение.
  Future<Either<Error, void>> sendData(final ConnectionDetails details, final Uint8List data);

  /// Возвращает поток (Stream) с данными от указанного соединения.
  Stream<Either<Error, List<int>>> listenToData(final ConnectionDetails details);

  /// Возвращает поток (Stream) со статусами указанного соединения.
  Stream<Either<Error, ConnectionStatus>> listenToStatus(final ConnectionDetails details);

  /// Запускает сканирование устройств для подключения (для BLE, Serial).
  /// Возвращает поток со списком найденных устройств.
  /// Для неподдерживаемых типов (TCP, UDP) вернет поток с ошибкой.
  Stream<Either<Error, List<ConnectionDetails>>> scanForDevices(final ConnectionType type);

  Future<Either<Error, void>> startScan(final ConnectionType type);

  Future<Either<Error, void>> stopScan(final ConnectionType type);
  /// Освобождает все ресурсы, связанные со всеми активными подключениями.
  /// Должен вызываться при закрытии приложения.
  void dispose();
}
