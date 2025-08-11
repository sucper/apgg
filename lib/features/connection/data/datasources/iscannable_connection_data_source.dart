import 'package:agropilot/features/connection/data/datasources/iconnection_data_source.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:fpdart/fpdart.dart';

/// An extension of [IConnectionDataSource] for connection types
/// that support scanning for devices (e.g., BLE, Serial).
abstract class IScannableConnectionDataSource extends IConnectionDataSource {

  /// Actively starts the hardware scanning for devices.
  ///
  /// This may trigger permission requests.
  /// Throws an error if permissions are not granted or scanning fails to start.
  Future<void> startScan();

  /// Actively stops the hardware scanning.
  Future<void> stopScan();

  /// Passively listens for a stream of available devices.
  ///
  /// You must call [startScan] before listening to this stream to get results.
  Stream<Either<Error, List<ConnectionDetails>>> scanForDevices();
}
