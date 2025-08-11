import 'connection_details.dart';
import 'connection_type.dart';

class BleConnectionDetails extends ConnectionDetails {
  BleConnectionDetails({required super.id, required super.name, required super.parserType, required this.deviceIdentifier})
    : super(type: ConnectionType.ble);

  final String deviceIdentifier;

  @override
  List<Object?> get props => <Object?>[...super.props, deviceIdentifier];
}
