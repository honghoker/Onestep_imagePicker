import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onestep_imagepicker/widget/asset_picker_page_route.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../constants/config.dart';
import '../../constants/constants.dart';
import '../../delegates/asset_picker_builder_delegate.dart';
import '../../internal/methods.dart';
import '../../internal/singleton.dart';
import '../../provider/asset_picker_provider.dart';

class OnestepImagePicker<Asset, Path> extends StatefulWidget {
  const OnestepImagePicker({Key? key, required this.builder}) : super(key: key);

  final AssetPickerBuilderDelegate<Asset, Path> builder;

  static Future<PermissionState> permissionCheck() async {
    final PermissionState _ps = await PhotoManager.requestPermissionExtend();
    if (_ps != PermissionState.authorized && _ps != PermissionState.limited) {
      throw StateError('Permission state error with $_ps.');
    }
    return _ps;
  }

  /// Static method to push with the navigator.
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
    bool useRootNavigator = true,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
  }) async {
    final PermissionState _ps = await permissionCheck();
    final DefaultAssetPickerProvider provider = DefaultAssetPickerProvider(
      maxAssets: pickerConfig.maxAssets,
      pageSize: pickerConfig.pageSize,
      pathThumbnailSize: pickerConfig.pathThumbnailSize,
      selectedAssets: pickerConfig.selectedAssets,
      requestType: pickerConfig.requestType,
      sortPathDelegate: pickerConfig.sortPathDelegate,
      filterOptions: pickerConfig.filterOptions,
    );
    final Widget picker = OnestepImagePicker<AssetEntity, AssetPathEntity>(
      key: Singleton.pickerKey,
      builder: DefaultAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: _ps,
        gridCount: pickerConfig.gridCount,
        pickerTheme: pickerConfig.pickerTheme,
        gridThumbnailSize: pickerConfig.gridThumbnailSize,
        previewThumbnailSize: pickerConfig.previewThumbnailSize,
        specialPickerType: pickerConfig.specialPickerType,
        specialItemPosition: pickerConfig.specialItemPosition,
        specialItemBuilder: pickerConfig.specialItemBuilder,
        loadingIndicatorBuilder: pickerConfig.loadingIndicatorBuilder,
        allowSpecialItemWhenEmpty: pickerConfig.allowSpecialItemWhenEmpty,
        selectPredicate: pickerConfig.selectPredicate,
        shouldRevertGrid: pickerConfig.shouldRevertGrid,
        textDelegate: pickerConfig.textDelegate,
        themeColor: pickerConfig.themeColor,
        locale: Localizations.maybeLocaleOf(context),
      ),
    );
    final List<AssetEntity>? result = await Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).push<List<AssetEntity>>(
      pageRouteBuilder?.call(picker) ??
          ImagePickerPageRoute<List<AssetEntity>>(builder: (_) => picker),
    );
    return result;
  }

  static Future<List<Asset>?> pickAssetsWithDelegate<Asset, Path,
      PickerProvider extends AssetPickerProvider<Asset, Path>>(
    BuildContext context, {
    required AssetPickerBuilderDelegate<Asset, Path> delegate,
    bool useRootNavigator = true,
    AssetPickerPageRouteBuilder<List<Asset>>? pageRouteBuilder,
  }) async {
    await permissionCheck();

    final Widget picker = OnestepImagePicker<Asset, Path>(
      key: Singleton.pickerKey,
      builder: delegate,
    );
    final List<Asset>? result = await Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).push<List<Asset>>(
      pageRouteBuilder?.call(picker) ??
          ImagePickerPageRoute<List<Asset>>(builder: (_) => picker),
    );
    return result;
  }

  /// Register observe callback with assets changes.
  static void registerObserve([ValueChanged<MethodCall>? callback]) {
    if (callback == null) {
      return;
    }
    try {
      PhotoManager.addChangeCallback(callback);
      PhotoManager.startChangeNotify();
    } catch (e) {
      realDebugPrint('Error when registering assets callback: $e');
    }
  }

  /// Unregister the observation callback with assets changes.
  static void unregisterObserve([ValueChanged<MethodCall>? callback]) {
    if (callback == null) {
      return;
    }
    try {
      PhotoManager.removeChangeCallback(callback);
      PhotoManager.stopChangeNotify();
    } catch (e) {
      realDebugPrint('Error when unregistering assets callback: $e');
    }
  }

  /// Build a dark theme according to the theme color.
  static ThemeData themeData(Color? themeColor, {bool light = true}) {
    themeColor ??= defaultThemeColorWeChat;
    if (light) {
      return ThemeData.light().copyWith(
        primaryColor: Colors.grey[50],
        primaryColorLight: Colors.grey[50],
        primaryColorDark: Colors.grey[50],
        canvasColor: Colors.grey[100],
        scaffoldBackgroundColor: Colors.grey[50],
        bottomAppBarColor: Colors.grey[50],
        cardColor: Colors.grey[50],
        highlightColor: Colors.transparent,
        toggleableActiveColor: themeColor,
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: themeColor,
          selectionColor: themeColor.withAlpha(100),
          selectionHandleColor: themeColor,
        ),
        indicatorColor: themeColor,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          elevation: 0,
        ),
        buttonTheme: ButtonThemeData(buttonColor: themeColor),
        colorScheme: ColorScheme(
          primary: Colors.grey[50]!,
          primaryVariant: Colors.grey[50]!,
          secondary: themeColor,
          secondaryVariant: themeColor,
          background: Colors.grey[50]!,
          surface: Colors.grey[50]!,
          brightness: Brightness.light,
          error: const Color(0xffcf6679),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: Colors.white,
        ),
      );
    }
    return ThemeData.dark().copyWith(
      primaryColor: Colors.grey[900],
      primaryColorLight: Colors.grey[900],
      primaryColorDark: Colors.grey[900],
      canvasColor: Colors.grey[850],
      scaffoldBackgroundColor: Colors.grey[900],
      bottomAppBarColor: Colors.grey[900],
      cardColor: Colors.grey[900],
      highlightColor: Colors.transparent,
      toggleableActiveColor: themeColor,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: themeColor,
        selectionColor: themeColor.withAlpha(100),
        selectionHandleColor: themeColor,
      ),
      indicatorColor: themeColor,
      appBarTheme: const AppBarTheme(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        elevation: 0,
      ),
      buttonTheme: ButtonThemeData(buttonColor: themeColor),
      colorScheme: ColorScheme(
        primary: Colors.grey[900]!,
        primaryVariant: Colors.grey[900]!,
        secondary: themeColor,
        secondaryVariant: themeColor,
        background: Colors.grey[900]!,
        surface: Colors.grey[900]!,
        brightness: Brightness.dark,
        error: const Color(0xffcf6679),
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.black,
      ),
    );
  }

  @override
  OnestepImagePickerState<Asset, Path> createState() =>
      OnestepImagePickerState<Asset, Path>();
}

class OnestepImagePickerState<Asset, Path>
    extends State<OnestepImagePicker<Asset, Path>>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    OnestepImagePicker.registerObserve(_onLimitedAssetsUpdated);
    widget.builder.initState(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      PhotoManager.requestPermissionExtend().then(
        (PermissionState ps) => widget.builder.permission.value = ps,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    OnestepImagePicker.unregisterObserve(_onLimitedAssetsUpdated);
    widget.builder.dispose();
    super.dispose();
  }

  Future<void> _onLimitedAssetsUpdated(MethodCall call) async {
    await widget.builder.onAssetsChanged(
      call,
      (VoidCallback fn) {
        fn();
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder.build(context);
  }
}
