// ignore_for_file: prefer_expression_function_bodies

import 'package:agropilot/features/connection/bloc/connections_manager_bloc/connections_manager_bloc.dart';
import 'package:agropilot/features/connection/bloc/device_discovery_bloc/device_discovery_bloc.dart';
import 'package:agropilot/features/connection/presentation/pages/connections_dashboard_page.dart';
import 'package:agropilot/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  // Убедимся, что все биндинги Flutter инициализированы
  WidgetsFlutterBinding.ensureInitialized();
  
  // Запускаем инициализацию наших зависимостей
  di.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectionsManagerBloc>(
          create: (final BuildContext context) => di.sl<ConnectionsManagerBloc>(),
        ),
        BlocProvider<DeviceDiscoveryBloc>(
          create: (final BuildContext context) => di.sl<DeviceDiscoveryBloc>(),
        ),
      ],
      child: const MaterialApp(
        title: 'AgroPilot Connection Manager',
        home: ConnectionsDashboardPage(),
      ),
    );
  }
}
