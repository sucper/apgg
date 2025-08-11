// ignore_for_file: prefer_expression_function_bodies
// ignore_for_file: cascade_invocations

import 'dart:convert';
import 'dart:typed_data';

import 'package:agropilot/features/connection/bloc/connection_bloc/connection_bloc.dart';
import 'package:agropilot/features/connection/bloc/connections_manager_bloc/connections_manager_bloc.dart';
import 'package:agropilot/features/connection/bloc/device_discovery_bloc/device_discovery_bloc.dart';
import 'package:agropilot/features/connection/domain/entities/connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/connection_status.dart';
import 'package:agropilot/features/connection/domain/entities/connection_type.dart';
import 'package:agropilot/features/connection/domain/entities/tcp_connection_details.dart';
import 'package:agropilot/features/connection/domain/entities/udp_connection_details.dart';
import 'package:agropilot/features/parsing/domain/entities/parser_type.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_bloc/flutter_bloc.dart';

class ConnectionsDashboardPage extends StatefulWidget {
  const ConnectionsDashboardPage({super.key});

  @override
  State<ConnectionsDashboardPage> createState() => _ConnectionsDashboardPageState();
}

class _ConnectionsDashboardPageState extends State<ConnectionsDashboardPage> {
  final Map<String, TextEditingController> _dataSendControllers = <String, TextEditingController>{};

  @override
  void dispose() {
    _dataSendControllers.forEach((_, final TextEditingController controller) => controller.dispose());
    super.dispose();
  }

  void _showAddConnectionModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // Provide BLoCs to the sheet
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<ConnectionsManagerBloc>.value(value: BlocProvider.of<ConnectionsManagerBloc>(context)),
          BlocProvider<DeviceDiscoveryBloc>.value(value: BlocProvider.of<DeviceDiscoveryBloc>(context)),
        ],
        child: const _AddConnectionSheet(),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Manager')),
      body: BlocBuilder<ConnectionsManagerBloc, ConnectionsManagerState>(
        builder: (final BuildContext context, final ConnectionsManagerState managerState) {
          if (managerState.activeConnections.isEmpty) {
            return const Center(child: Text('No connections. Press + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: managerState.activeConnections.length,
            itemBuilder: (final BuildContext context, final int index) {
              final ConnectionBloc connectionBloc = managerState.activeConnections[index];
              _dataSendControllers.putIfAbsent(connectionBloc.state.details.id, () => TextEditingController());
              return BlocProvider<ConnectionBloc>.value(
                value: connectionBloc,
                child: _ConnectionCard(sendController: _dataSendControllers[connectionBloc.state.details.id]!),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddConnectionModal, child: const Icon(Icons.add)),
    );
  }
}

// --- Card Widget to display a single connection ---
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.sendController});
  final TextEditingController sendController;

  @override
  Widget build(final BuildContext context) {
    return BlocBuilder<ConnectionBloc, ConnectionState>(
      builder: (final BuildContext context, final ConnectionState state) {
        final bool isConnected = state.status == ConnectionStatus.connected;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, state.details),
                const SizedBox(height: 8),
                _buildStatus(context, state.status, state.error?.toString()),
                const SizedBox(height: 8),
                _buildActionButtons(context, isConnected),
                const SizedBox(height: 8),
                _buildSendData(context, sendController, isConnected),
                const SizedBox(height: 12),
                _buildReceivedData(context, state.receivedMessages),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(final BuildContext context, final ConnectionDetails details) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(details.name, style: Theme.of(context).textTheme.titleLarge),
              Text('Type: ${details.type.name.toUpperCase()}', style: Theme.of(context).textTheme.bodySmall),
              if (details is TcpConnectionDetails)
                Text('Target: ${details.host}:${details.port}', style: Theme.of(context).textTheme.bodySmall),
              if (details is UdpConnectionDetails)
                Text(
                  'Bind: ${details.bindHost}:${details.bindPort} -> Send: ${details.host}:${details.port}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => context.read<ConnectionsManagerBloc>().add(ConnectionRemoved(details.id)),
        ),
      ],
    );
  }

  Widget _buildStatus(final BuildContext context, final ConnectionStatus status, final String? errorMessage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _StatusIndicator(status: status),
            const SizedBox(width: 8),
            Text(
              status.name.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: _getStatusColor(status), fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (errorMessage != null && errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text('Error: $errorMessage', style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildActionButtons(final BuildContext context, final bool isConnected) {
    final ConnectionBloc bloc = context.read<ConnectionBloc>();
    return Row(
      children: <Widget>[
        ElevatedButton(
          onPressed: () {
            if (isConnected) {
              bloc.add(DisconnectRequested());
            } else {
              bloc.add(ConnectRequested());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: isConnected ? Colors.orange : Colors.green),
          child: Text(isConnected ? 'Disconnect' : 'Connect'),
        ),
      ],
    );
  }

  Widget _buildSendData(final BuildContext context, final TextEditingController controller, final bool isConnected) {
    final ConnectionBloc bloc = context.read<ConnectionBloc>();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isConnected,
              decoration: const InputDecoration(hintText: 'Send data', isDense: true),
              onSubmitted: (final String value) {
                if (value.isNotEmpty && isConnected) {
                  bloc.add(DataSent(Uint8List.fromList(utf8.encode(value))));
                  controller.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: isConnected
                ? () {
                    final String data = controller.text;
                    if (data.isNotEmpty) {
                      bloc.add(DataSent(Uint8List.fromList(utf8.encode(data))));
                      controller.clear();
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedData(final BuildContext context, final List<String> receivedData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Received Data:', style: Theme.of(context).textTheme.titleSmall),
        Container(
          height: 100,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade50,
          ),
          child: receivedData.isEmpty
              ? const Text('No data received.', style: TextStyle(color: Colors.grey))
              : ListView.builder(
                  reverse: true,
                  itemCount: receivedData.length,
                  itemBuilder: (final BuildContext context, final int index) {
                    final String message = receivedData[receivedData.length - 1 - index];
                    return Text(
                      message,
                      style: TextStyle(color: message.startsWith('>>') ? Colors.blue.shade800 : Colors.black),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(final ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.blueGrey;
      case ConnectionStatus.error:
        return Colors.red;
    }
  }
}

// --- Modal Bottom Sheet for adding a new connection ---

enum _SheetPage { configuration, discovery }

class _AddConnectionSheet extends StatefulWidget {
  const _AddConnectionSheet();

  @override
  State<_AddConnectionSheet> createState() => _AddConnectionSheetState();
}

class _AddConnectionSheetState extends State<_AddConnectionSheet> {
  _SheetPage _currentPage = _SheetPage.configuration;
  ConnectionType _selectedType = ConnectionType.tcp;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _tcpHostController = TextEditingController(text: '10.0.2.2');
  final TextEditingController _tcpPortController = TextEditingController(text: '8888');
  final TextEditingController _udpRemoteHostController = TextEditingController(text: '10.0.2.2');
  final TextEditingController _udpRemotePortController = TextEditingController(text: '9999');

  @override
  void initState() {
    super.initState();
    _updateDefaultName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tcpHostController.dispose();
    _tcpPortController.dispose();
    _udpRemoteHostController.dispose();
    _udpRemotePortController.dispose();
    super.dispose();
  }

  void _updateDefaultName() {
    _nameController.text = '${_selectedType.name.toUpperCase()} Connection';
  }

  void _onAddConnection() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    ConnectionDetails? details;
    if (_selectedType == ConnectionType.tcp) {
      details = TcpConnectionDetails(
        name: name,
        host: _tcpHostController.text.trim(),
        port: int.parse(_tcpPortController.text.trim()),
        parserType: ParserType.unknown,
      );
    } else if (_selectedType == ConnectionType.udp) {
      details = UdpConnectionDetails(
        name: name,
        host: _udpRemoteHostController.text.trim(),
        port: int.parse(_udpRemotePortController.text.trim()),
        parserType: ParserType.unknown,
      );
    }
    if (details != null) {
      context.read<ConnectionsManagerBloc>().add(ConnectionAdded(details));
      Navigator.of(context).pop();
    }
  }

  void _onFindDevices() {
    context.read<DeviceDiscoveryBloc>().add(ScanStarted(_selectedType));
    setState(() {
      _currentPage = _SheetPage.discovery;
    });
  }

  @override
  Widget build(final BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (final Widget child, final Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(animation),
            child: child,
          );
        },
        child: _currentPage == _SheetPage.configuration ? _buildConfigurationPage() : _buildDiscoveryPage(),
      ),
    );
  }

  Widget _buildConfigurationPage() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Add New Connection', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          DropdownButtonFormField<ConnectionType>(
            value: _selectedType,
            items: ConnectionType.values
                .map(
                  (final ConnectionType type) =>
                      DropdownMenuItem<ConnectionType>(value: type, child: Text(type.name.toUpperCase())),
                )
                .toList(),
            onChanged: (final ConnectionType? type) {
              if (type == null) return;
              setState(() {
                _selectedType = type;
                _updateDefaultName();
              });
            },
            decoration: const InputDecoration(labelText: 'Connection Type', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          ..._buildConfigFields(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildConfigFields() {
    final bool isScannable = _selectedType == ConnectionType.ble || _selectedType == ConnectionType.serial;
    final List<Widget> fields = <Widget>[
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Connection Name', border: OutlineInputBorder()),
        validator: (final String? v) => (v?.isEmpty ?? true) ? 'Required' : null,
      ),
      const SizedBox(height: 16),
    ];
    if (_selectedType == ConnectionType.tcp) {
      fields.addAll(<Widget>[
        TextFormField(
          controller: _tcpHostController,
          decoration: const InputDecoration(labelText: 'Host IP', border: OutlineInputBorder()),
          validator: (final String? v) => (v?.isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tcpPortController,
          decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          validator: (final String? v) => (v?.isEmpty ?? true) ? 'Required' : null,
        ),
      ]);
    } else if (_selectedType == ConnectionType.udp) {
      fields.addAll(<Widget>[
        TextFormField(
          controller: _udpRemoteHostController,
          decoration: const InputDecoration(labelText: 'Remote Host IP (Send)', border: OutlineInputBorder()),
          validator: (final String? v) => (v?.isEmpty ?? true) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _udpRemotePortController,
          decoration: const InputDecoration(labelText: 'Remote Port (Send)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          validator: (final String? v) => (v?.isEmpty ?? true) ? 'Required' : null,
        ),
      ]);
    }
    fields.add(const SizedBox(height: 16));
    fields.add(
      ElevatedButton(
        onPressed: isScannable ? _onFindDevices : _onAddConnection,
        child: Text(isScannable ? 'Find Devices' : 'Add Connection'),
      ),
    );
    return fields;
  }

  Widget _buildDiscoveryPage() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.read<DeviceDiscoveryBloc>().add(ScanStopped());
                setState(() => _currentPage = _SheetPage.configuration);
              },
            ),
            Expanded(
              child: Text(
                'Discovering ${_selectedType.name.toUpperCase()}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48), // to balance the back button
          ],
        ),
        const SizedBox(height: 8),
        _buildDiscoveryControls(),
        const Divider(),
        Expanded(
          child: BlocConsumer<DeviceDiscoveryBloc, DeviceDiscoveryState>(
            listener: (final BuildContext context, final DeviceDiscoveryState state) {
              if (state.error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Scan Error: ${state.error}'), backgroundColor: Colors.red));
              }
            },
            builder: (final BuildContext context, final DeviceDiscoveryState state) {
              if (state.isScanning && state.filteredDevices.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.filteredDevices.isEmpty) {
                return const Center(child: Text('No devices found. Try scanning again.'));
              }
              return ListView.builder(
                itemCount: state.filteredDevices.length,
                itemBuilder: (final BuildContext context, final int index) {
                  final ConnectionDetails device = state.filteredDevices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    onTap: () {
                      context.read<ConnectionsManagerBloc>().add(ConnectionAdded(device));
                      Navigator.of(context).pop();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryControls() {
    final DeviceDiscoveryBloc discoveryBloc = context.read<DeviceDiscoveryBloc>();
    final bool isScanning = context.select((final DeviceDiscoveryBloc bloc) => bloc.state.isScanning);

    if (_selectedType == ConnectionType.ble) {
      return ElevatedButton.icon(
        icon: Icon(isScanning ? Icons.stop : Icons.search),
        label: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
        onPressed: () {
          if (isScanning) {
            discoveryBloc.add(ScanStopped());
          } else {
            discoveryBloc.add(ScanStarted(_selectedType));
          }
        },
      );
    } else if (_selectedType == ConnectionType.serial) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
        onPressed: () => discoveryBloc.add(ScanStarted(_selectedType)),
      );
    }
    return const SizedBox.shrink();
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});
  final ConnectionStatus status;

  @override
  Widget build(final BuildContext context) {
    Color color;
    switch (status) {
      case ConnectionStatus.connected:
        color = Colors.green;
      case ConnectionStatus.connecting:
        color = Colors.orange;
      case ConnectionStatus.disconnected:
        color = Colors.blueGrey;
      case ConnectionStatus.error:
        color = Colors.red;
    }
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
