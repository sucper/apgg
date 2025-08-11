import 'dart:async';

import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';
import 'package:agropilot/features/connection/domain/repositories/iconnection_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

part 'device_discovery_event.dart';
part 'device_discovery_state.dart';

class DeviceDiscoveryBloc extends Bloc<DeviceDiscoveryEvent, DeviceDiscoveryState> {
  DeviceDiscoveryBloc({required final IConnectionRepository connectionRepository})
    : _connectionRepository = connectionRepository,
      super(const DeviceDiscoveryState()) {
    on<ScanStarted>(_onScanStarted);
    on<ScanStopped>(_onScanStopped);
    on<FilterChanged>(_onFilterChanged);
    on<ShowUnnamedToggled>(_onShowUnnamedToggled);
    on<_DevicesUpdated>(_onDevicesUpdated);
    on<_ScanErrorOccurred>(_onScanErrorOccurred);
  }

  final IConnectionRepository _connectionRepository;
  StreamSubscription<Either<Error, List<ConnectionDetails>>>? _scanSubscription;

  Future<void> _onScanStarted(final ScanStarted event, final Emitter<DeviceDiscoveryState> emit) async {
    // Ensure any previous scan is stopped before starting a new one.
    await _scanSubscription?.cancel();
    emit(state.copyWith(isScanning: true, allDiscoveredDevices: <ConnectionDetails>[], clearError: true));

    final Either<Error, void> result = await _connectionRepository.startScan(event.type);
    result.fold((final Error error) => add(_ScanErrorOccurred(error)), (_) {
      _scanSubscription = _connectionRepository
          .scanForDevices(event.type)
          .listen(
            (final Either<Error, List<ConnectionDetails>> either) => either.fold(
              (final Error error) => add(_ScanErrorOccurred(error)),
              (final List<ConnectionDetails> devices) => add(_DevicesUpdated(devices)),
            ),
            onError: (final Object error, final StackTrace stackTrace) {
              final StateError errorToSend = StateError('Stream error: $error\n$stackTrace');
              add(_ScanErrorOccurred(errorToSend));
            },
          );
    });
  }

  Future<void> _onScanStopped(final ScanStopped event, final Emitter<DeviceDiscoveryState> emit) async {
    // In a real scenario, you would call repository.stopScan()
    // For now, we just cancel the subscription and update the state.
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    emit(state.copyWith(isScanning: false));
  }

  void _onFilterChanged(final FilterChanged event, final Emitter<DeviceDiscoveryState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  void _onShowUnnamedToggled(final ShowUnnamedToggled event, final Emitter<DeviceDiscoveryState> emit) {
    emit(state.copyWith(showUnnamed: event.showUnnamed));
  }

  void _onDevicesUpdated(final _DevicesUpdated event, final Emitter<DeviceDiscoveryState> emit) {
    emit(state.copyWith(allDiscoveredDevices: event.devices));
  }

  void _onScanErrorOccurred(final _ScanErrorOccurred event, final Emitter<DeviceDiscoveryState> emit) {
    emit(state.copyWith(error: event.error, isScanning: false));
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    // It's good practice to also explicitly stop the scan in the hardware.
    // This requires adding a 'type' to the state or tracking it locally.
    // For now, we assume the subscription cancellation is sufficient.
    return super.close();
  }
}
