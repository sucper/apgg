part of 'device_discovery_bloc.dart';

class DeviceDiscoveryState extends Equatable {
  const DeviceDiscoveryState({
    this.isScanning = false,
    this.allDiscoveredDevices = const <ConnectionDetails>[],
    this.filter = '',
    this.showUnnamed = false,
    this.error,
  });
  final bool isScanning;
  final List<ConnectionDetails> allDiscoveredDevices;
  final String filter;
  final bool showUnnamed;
  final Error? error;

  /// A computed property that returns a filtered list of devices for the UI.
  List<ConnectionDetails> get filteredDevices => allDiscoveredDevices.where((final ConnectionDetails device) {
    final bool nameMatches;
    final String deviceName = device.name.toLowerCase();
    final String filterLower = filter.toLowerCase(); // Handle unnamed devices
    if (deviceName.isEmpty) {
      return showUnnamed; // Show only if the toggle is on
    }

    // Handle named devices
    if (filter.isEmpty) {
      nameMatches = true; // No filter, show all named devices
    } else {
      nameMatches = deviceName.contains(filterLower);
    }

    return nameMatches;
  }).toList();

  DeviceDiscoveryState copyWith({
    final bool? isScanning,
    final List<ConnectionDetails>? allDiscoveredDevices,
    final String? filter,
    final bool? showUnnamed,
    final Error? error,
    final bool clearError = false,
  }) => DeviceDiscoveryState(
    isScanning: isScanning ?? this.isScanning,
    allDiscoveredDevices: allDiscoveredDevices ?? this.allDiscoveredDevices,
    filter: filter ?? this.filter,
    showUnnamed: showUnnamed ?? this.showUnnamed,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => <Object?>[isScanning, allDiscoveredDevices, filter, showUnnamed, error];
}
