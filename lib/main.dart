import 'package:flutter/material.dart';
import 'package:onestep_imagepicker/constants/config.dart';
import 'package:onestep_imagepicker/widget/asset_picker.dart';
import 'package:photo_manager/photo_manager.dart';

const Color themeColor = Color(0xFF1056e1);

void main() {
  runApp(const MyApp());
  // SystemChrome.setSystemUIOverlayStyle(
  //   SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
  // );
  // OnestepImagePicker.registerObserve();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('onestep Imagepicker', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
          child: GestureDetector(
        onTap: () {
          OnestepImagePicker.pickAssets(
            context,
            pickerConfig: AssetPickerConfig(
              // selectedAssets: entity,
              maxAssets: 5,
              themeColor: themeColor,
              pageSize: 330,
              gridCount: 3,
              requestType: RequestType.image,

              // textDelegate: KoreanTextDelegate(),

              //   child: OneStepIcon(
              //     icondata: Icons.camera_alt_rounded,
              //     size: 42.0,
            ),
          );
        },
        child: Container(
          width: 200,
          height: 200,
          color: themeColor,
        ),
      )),
    );
  }
}
