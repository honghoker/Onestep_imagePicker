import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onestep_imagepicker/widget/asset_picker.dart';

const Color themeColor = Color(0xFF1056e1);

void main() {
  runApp(const MyApp());
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  );
  AssetPicker.registerObserve();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'onestep Imagepicker', home: AppMain());
  }
}

class AppMain extends StatefulWidget {
  AppMain({Key? key}) : super(key: key);

  @override
  State<AppMain> createState() => _AppMainState();
}

class _AppMainState extends State<AppMain> {
  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}
