import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';

class UdpConnectionDetails extends ConnectionDetails {
  UdpConnectionDetails({
    required super.name,
    required super.parserType,
    required this.host,
    required this.port,
    this.bindHost = '0.0.0.0',
    this.bindPort = 0,
  }) : super(type: ConnectionType.udp);

  final String host;
  final int port;
  final String bindHost;
  final int bindPort;

  @override
  List<Object?> get props => <Object?>[...super.props, host, port, bindHost, bindPort];
}
