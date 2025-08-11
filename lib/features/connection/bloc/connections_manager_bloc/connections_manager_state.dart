part of 'connections_manager_bloc.dart';

class ConnectionsManagerState extends Equatable {
  const ConnectionsManagerState({this.activeConnections = const <ConnectionBloc>[]});

  final List<ConnectionBloc> activeConnections;

  ConnectionsManagerState copyWith({final List<ConnectionBloc>? activeConnections}) =>
      ConnectionsManagerState(activeConnections: activeConnections ?? this.activeConnections);

  @override
  List<Object> get props => <Object>[activeConnections];
}
