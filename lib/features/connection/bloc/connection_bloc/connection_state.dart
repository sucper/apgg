part of 'connection_bloc.dart';

class ConnectionState extends Equatable {
  const ConnectionState({
    required this.details,
    this.status = ConnectionStatus.disconnected,
    this.receivedMessages = const <String>[],
    this.error,
  });

  /// The details of the connection (e.g., IP/Port, device ID).
  final ConnectionDetails details;

  /// The current status of the connection.
  final ConnectionStatus status;

  /// A list of received data messages, converted to string for display.
  final List<String> receivedMessages;

  /// The last error that occurred, if any.
  final Error? error;

  ConnectionState copyWith({
    final ConnectionDetails? details,
    final ConnectionStatus? status,
    final List<String>? receivedMessages,
    final Error? error,
    final bool clearError = false,
  }) => ConnectionState(
      details: details ?? this.details,
      status: status ?? this.status,
      receivedMessages: receivedMessages ?? this.receivedMessages,
      error: clearError ? null : error ?? this.error,
    );

  @override
  List<Object?> get props => <Object?>[details, status, receivedMessages, error];
}
