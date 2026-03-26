import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'auth_screen.dart';      


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ios_tiretest_ai/Bloc/auth_bloc.dart';
import 'package:ios_tiretest_ai/Bloc/auth_event.dart';
import 'package:ios_tiretest_ai/Screens/app_shell.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  static const _upperPath = 'assets/splash_upper_view.png';
  static const _bottomPath = 'assets/splash_bottom_view.png';
  static const _logoPath = 'assets/tiretest_logo.png';

  @override
  void initState() {
    super.initState();

    final bloc = context.read<AuthBloc>();
    bloc.add(const HomeMapBootRequested(forceRefresh: false));
    bloc.add(const PlacesPrewarmRequested());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final token = (GetStorage().read<String>('auth_token') ?? '').trim();
      final hasToken = token.isNotEmpty;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => hasToken ? const AppShell() : const AuthScreen(),
        ),
        (route) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _UpperBackground(imagePath: _upperPath),
          Align(
            alignment: const Alignment(0, -0.05),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = MediaQuery.of(context).size.width;
                final logoW = w * 0.64;
                return Image.asset(
                  _logoPath,
                  width: logoW,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                );
              },
            ),
          ),
          const _BottomDecor(imagePath: _bottomPath),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }
}

class _UpperBackground extends StatelessWidget {
  const _UpperBackground({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
    );
  }
}

class _BottomDecor extends StatelessWidget {
  const _BottomDecor({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Image.asset(
        imagePath,
        fit: BoxFit.fitWidth,
        width: MediaQuery.of(context).size.width,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}



// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
//   late final AnimationController _fadeCtrl = AnimationController(
//     vsync: this,
//     duration: const Duration(milliseconds: 600),
//   )..forward();

//   static const _upperPath  = 'assets/splash_upper_view.png';
//   static const _bottomPath = 'assets/splash_bottom_view.png';
//   static const _logoPath   = 'assets/tiretest_logo.png';

//   @override
//   void initState() {
//     super.initState();
//    final bloc = context.read<AuthBloc>();
//   bloc.add(const HomeMapBootRequested(forceRefresh: false));
//   bloc.add(const PlacesPrewarmRequested());

//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await Future.delayed(const Duration(milliseconds: 1200));
//       if (!mounted) return;

//       final token = (GetStorage().read<String>('auth_token') ?? '').trim();
//       final hasToken = token.isNotEmpty;

//       Navigator.of(context).pushAndRemoveUntil(
//         MaterialPageRoute(
//           builder: (_) => hasToken
//               ? const AppShell() //InspectionHomePixelPerfect()
//               : const AuthScreen(),
//         ),
//         (route) => false,
//       );
//     });
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
    
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           const _UpperBackground(imagePath: _upperPath),
//                 Align(
//             alignment: const Alignment(0, -0.05), 
//             child: LayoutBuilder(
//               builder: (context, c) {
//                 final w = MediaQuery.of(context).size.width;
//                 final logoW = w * 0.64;
//                 return Image.asset(
//                   _logoPath,
//                   width: logoW,
//                   fit: BoxFit.contain,
//                   filterQuality: FilterQuality.high,
//                 );
//               },
//             ),
//           ),
//                 const _BottomDecor(imagePath: _bottomPath),
//         ],
//       ),
//       backgroundColor: Colors.white, 
//     );
//   }
// }

// class _UpperBackground extends StatelessWidget {
//   const _UpperBackground({required this.imagePath});
//   final String imagePath;

//   @override
//   Widget build(BuildContext context) {
//     return Image.asset(
//       imagePath,
//       fit: BoxFit.cover,        
//       filterQuality: FilterQuality.high,
//     );
//   }
// }

// class _BottomDecor extends StatelessWidget {
//   const _BottomDecor({required this.imagePath});
//   final String imagePath;

//   @override
//   Widget build(BuildContext context) {
//     return Positioned(
//       left: 0, right: 0, bottom: 0,
//       child: Image.asset(
//         imagePath,
//         fit: BoxFit.fitWidth,        
//         width: MediaQuery.of(context).size.width,
//         filterQuality: FilterQuality.high,
//       ),
//     );
//   }
// }

