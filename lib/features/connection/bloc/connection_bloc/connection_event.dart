part of 'connection_bloc.dart';

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object> get props => <Object>[];
}

/// UI event to initiate the connection process.
class ConnectRequested extends ConnectionEvent {}

/// UI event to terminate the connection.
class DisconnectRequested extends ConnectionEvent {}

/// UI event to send data over the connection.
class DataSent extends ConnectionEvent {
  const DataSent(this.data);
  final Uint8List data;

  @override
  List<Object> get props => <Object>[data];
}

/// Internal event triggered when the connection status changes.
class _StatusChanged extends ConnectionEvent {
  const _StatusChanged(this.status);
  final ConnectionStatus status;

  @override
  List<Object> get props => <Object>[status];
}

/// Internal event triggered when new data is received.
class _DataReceived extends ConnectionEvent {
  const _DataReceived(this.data);
  final List<int> data;

  @override
  List<Object> get props => <Object>[data];
}

/// Internal event triggered on connection error.
class _ErrorOccurred extends ConnectionEvent {
  const _ErrorOccurred(this.error);
  final Error error;

  @override
  List<Object> get props => <Object>[error];
}
