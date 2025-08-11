import 'package:agropilot/features/connection/domain/entities/connection_type.dart';
import 'package:agropilot/features/parsing/domain/entities/parser_type.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Base class for all connection details.
abstract class ConnectionDetails extends Equatable {
  ConnectionDetails({required this.name, required this.type, required this.parserType, final String? id})
    : id = id ?? const Uuid().v4();

  final String id;
  final String name;
  final ConnectionType type;
  final ParserType parserType;

  @override
  List<Object?> get props => <Object?>[id, name, type, parserType];
}
