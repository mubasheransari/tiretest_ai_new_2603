import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Bloc/auth_state.dart';
import 'package:ios_tiretest_ai/Data/app_routes.dart';
import 'package:ios_tiretest_ai/Repository/repository.dart';
import 'package:ios_tiretest_ai/Screens/auth_screen.dart';
import 'package:ios_tiretest_ai/Screens/splash_screen.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await GetStorage.init();

//   final authRepo = AuthRepositoryHttp();

//   runApp(
//     MultiBlocProvider(
//       providers: [
//         BlocProvider<AuthBloc>(
//           create: (_) => AuthBloc(authRepo)..add(const AppStarted()),
//         ),
//       ],
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Taskoon App',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         colorSchemeSeed: Colors.deepPurple,
//       ),
//       // Named routes used by the bottom bar:
//       onGenerateRoute: AppRoutes.onGenerateRoute,
//       // AuthGate decides which first screen to render:
//       home: const AuthGate(),
//     );
//   }
// }

// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final box   = GetStorage();
//     final token = (box.read<String>('auth_token') ?? '').trim();
//     if (token.isEmpty) return const AuthScreen();

//     return BlocBuilder<AuthBloc, AuthState>(
//       buildWhen: (p, c) => p.profileStatus != c.profileStatus,
//       builder: (context, state) {
//         switch (state.profileStatus) {
//           case ProfileStatus.success:
//             return const SplashScreen(); 
//           case ProfileStatus.failure:
//             return const SplashScreen();
//           case ProfileStatus.initial:
//           case ProfileStatus.loading:
//           default:
//             return const SplashScreen();
//         }
//       },
//     );
//   }
// }



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  final authRepo = AuthRepositoryHttp();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authRepo)..add(const AppStarted()),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskoon App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    final token = (box.read<String>('auth_token') ?? '').trim();
    if (token.isEmpty) return const AuthScreen();

    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (p, c) => p.profileStatus != c.profileStatus,
      builder: (context, state) {
        switch (state.profileStatus) {
          case ProfileStatus.success:
            return const SplashScreen();
          case ProfileStatus.failure:
            return const SplashScreen();
          case ProfileStatus.initial:
          case ProfileStatus.loading:
          default:
            return const SplashScreen();
        }
      },
    );
  }
}