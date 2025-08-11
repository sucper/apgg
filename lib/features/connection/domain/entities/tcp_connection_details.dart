import 'connection_details.dart';
import 'connection_type.dart';

class TcpConnectionDetails extends ConnectionDetails {
  TcpConnectionDetails({required super.name, required super.parserType, required this.host, required this.port})
    : super(type: ConnectionType.tcp);

  final String host;
  final int port;

  @override
  List<Object?> get props => <Object?>[...super.props, host, port];
}
