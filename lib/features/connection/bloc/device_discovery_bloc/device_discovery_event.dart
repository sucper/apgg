part of 'device_discovery_bloc.dart';

abstract class DeviceDiscoveryEvent extends Equatable {
  const DeviceDiscoveryEvent();

  @override
  List<Object> get props => <Object>[];
}

/// Starts scanning for devices of a specific type (BLE or Serial).
class ScanStarted extends DeviceDiscoveryEvent {
  const ScanStarted(this.type);
  final ConnectionType type;

  @override
  List<Object> get props => <Object>[type];
}

/// Stops the current scanning process.
class ScanStopped extends DeviceDiscoveryEvent {}

/// Updates the name filter for the device list.
class FilterChanged extends DeviceDiscoveryEvent {
  const FilterChanged(this.filter);
  final String filter;

  @override
  List<Object> get props => <Object>[filter];
}

/// Toggles the visibility of devices that do not have a name.
class ShowUnnamedToggled extends DeviceDiscoveryEvent {
  const ShowUnnamedToggled(this.showUnnamed);
  final bool showUnnamed;

  @override
  List<Object> get props => <Object>[showUnnamed];
}

/// Internal event for when the repository provides an updated list of devices.
class _DevicesUpdated extends DeviceDiscoveryEvent {
  const _DevicesUpdated(this.devices);
  final List<ConnectionDetails> devices;

  @override
  List<Object> get props => <Object>[devices];
}

/// Internal event for when a scanning error occurs.
class _ScanErrorOccurred extends DeviceDiscoveryEvent {
  const _ScanErrorOccurred(this.error);
  final Error error;

  @override
  List<Object> get props => <Object>[error];
}
