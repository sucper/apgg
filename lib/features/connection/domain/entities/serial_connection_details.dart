import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';

/// Concrete implementation of [ConnectionDetails] for Serial connections.
class SerialConnectionDetails extends ConnectionDetails {
  SerialConnectionDetails({
    required super.id,
    required super.name,
    required super.parserType,
    required this.portName,
    required this.deviceId,
    this.baudRate = 460800,
  }) : super(type: ConnectionType.serial);

  final String portName;
  final int baudRate;
  final String deviceId;

  @override
  List<Object?> get props => <Object?>[...super.props, portName, deviceId, baudRate];
}
