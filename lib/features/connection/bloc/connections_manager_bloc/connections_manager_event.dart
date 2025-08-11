part of 'connections_manager_bloc.dart';

abstract class ConnectionsManagerEvent extends Equatable {
  const ConnectionsManagerEvent();

  @override
  List<Object> get props => <Object>[];
}

/// Event to add a new connection to the manager.
class ConnectionAdded extends ConnectionsManagerEvent {
  const ConnectionAdded(this.details);

  final ConnectionDetails details;

  @override
  List<Object> get props => <Object>[details];
}

/// Event to remove an existing connection from the manager using its unique ID.
class ConnectionRemoved extends ConnectionsManagerEvent {

  const ConnectionRemoved(this.connectionId);
  final String connectionId;

  @override
  List<Object> get props => <Object>[connectionId];
}
