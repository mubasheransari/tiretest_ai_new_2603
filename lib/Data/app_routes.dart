import 'package:flutter/material.dart';
import 'package:ios_tiretest_ai/Screens/home_screen.dart';
import 'package:ios_tiretest_ai/Screens/report_history_screen.dart';
import 'package:ios_tiretest_ai/Screens/sponser_vendors_screen.dart';



class AppRoutes {
  static const home    = '/';
  static const reports = '/reports';
  static const map     = '/map';
  static const about   = '/about';
  static const profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case reports:
        return _page( ReportHistoryScreen());
      case map:
        return _page( ReportHistoryScreen());
      case about:
        return _page( SponsoredVendorsScreen());
      case profile:
        return _page( ReportHistoryScreen());
      case home:
      default:
        return _page(const InspectionHomePixelPerfect());
    }
  }

  static MaterialPageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child, settings: RouteSettings(name: child.runtimeType.toString()));
}
