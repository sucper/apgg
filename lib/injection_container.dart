// ignore_for_file: cascade_invocations

import 'package:agropilot/features/connection/bloc/connections_manager_bloc/connections_manager_bloc.dart';
import 'package:agropilot/features/connection/bloc/device_discovery_bloc/device_discovery_bloc.dart';
import 'package:agropilot/features/connection/data/datasources/ble_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/iconnection_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/serial_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/tcp_data_source.dart';
import 'package:agropilot/features/connection/data/datasources/udp_data_source.dart';
import 'package:agropilot/features/connection/data/repositories/connection_repository.dart';
import 'package:agropilot/features/connection/domain/repositories/iconnection_repository.dart';
import 'package:get_it/get_it.dart';

// Создаем глобальный экземпляр get_it
final GetIt sl = GetIt.instance;

/// Функция для инициализации всех зависимостей
void init() {
  // --- Blocs ---
  // Мы регистрируем их как "фабрики" или "синглтоны" в зависимости от назначения.

  // ConnectionsManagerBloc - ленивый синглтон. Он должен существовать в единственном
  // экземпляре на протяжении всей работы приложения, чтобы управлять всеми подключениями.
  sl.registerLazySingleton<ConnectionsManagerBloc>(() => ConnectionsManagerBloc(connectionRepository: sl()));

  // DeviceDiscoveryBloc - фабрика. Мы хотим создавать новый, "чистый" экземпляр
  // каждый раз, когда пользователь открывает экран поиска устройств.
  sl.registerFactory<DeviceDiscoveryBloc>(() => DeviceDiscoveryBloc(connectionRepository: sl()));

  // --- Connection Feature ---

  // 1. Data Sources
  // Мы регистрируем их как "ленивые синглтоны" (lazy singletons).
  // Это значит, что объект будет создан только при первом запросе
  // и будет жить до конца работы приложения.
  sl.registerLazySingleton(() => TcpDataSource());
  sl.registerLazySingleton(() => UdpDataSource());
  sl.registerLazySingleton(() => BleDataSource());
  sl.registerLazySingleton(() => SerialDataSource());

  // 2. Repository
  // Мы также регистрируем репозиторий как ленивый синглтон.
  // get_it автоматически найдет все зарегистрированные DataSource
  // и передаст их в конструктор ConnectionRepository.
  sl.registerLazySingleton<IConnectionRepository>(
    () => ConnectionRepository(<IConnectionDataSource>[
      sl<TcpDataSource>(),
      sl<UdpDataSource>(),
      sl<BleDataSource>(),
      sl<SerialDataSource>(),
    ]),
  );

  // --- Здесь можно будет добавлять зависимости для других фич (например, парсеры) ---
}
