///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2020-10-29 21:50
///
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:onestep_imagepicker/widget/asset_picker.dart';
import 'package:onestep_imagepicker/widget/asset_picker_viewer.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../constants/constants.dart';
import '../constants/enums.dart';
import '../constants/extensions.dart';
import '../delegates/asset_picker_text_delegate.dart';
import '../internal/singleton.dart';
import '../provider/asset_picker_provider.dart';
import '../widget/asset_picker_app_bar.dart';
import '../widget/builder/asset_entity_grid_item_builder.dart';
import '../widget/builder/value_listenable_builder_2.dart';
import '../widget/gaps.dart';
import '../widget/platform_progress_indicator.dart';
import '../widget/scale_text.dart';

const String _ordinalNamePermissionOverlay = 'permissionOverlay';

typedef IndicatorBuilder = Widget Function(
  BuildContext context,
  bool isAssetsEmpty,
);

/// {@template wechat_assets_picker.AssetSelectPredicate}
/// Predicate whether an asset can be selected or unselected.
/// {@endtemplate}
typedef AssetSelectPredicate<Asset> = FutureOr<bool> Function(
  BuildContext context,
  Asset asset,
  bool isSelected,
);

/// The delegate to build the whole picker's components.
///
/// By extending the delegate, you can customize every components on you own.
/// Delegate requires two generic types:
///  * [Asset] The type of your assets. Defaults to [AssetEntity].
///  * [Path] The type of your paths. Defaults to [AssetPathEntity].
abstract class AssetPickerBuilderDelegate<Asset, Path> {
  AssetPickerBuilderDelegate({
    required this.initialPermission,
    this.gridCount = 4,
    this.pickerTheme,
    this.specialItemPosition = SpecialItemPosition.none,
    this.specialItemBuilder,
    this.loadingIndicatorBuilder,
    this.allowSpecialItemWhenEmpty = false,
    this.selectPredicate,
    this.shouldRevertGrid,
    Color? themeColor,
    AssetPickerTextDelegate? textDelegate,
    Locale? locale,
  })  : assert(
          pickerTheme == null || themeColor == null,
          'Theme and theme color cannot be set at the same time.',
        ),
        themeColor = pickerTheme?.colorScheme.secondary ??
            themeColor ??
            defaultThemeColorWeChat {
    Singleton.textDelegate =
        textDelegate ?? assetPickerTextDelegateFromLocale(locale);
  }

  /// The [PermissionState] when the picker is called.
  final PermissionState initialPermission;

  /// Assets count for the picker.
  final int gridCount;

  /// Main color for the picker.
  final Color? themeColor;

  /// Theme for the picker.
  ///
  /// Usually the WeChat uses the dark version (dark background color)
  /// for the picker. However, some others want a light or a custom version.
  ///
  final ThemeData? pickerTheme;

  /// Allow users set a special item in the picker with several positions.
  final SpecialItemPosition specialItemPosition;

  /// The widget builder for the the special item.
  final WidgetBuilder? specialItemBuilder;

  /// Indicates the loading status for the builder.
  final IndicatorBuilder? loadingIndicatorBuilder;

  /// Whether the special item will display or not when assets is empty.
  final bool allowSpecialItemWhenEmpty;

  /// {@macro wechat_assets_picker.AssetSelectPredicate}
  final AssetSelectPredicate<Asset>? selectPredicate;

  /// The [ScrollController] for the preview grid.
  final ScrollController gridScrollController = ScrollController();

  /// If path switcher opened.
  final ValueNotifier<bool> isSwitchingPath = ValueNotifier<bool>(false);

  /// The [GlobalKey] for [assetsGridBuilder] to locate the [ScrollView.center].
  /// [assetsGridBuilder] 用于定位 [ScrollView.center] 的 [GlobalKey]
  final GlobalKey gridRevertKey = GlobalKey();

  /// Whether the assets grid should revert.
  ///
  /// [Null] means judging by [isAppleOS].
  final bool? shouldRevertGrid;

  /// [ThemeData] for the picker.
  ThemeData get theme =>
      pickerTheme ?? OnestepImagePicker.themeData(themeColor);

  /// Return a system ui overlay style according to
  /// the brightness of the theme data.
  SystemUiOverlayStyle get overlayStyle =>
      theme.appBarTheme.systemOverlayStyle ??
      (theme.effectiveBrightness.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark);

  /// The color for interactive texts.
  Color interactiveTextColor(BuildContext context) => Color.lerp(
        context.themeData.iconTheme.color?.withOpacity(.7) ?? Colors.white,
        Colors.blueAccent,
        0.4,
      )!;

  /// Whether the current platform is Apple OS.
  bool get isAppleOS => Platform.isIOS || Platform.isMacOS;

  /// Whether the picker is under the single asset mode.
  bool get isSingleAssetMode;

  /// Space between assets item widget.
  double get itemSpacing => 2;

  /// Item's height in app bar.
  double get appBarItemHeight => 32;

  /// Blur radius in Apple OS layout mode.
  double get appleOSBlurRadius => 10;

  /// Height for the bottom occupied section.
  double get bottomSectionHeight =>
      bottomActionBarHeight + permissionLimitedBarHeight;

  /// Height for bottom action bar.
  double get bottomActionBarHeight => kToolbarHeight / 1.1;

  /// Height for the permission limited bar.
  double get permissionLimitedBarHeight => isPermissionLimited ? 75 : 0;

  /// Notifier for the current [PermissionState].
  late final ValueNotifier<PermissionState> permission =
      ValueNotifier<PermissionState>(
    initialPermission,
  );
  final ValueNotifier<bool> permissionOverlayHidden =
      ValueNotifier<bool>(false);

  /// Whether the permission is limited currently.
  bool get isPermissionLimited => permission.value == PermissionState.limited;

  bool get effectiveShouldRevertGrid => shouldRevertGrid ?? isAppleOS;

  AssetPickerTextDelegate get textDelegate => Singleton.textDelegate;

  AssetPickerTextDelegate get semanticsTextDelegate =>
      Singleton.textDelegate.semanticsTextDelegate;

  /// Keep a `initState` method to sync with [State].
  @mustCallSuper
  void initState(OnestepImagePickerState<Asset, Path> state) {}

  /// Keep a `dispose` method to sync with [State].
  @mustCallSuper
  void dispose() {
    Singleton.scrollPosition = null;
    gridScrollController.dispose();
    isSwitchingPath.dispose();
    permission.dispose();
    permissionOverlayHidden.dispose();
  }

  /// The method to select assets. Delegates can implement this method
  /// to involve with predications, callbacks, etc.
  @protected
  void selectAsset(BuildContext context, Asset asset, bool selected);

  /// Called when assets changed and obtained notifications from the OS.
  Future<void> onAssetsChanged(MethodCall call, StateSetter setState) async {}

  /// Yes, the build method.
  Widget build(BuildContext context);

  /// Path entity select widget builder.
  Widget pathEntitySelector(BuildContext context);

  /// Item widgets for path entity selector.
  Widget pathEntityWidget({
    required BuildContext context,
    required Map<Path, Uint8List?> list,
    required int index,
    bool isAudio = false,
  });

  /// A backdrop widget behind the [pathEntityListWidget].
  ///
  /// While the picker is switching path, this will displayed.
  /// If the user tapped on it, it'll collapse the list widget.
  ///
  Widget pathEntityListBackdrop(BuildContext context);

  /// List widget for path entities.
  Widget pathEntityListWidget(BuildContext context);

  /// Confirm button.
  Widget confirmButton(BuildContext context);

  /// Audio asset type indicator.
  Widget audioIndicator(BuildContext context, Asset asset);

  /// Video asset type indicator.
  Widget videoIndicator(BuildContext context, Asset asset);

  /// Animated backdrop widget for items.
  Widget selectedBackdrop(
    BuildContext context,
    int index,
    Asset asset,
  );

  /// Indicator for assets selected status.
  Widget selectIndicator(BuildContext context, int index, Asset asset);

  /// The main grid view builder for assets.
  Widget assetsGridBuilder(BuildContext context);

  /// Indicates how would the grid found a reusable [RenderObject] through [id].
  ///
  /// See also:
  ///  * [SliverChildBuilderDelegate.findChildIndexCallback].
  int? findChildIndexBuilder({
    required String id,
    required List<Asset> assets,
    int placeholderCount = 0,
  }) =>
      null;

  /// The function which return items count for the assets' grid.
  int assetsGridItemCount({
    required BuildContext context,
    required List<Asset> assets,
    int placeholderCount = 0,
  });

  /// The item builder for the assets' grid.
  Widget assetGridItemBuilder(
    BuildContext context,
    int index,
    List<Asset> currentAssets,
  );

  /// The [Semantics] builder for the assets' grid.
  Widget assetGridItemSemanticsBuilder(
    BuildContext context,
    int index,
    Asset asset,
    Widget child,
  );

  /// The item builder for audio type of asset.
  Widget audioItemBuilder(
    BuildContext context,
    int index,
    Asset asset,
  );

  /// The item builder for images and video type of asset.
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    Asset asset,
  );

  /// Preview button to preview selected assets.
  Widget previewButton(BuildContext context);

  /// Custom app bar for the picker.
  PreferredSizeWidget appBar(BuildContext context);

  /// Layout for Apple OS devices.
  Widget appleOSLayout(BuildContext context);

  /// Layout for Android devices.
  Widget androidLayout(BuildContext context);

  /// GIF image type indicator.
  Widget gifIndicator(BuildContext context, Asset asset) {
    return PositionedDirectional(
      start: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: <Color>[theme.dividerColor, Colors.transparent],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: !isAppleOS
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: theme.iconTheme.color!.withOpacity(0.75),
                )
              : null,
          child: ScaleText(
            textDelegate.gifIndicator,
            style: TextStyle(
              color: isAppleOS
                  ? theme.textTheme.bodyText2?.color
                  : theme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            semanticsLabel: semanticsTextDelegate.gifIndicator,
            strutStyle: const StrutStyle(forceStrutHeight: true, height: 1),
          ),
        ),
      ),
    );
  }

  /// Indicator when the asset cannot be selected.
  Widget itemBannedIndicator(BuildContext context, Asset asset) {
    return Consumer<AssetPickerProvider<Asset, Path>>(
      builder: (_, AssetPickerProvider<Asset, Path> p, __) {
        if (!p.selectedAssets.contains(asset) && p.selectedMaximumAssets) {
          return Container(
            color: theme.colorScheme.background.withOpacity(.85),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// Loading indicator.
  Widget loadingIndicator(BuildContext context) {
    return Center(
      child: Selector<AssetPickerProvider<Asset, Path>, bool>(
        selector: (_, AssetPickerProvider<Asset, Path> p) => p.isAssetsEmpty,
        builder: (BuildContext c, bool isAssetsEmpty, Widget? w) {
          if (loadingIndicatorBuilder != null) {
            return loadingIndicatorBuilder!(c, isAssetsEmpty);
          }
          if (isAssetsEmpty) {
            return ScaleText(
              textDelegate.emptyList,
              maxScaleFactor: 1.5,
              semanticsLabel: semanticsTextDelegate.emptyList,
            );
          }
          return w!;
        },
        child: PlatformProgressIndicator(
          color: theme.iconTheme.color,
          size: context.mediaQuery.size.width / gridCount / 3,
        ),
      ),
    );
  }

  /// Item widgets when the thumb data load failed.
  Widget failedItemBuilder(BuildContext context) {
    return Center(
      child: ScaleText(
        textDelegate.loadFailed,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18),
        semanticsLabel: semanticsTextDelegate.loadFailed,
      ),
    );
  }

  /// The effective direction for the assets grid.
  ///
  /// By default, the direction will be reversed if it's iOS/macOS.
  TextDirection effectiveGridDirection(BuildContext context) {
    final TextDirection _od = Directionality.of(context);
    if (effectiveShouldRevertGrid) {
      if (_od == TextDirection.ltr) {
        return TextDirection.rtl;
      }
      return TextDirection.ltr;
    }
    return _od;
  }

  /// The tip widget displays when the access is limited.
  Widget accessLimitedBottomTip(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Feedback.forTap(context);
        PhotoManager.openSetting();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: permissionLimitedBarHeight,
        color: theme.primaryColor.withOpacity(isAppleOS ? 0.90 : 1),
        child: Row(
          children: <Widget>[
            const SizedBox(width: 5),
            Icon(
              Icons.warning,
              color: Colors.orange[400]!.withOpacity(.8),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ScaleText(
                textDelegate.accessAllTip,
                style: context.themeData.textTheme.caption?.copyWith(
                  fontSize: 14,
                ),
                semanticsLabel: semanticsTextDelegate.accessAllTip,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_right,
              color: context.themeData.iconTheme.color?.withOpacity(.5),
            ),
          ],
        ),
      ),
    );
  }

  /// Action bar widget aligned to bottom.
  Widget bottomActionBar(BuildContext context) {
    Widget child = Container(
      height: bottomActionBarHeight + context.bottomPadding,
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(
        bottom: context.bottomPadding,
      ),
      color: theme.primaryColor.withOpacity(isAppleOS ? 0.90 : 1),
      child: Row(
        children: <Widget>[
          if (!isSingleAssetMode || !isAppleOS) previewButton(context),
          if (isAppleOS) const Spacer(),
          if (isAppleOS) confirmButton(context),
        ],
      ),
    );
    if (isPermissionLimited) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[accessLimitedBottomTip(context), child],
      );
    }
    child = ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: appleOSBlurRadius,
          sigmaY: appleOSBlurRadius,
        ),
        child: child,
      ),
    );
    return child;
  }

  /// Back button.
  Widget backButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IconButton(
        onPressed: Navigator.of(context).maybePop,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    );
  }

  /// The overlay when the permission is limited on iOS.
  Widget iOSPermissionOverlay(BuildContext context) {
    final Size size = context.mediaQuery.size;
    final Widget _closeButton = Container(
      margin: const EdgeInsetsDirectional.only(start: 16, top: 4),
      alignment: AlignmentDirectional.centerStart,
      child: IconButton(
        onPressed: Navigator.of(context).maybePop,
        icon: const Icon(Icons.close),
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tight(const Size.square(32)),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
    );

    final Widget _limitedTips = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ScaleText(
            textDelegate.unableToAccessAll,
            style: const TextStyle(fontSize: 22),
            textAlign: TextAlign.center,
            semanticsLabel: semanticsTextDelegate.unableToAccessAll,
          ),
          SizedBox(height: size.height / 30),
          ScaleText(
            textDelegate.accessAllTip,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
            semanticsLabel: semanticsTextDelegate.accessAllTip,
          ),
        ],
      ),
    );

    final Widget _goToSettingsButton = MaterialButton(
      elevation: 0,
      minWidth: size.width / 2,
      height: appBarItemHeight * 1.25,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: themeColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: ScaleText(
        textDelegate.goToSystemSettings,
        style: const TextStyle(fontSize: 17),
        semanticsLabel: semanticsTextDelegate.goToSystemSettings,
      ),
      onPressed: PhotoManager.openSetting,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final Widget _accessLimitedButton = GestureDetector(
      onTap: () => permissionOverlayHidden.value = true,
      child: ScaleText(
        textDelegate.accessLimitedAssets,
        style: TextStyle(color: interactiveTextColor(context)),
        semanticsLabel: semanticsTextDelegate.accessLimitedAssets,
      ),
    );

    return ValueListenableBuilder2<PermissionState, bool>(
      firstNotifier: permission,
      secondNotifier: permissionOverlayHidden,
      builder: (_, PermissionState ps, bool isHidden, __) {
        if (ps.isAuth || isHidden) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Semantics(
            sortKey: const OrdinalSortKey(
              0,
              name: _ordinalNamePermissionOverlay,
            ),
            child: Container(
              padding: context.mediaQuery.padding,
              color: context.themeData.canvasColor,
              child: Column(
                children: <Widget>[
                  _closeButton,
                  Expanded(child: _limitedTips),
                  _goToSettingsButton,
                  SizedBox(height: size.height / 18),
                  _accessLimitedButton,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DefaultAssetPickerBuilderDelegate
    extends AssetPickerBuilderDelegate<AssetEntity, AssetPathEntity> {
  DefaultAssetPickerBuilderDelegate({
    required this.provider,
    required PermissionState initialPermission,
    int gridCount = 4,
    ThemeData? pickerTheme,
    SpecialItemPosition specialItemPosition = SpecialItemPosition.none,
    WidgetBuilder? specialItemBuilder,
    IndicatorBuilder? loadingIndicatorBuilder,
    bool allowSpecialItemWhenEmpty = false,
    AssetSelectPredicate<AssetEntity>? selectPredicate,
    bool? shouldRevertGrid,
    this.gridThumbnailSize = defaultAssetGridPreviewSize,
    this.previewThumbnailSize,
    this.specialPickerType,
    this.keepScrollOffset = false,
    Color? themeColor,
    AssetPickerTextDelegate? textDelegate,
    Locale? locale,
  })  : assert(
          pickerTheme == null || themeColor == null,
          'Theme and theme color cannot be set at the same time.',
        ),
        super(
          initialPermission: initialPermission,
          gridCount: gridCount,
          pickerTheme: pickerTheme,
          specialItemPosition: specialItemPosition,
          specialItemBuilder: specialItemBuilder,
          loadingIndicatorBuilder: loadingIndicatorBuilder,
          allowSpecialItemWhenEmpty: allowSpecialItemWhenEmpty,
          selectPredicate: selectPredicate,
          shouldRevertGrid: shouldRevertGrid,
          themeColor: themeColor,
          textDelegate: textDelegate,
          locale: locale,
        ) {
    // Add the listener if [keepScrollOffset] is true.
    if (keepScrollOffset) {
      gridScrollController.addListener(keepScrollOffsetListener);
    }
  }

  /// [ChangeNotifier] for asset picker.
  /// 资源选择器状态保持
  final DefaultAssetPickerProvider provider;

  /// Thumbnail size in the grid.
  ///
  /// This only works on images and videos since other types does not have to
  /// request for the thumbnail data. The preview can speed up by reducing it.
  ///
  /// This cannot be `null` or a large value since you shouldn't use the
  /// original data for the grid.
  final ThumbnailSize gridThumbnailSize;

  /// Preview thumbnail size in the viewer.
  ///
  /// This only works on images and videos since other types does not have to
  /// request for the thumbnail data. The preview can speed up by reducing it.
  ///
  /// Default is `null`, which will request the origin data.
  final ThumbnailSize? previewThumbnailSize;

  /// The current special picker type for the picker.
  ///
  /// Several types which are special:
  /// * [SpecialPickerType.wechatMoment] When user selected video, no more images
  /// can be selected.
  /// * [SpecialPickerType.noPreview] Disable preview of asset; Clicking on an
  /// asset selects it.
  ///
  /// * [SpecialPickerType.wechatMoment] 微信朋友圈模式。当用户选择了视频，将不能选择图片。
  /// * [SpecialPickerType.noPreview] 禁用资源预览。多选时单击资产将直接选中，单选时选中并返回。
  final SpecialPickerType? specialPickerType;

  /// Whether the picker should save the scroll offset between pushes and pops.
  final bool keepScrollOffset;

  /// [Duration] when triggering path switching.
  Duration get switchingPathDuration => const Duration(milliseconds: 300);

  /// [Curve] when triggering path switching.
  Curve get switchingPathCurve => Curves.easeInOutQuad;

  /// Whether the [SpecialPickerType.wechatMoment] is enabled.
  bool get isWeChatMoment =>
      specialPickerType == SpecialPickerType.wechatMoment;

  /// Whether the preview of assets is enabled.
  bool get isPreviewEnabled => specialPickerType != SpecialPickerType.noPreview;

  @override
  bool get isSingleAssetMode => provider.maxAssets == 1;

  /// The listener to track the scroll position of the [gridScrollController]
  /// if [keepScrollOffset] is true.
  void keepScrollOffsetListener() {
    if (gridScrollController.hasClients) {
      Singleton.scrollPosition = gridScrollController.position;
    }
  }

  /// Be aware that the method will do nothing when [keepScrollOffset] is true.
  @override
  void dispose() {
    // Skip delegate's dispose when it's keeping scroll offset.
    if (keepScrollOffset) {
      return;
    }
    super.dispose();
  }

  @override
  Future<void> selectAsset(
    BuildContext context,
    AssetEntity asset,
    bool selected,
  ) async {
    // final bool? selectPredicateResult = await selectPredicate?.call(
    //   context,
    //   asset,
    //   selected,
    // );
    // if (selectPredicateResult == false) {
    //   return;
    // }
    final DefaultAssetPickerProvider provider =
        context.read<DefaultAssetPickerProvider>();
    if (selected) {
      provider.unSelectAsset(asset);
      return;
    }

    final bool isDisabled = (!provider.selectedAssets.contains(asset) &&
            provider.selectedMaximumAssets) ||
        (isWeChatMoment &&
            asset.type == AssetType.video &&
            provider.selectedAssets.isNotEmpty);

    if (isDisabled) {
      Fluttertoast.showToast(msg: '더 이상 사진을 선택할 수 없어요.');
    }

    if (isSingleAssetMode) {
      provider.selectedAssets.clear();
    }
    provider.selectAsset(asset);
    if (isSingleAssetMode && !isPreviewEnabled) {
      Navigator.of(context).maybePop(provider.selectedAssets);
    }
  }

  @override
  Future<void> onAssetsChanged(MethodCall call, StateSetter setState) async {
    if (!isPermissionLimited) {
      return;
    }
    final AssetPathEntity? _currentPathEntity = provider.currentPath;
    if (_currentPathEntity != null) {
      provider.currentPath = await _currentPathEntity.obtainForNewProperties();
      await provider.switchPath(_currentPathEntity);
      isSwitchingPath.value = false;
    }
  }

  Future<void> _pushAssetToViewer(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) async {
    final DefaultAssetPickerProvider provider =
        context.read<DefaultAssetPickerProvider>();

    // bool selectedAllAndNotSelected() =>
    //     !provider.selectedAssets.contains(asset) &&
    //     provider.selectedMaximumAssets;
    // bool selectedPhotosAndIsVideo() =>
    //     isWeChatMoment &&
    //     asset.type == AssetType.video &&
    //     provider.selectedAssets.isNotEmpty;

    // When we reached the maximum select count and the asset
    // is not selected, do nothing.
    // When the special type is WeChat Moment, pictures and videos cannot
    // be selected at the same time. Video select should be banned if any
    // pictures are selected.

    // if (selectedAllAndNotSelected() || selectedPhotosAndIsVideo()) {
    //   return;
    // }

    final List<AssetEntity> _current;
    final List<AssetEntity>? _selected;
    final int _index;
    if (isWeChatMoment) {
      if (asset.type == AssetType.video) {
        _current = <AssetEntity>[asset];
        _selected = null;
        _index = 0;
      } else {
        _current = provider.currentAssets
            .where((AssetEntity e) => e.type == AssetType.image)
            .toList();
        _selected = provider.selectedAssets;
        _index = _current.indexOf(asset);
      }
    } else {
      _current = provider.currentAssets;
      _selected = provider.selectedAssets;
      _index = index;
    }
    final List<AssetEntity>? result = await AssetPickerViewer.pushToViewer(
      context,
      currentIndex: _index,
      previewAssets: _current,
      themeData: theme,
      previewThumbnailSize: previewThumbnailSize,
      selectedAssets: _selected,
      selectorProvider: provider,
      specialPickerType: specialPickerType,
      maxAssets: provider.maxAssets,
      shouldReversePreview: isAppleOS,
    );
    if (result != null) {
      Navigator.of(context).maybePop(result);
    }
  }

  @override
  AssetPickerAppBar appBar(BuildContext context) {
    return AssetPickerAppBar(
      backgroundColor: theme.appBarTheme.backgroundColor,
      centerTitle: isAppleOS,
      title: Semantics(
        onTapHint: semanticsTextDelegate.sActionSwitchPathLabel,
        child: pathEntitySelector(context),
      ),
      leading: backButton(context),
      // Condition for displaying the confirm button:
      // - On Android, show if preview is enabled or if multi asset mode.
      //   If no preview and single asset mode, do not show confirm button,
      //   because any click on an asset selects it.
      // - On iOS, show if no preview and multi asset mode. This is because for iOS
      //   the [bottomActionBar] has the confirm button, but if no preview,
      //   [bottomActionBar] is not displayed.
      actions: (!isAppleOS || !isPreviewEnabled) &&
              (isPreviewEnabled || !isSingleAssetMode)
          ? <Widget>[confirmButton(context)]
          : null,
      actionsPadding: const EdgeInsetsDirectional.only(end: 14),
      blurRadius: isAppleOS ? appleOSBlurRadius : 0,
    );
  }

  @override
  Widget androidLayout(BuildContext context) {
    return AssetPickerAppBarWrapper(
      appBar: appBar(context),
      body: Selector<DefaultAssetPickerProvider, bool>(
        selector: (_, DefaultAssetPickerProvider p) => p.hasAssetsToDisplay,
        builder: (_, bool hasAssetsToDisplay, __) {
          final bool shouldDisplayAssets = hasAssetsToDisplay ||
              (allowSpecialItemWhenEmpty &&
                  specialItemPosition != SpecialItemPosition.none);
          return AnimatedSwitcher(
            duration: switchingPathDuration,
            child: shouldDisplayAssets
                ? Stack(
                    children: <Widget>[
                      RepaintBoundary(
                        child: Column(
                          children: <Widget>[
                            Expanded(child: assetsGridBuilder(context)),
                            if (!isSingleAssetMode && isPreviewEnabled)
                              bottomActionBar(context),
                          ],
                        ),
                      ),
                      pathEntityListBackdrop(context),
                      pathEntityListWidget(context),
                    ],
                  )
                : loadingIndicator(context),
          );
        },
      ),
    );
  }

  @override
  Widget appleOSLayout(BuildContext context) {
    Widget _gridLayout(BuildContext context) {
      return ValueListenableBuilder<bool>(
        valueListenable: isSwitchingPath,
        builder: (_, bool isSwitchingPath, __) => Semantics(
          excludeSemantics: isSwitchingPath,
          child: RepaintBoundary(
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: assetsGridBuilder(context)),
                if ((!isSingleAssetMode || isAppleOS) && isPreviewEnabled)
                  Positioned.fill(
                    top: null,
                    child: bottomActionBar(context),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _layout(BuildContext context) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: Selector<DefaultAssetPickerProvider, bool>(
              selector: (_, DefaultAssetPickerProvider p) =>
                  p.hasAssetsToDisplay,
              builder: (_, bool hasAssetsToDisplay, __) {
                final Widget _child;
                final bool shouldDisplayAssets = hasAssetsToDisplay ||
                    (allowSpecialItemWhenEmpty &&
                        specialItemPosition != SpecialItemPosition.none);
                if (shouldDisplayAssets) {
                  _child = Stack(
                    children: <Widget>[
                      _gridLayout(context),
                      pathEntityListBackdrop(context),
                      pathEntityListWidget(context),
                    ],
                  );
                } else {
                  _child = loadingIndicator(context);
                }
                return AnimatedSwitcher(
                  duration: switchingPathDuration,
                  child: _child,
                );
              },
            ),
          ),
          appBar(context),
        ],
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: permissionOverlayHidden,
      builder: (_, bool value, Widget? child) {
        if (value) {
          return child!;
        }
        return Semantics(
          excludeSemantics: true,
          sortKey: const OrdinalSortKey(1, name: _ordinalNamePermissionOverlay),
          child: child,
        );
      },
      child: _layout(context),
    );
  }

  @override
  Widget assetsGridBuilder(BuildContext context) {
    return Selector<DefaultAssetPickerProvider, AssetPathEntity?>(
      selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
      builder: (_, AssetPathEntity? path, __) {
        // First, we need the count of the assets.
        int totalCount = path?.assetCount ?? 0;
        // If user chose a special item's position, add 1 count.
        if (specialItemPosition != SpecialItemPosition.none &&
            path?.isAll == true) {
          totalCount += 1;
        }
        // Then we use the [totalCount] to calculate placeholders we need.
        final int placeholderCount;
        if (effectiveShouldRevertGrid && totalCount % gridCount != 0) {
          // When there are left items that not filled into one row,
          // filled the row with placeholders.
          placeholderCount = gridCount - totalCount % gridCount;
        } else {
          // Otherwise, we don't need placeholders.
          placeholderCount = 0;
        }
        // Calculate rows count.
        final int row = (totalCount + placeholderCount) ~/ gridCount;
        // Here we got a magic calculation. [itemSpacing] needs to be divided by
        // [gridCount] since every grid item is squeezed by the [itemSpacing],
        // and it's actual size is reduced with [itemSpacing / gridCount].
        final double dividedSpacing = itemSpacing / gridCount;
        final double topPadding = context.topPadding + kToolbarHeight;

        Widget _sliverGrid(BuildContext ctx, List<AssetEntity> assets) {
          return SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, int index) => Builder(
                builder: (BuildContext c) {
                  if (effectiveShouldRevertGrid) {
                    if (index < placeholderCount) {
                      return const SizedBox.shrink();
                    }
                    index -= placeholderCount;
                  }
                  return MergeSemantics(
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: assetGridItemBuilder(c, index, assets),
                    ),
                  );
                },
              ),
              childCount: assetsGridItemCount(
                context: ctx,
                assets: assets,
                placeholderCount: placeholderCount,
              ),
              findChildIndexCallback: (Key? key) {
                if (key is ValueKey<String>) {
                  return findChildIndexBuilder(
                    id: key.value,
                    assets: assets,
                    placeholderCount: placeholderCount,
                  );
                }
                return null;
              },
              // Explicitly disable semantic indexes for custom usage.
              addSemanticIndexes: false,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridCount,
              mainAxisSpacing: itemSpacing,
              crossAxisSpacing: itemSpacing,
            ),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext c, BoxConstraints constraints) {
            final double itemSize = constraints.maxWidth / gridCount;
            // Check whether all rows can be placed at the same time.
            final bool onlyOneScreen = row * itemSize <=
                constraints.maxHeight -
                    context.bottomPadding -
                    topPadding -
                    permissionLimitedBarHeight;
            final double height;
            if (onlyOneScreen) {
              height = constraints.maxHeight;
            } else {
              // Reduce [permissionLimitedBarHeight] for the final height.
              height = constraints.maxHeight - permissionLimitedBarHeight;
            }
            // Use [ScrollView.anchor] to determine where is the first place of
            // the [SliverGrid]. Each row needs [dividedSpacing] to calculate,
            // then minus one times of [itemSpacing] because spacing's count in the
            // cross axis is always less than the rows.
            final double anchor = math.min(
              (row * (itemSize + dividedSpacing) + topPadding - itemSpacing) /
                  height,
              1,
            );

            return Directionality(
              textDirection: effectiveGridDirection(context),
              child: ColoredBox(
                color: theme.canvasColor,
                child: Selector<DefaultAssetPickerProvider, List<AssetEntity>>(
                  selector: (_, DefaultAssetPickerProvider p) =>
                      p.currentAssets,
                  builder: (_, List<AssetEntity> assets, __) {
                    final SliverGap _bottomGap = SliverGap.v(
                      context.bottomPadding + bottomSectionHeight,
                    );
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: gridScrollController,
                      anchor: effectiveShouldRevertGrid ? anchor : 0,
                      center: effectiveShouldRevertGrid ? gridRevertKey : null,
                      slivers: <Widget>[
                        if (isAppleOS)
                          SliverGap.v(context.topPadding + kToolbarHeight),
                        _sliverGrid(_, assets),
                        // Ignore the gap when the [anchor] is not equal to 1.
                        if (effectiveShouldRevertGrid && anchor == 1)
                          _bottomGap,
                        if (effectiveShouldRevertGrid)
                          SliverToBoxAdapter(
                            key: gridRevertKey,
                            child: const SizedBox.shrink(),
                          ),
                        if (isAppleOS && !effectiveShouldRevertGrid) _bottomGap,
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// There are several conditions within this builder:
  ///  * Return [specialItemBuilder] while the current path is all and
  ///    [specialItemPosition] is not equal to [SpecialItemPosition.none].
  ///  * Return item builder according to the asset's type.
  ///    * [AssetType.audio] -> [audioItemBuilder]
  ///    * [AssetType.image], [AssetType.video] -> [imageAndVideoItemBuilder]
  ///  * Load more assets when the index reached at third line counting
  ///    backwards.
  @override
  Widget assetGridItemBuilder(
    BuildContext context,
    int index,
    List<AssetEntity> currentAssets,
  ) {
    final AssetPathEntity? currentPathEntity =
        context.select<DefaultAssetPickerProvider, AssetPathEntity?>(
      (DefaultAssetPickerProvider p) => p.currentPath,
    );

    int currentIndex;
    switch (specialItemPosition) {
      case SpecialItemPosition.none:
      case SpecialItemPosition.append:
        currentIndex = index;
        break;
      case SpecialItemPosition.prepend:
        currentIndex = index - 1;
        break;
    }

    // Directly return the special item when it's empty.
    if (currentPathEntity == null) {
      if (allowSpecialItemWhenEmpty &&
          specialItemPosition != SpecialItemPosition.none) {
        return specialItemBuilder!(context);
      }
      return const SizedBox.shrink();
    }

    final int _length = currentAssets.length;
    if (currentPathEntity.isAll &&
        specialItemPosition != SpecialItemPosition.none) {
      if ((index == 0 && specialItemPosition == SpecialItemPosition.prepend) ||
          (index == _length &&
              specialItemPosition == SpecialItemPosition.append)) {
        return specialItemBuilder!(context);
      }
    }

    if (!currentPathEntity.isAll) {
      currentIndex = index;
    }

    if (index == _length - gridCount * 3 &&
        context.select<DefaultAssetPickerProvider, bool>(
          (DefaultAssetPickerProvider p) => p.hasMoreToLoad,
        )) {
      context.read<DefaultAssetPickerProvider>().loadMoreAssets();
    }

    final AssetEntity asset = currentAssets.elementAt(currentIndex);
    final Widget builder;
    switch (asset.type) {
      case AssetType.audio:
        builder = audioItemBuilder(context, currentIndex, asset);
        break;
      case AssetType.image:
      case AssetType.video:
        builder = imageAndVideoItemBuilder(context, currentIndex, asset);
        break;
      case AssetType.other:
        builder = const SizedBox.shrink();
        break;
    }
    final Widget _content = Stack(
      key: ValueKey<String>(asset.id),
      children: <Widget>[
        builder,
        selectedBackdrop(context, currentIndex, asset),
        if (!isWeChatMoment || asset.type != AssetType.video)
          selectIndicator(context, index, asset),
        // itemBannedIndicator(context, asset),
      ],
    );
    return assetGridItemSemanticsBuilder(context, index, asset, _content);
  }

  int semanticIndex(int index) {
    if (specialItemPosition != SpecialItemPosition.prepend) {
      return index + 1;
    }
    return index;
  }

  @override
  Widget assetGridItemSemanticsBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
    Widget child,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSwitchingPath,
      builder: (_, bool isSwitchingPath, Widget? child) {
        return Consumer<DefaultAssetPickerProvider>(
          builder: (_, DefaultAssetPickerProvider p, __) {
            final bool isBanned = (!p.selectedAssets.contains(asset) &&
                    p.selectedMaximumAssets) ||
                (isWeChatMoment &&
                    asset.type == AssetType.video &&
                    p.selectedAssets.isNotEmpty);
            final bool isSelected = p.selectedDescriptions.contains(
              asset.toString(),
            );
            final int selectedIndex = p.selectedAssets.indexOf(asset) + 1;
            String hint = '';
            if (asset.type == AssetType.audio ||
                asset.type == AssetType.video) {
              hint += '${semanticsTextDelegate.sNameDurationLabel}: ';
              hint += semanticsTextDelegate.durationIndicatorBuilder(
                asset.videoDuration,
              );
            }
            if (asset.title?.isNotEmpty == true) {
              hint += ', ${asset.title}';
            }
            return Semantics(
              button: false,
              enabled: !isBanned,
              excludeSemantics: true,
              focusable: !isSwitchingPath,
              label: '${semanticsTextDelegate.semanticTypeLabel(asset.type)}'
                  '${semanticIndex(index)}, '
                  '${asset.createDateTime.toString().replaceAll('.000', '')}',
              hidden: isSwitchingPath,
              hint: hint,
              image: asset.type == AssetType.image ||
                  asset.type == AssetType.video,
              onTap: () => selectAsset(context, asset, isSelected),
              onTapHint: semanticsTextDelegate.sActionSelectHint,
              onLongPress: isPreviewEnabled
                  ? () => _pushAssetToViewer(context, index, asset)
                  : null,
              onLongPressHint: semanticsTextDelegate.sActionPreviewHint,
              selected: isSelected,
              sortKey: OrdinalSortKey(
                semanticIndex(index).toDouble(),
                name: 'GridItem',
              ),
              value: selectedIndex > 0 ? '$selectedIndex' : null,
              child: GestureDetector(
                // Regression https://github.com/flutter/flutter/issues/35112.
                onLongPress:
                    isPreviewEnabled && context.mediaQuery.accessibleNavigation
                        ? () => _pushAssetToViewer(context, index, asset)
                        : null,
                child: IndexedSemantics(
                  index: semanticIndex(index),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      child: child,
    );
  }

  @override
  int findChildIndexBuilder({
    required String id,
    required List<AssetEntity> assets,
    int placeholderCount = 0,
  }) {
    int index = assets.indexWhere((AssetEntity e) => e.id == id);
    if (specialItemPosition == SpecialItemPosition.prepend) {
      index += 1;
    }
    index += placeholderCount;
    return index;
  }

  @override
  int assetsGridItemCount({
    required BuildContext context,
    required List<AssetEntity> assets,
    int placeholderCount = 0,
  }) {
    final AssetPathEntity? currentPathEntity =
        context.select<DefaultAssetPickerProvider, AssetPathEntity?>(
      (DefaultAssetPickerProvider p) => p.currentPath,
    );

    if (currentPathEntity == null &&
        specialItemPosition != SpecialItemPosition.none) {
      return 1;
    }

    /// Return actual length if current path is all.
    final int _length = assets.length + placeholderCount;
    if (!currentPathEntity!.isAll) {
      return _length;
    }
    switch (specialItemPosition) {
      case SpecialItemPosition.none:
        return _length;
      case SpecialItemPosition.prepend:
      case SpecialItemPosition.append:
        return _length + 1;
    }
  }

  @override
  Widget audioIndicator(BuildContext context, AssetEntity asset) {
    return Container(
      width: double.maxFinite,
      alignment: AlignmentDirectional.bottomStart,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.bottomCenter,
          end: AlignmentDirectional.topCenter,
          colors: <Color>[theme.dividerColor, Colors.transparent],
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: ScaleText(
          textDelegate.durationIndicatorBuilder(
            Duration(seconds: asset.duration),
          ),
          style: const TextStyle(fontSize: 16),
          semanticsLabel: '${semanticsTextDelegate.sNameDurationLabel}: '
              '${semanticsTextDelegate.durationIndicatorBuilder(
            Duration(seconds: asset.duration),
          )}',
        ),
      ),
    );
  }

  @override
  Widget audioItemBuilder(BuildContext context, int index, AssetEntity asset) {
    return Stack(
      children: <Widget>[
        Container(
          width: double.maxFinite,
          alignment: AlignmentDirectional.topStart,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              colors: <Color>[theme.dividerColor, Colors.transparent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 30),
            child: ScaleText(
              asset.title ?? '',
              style: const TextStyle(fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const Align(
          alignment: AlignmentDirectional(0.9, 0.8),
          child: Icon(Icons.audiotrack),
        ),
        audioIndicator(context, asset),
      ],
    );
  }

  /// It'll pop with [AssetPickerProvider.selectedAssets]
  /// when there are any assets were chosen.
  @override
  Widget confirmButton(BuildContext context) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (_, DefaultAssetPickerProvider p, __) {
        final bool isSelect = p.isSelectedNotEmpty && !isSingleAssetMode;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: p.isSelectedNotEmpty
              ? () => Navigator.of(context).maybePop(p.selectedAssets)
              : null,
          child: Container(
            height: appBarItemHeight,
            child: Align(
              alignment: Alignment.center,
              child: RichText(
                textAlign: TextAlign.right,
                text: TextSpan(
                  style: const TextStyle(fontSize: 17, height: 1),
                  children: <TextSpan>[
                    if (isSelect)
                      TextSpan(
                        text: '${p.selectedAssets.length}',
                        style: TextStyle(
                          color: themeColor,
                          height: 1,
                        ),
                      ),
                    TextSpan(
                      text: ' ${textDelegate.confirm}',
                      style: TextStyle(
                        color: isSelect
                            ? theme.textTheme.bodyText1?.color
                            : theme.textTheme.caption?.color,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // return MaterialButton(
        //   minWidth: p.isSelectedNotEmpty ? 48 : 20,
        //   height: appBarItemHeight,
        //   padding: const EdgeInsets.symmetric(horizontal: 12),
        //   disabledColor: theme.dividerColor,
        //   color: p.isSelectedNotEmpty ? themeColor : theme.dividerColor,
        //   shape: RoundedRectangleBorder(
        //     borderRadius: BorderRadius.circular(3),
        //   ),
        //   child: ScaleText(
        //     p.isSelectedNotEmpty && !isSingleAssetMode
        //         ? '(${p.selectedAssets.length}/${p.maxAssets}) '
        //             '${textDelegate.confirm}'
        //         : textDelegate.confirm,
        //     style: TextStyle(
        //       color: p.isSelectedNotEmpty
        //           ? theme.textTheme.bodyText1?.color
        //           : theme.textTheme.caption?.color,
        //       fontSize: 17,
        //       fontWeight: FontWeight.normal,
        //     ),
        //     semanticsLabel: p.isSelectedNotEmpty && !isSingleAssetMode
        //         ? '${semanticsTextDelegate.confirm}'
        //             ' (${p.selectedAssets.length}/${p.maxAssets})'
        //         : semanticsTextDelegate.confirm,
        //   ),
        //   onPressed: p.isSelectedNotEmpty
        //       ? () => Navigator.of(context).maybePop(p.selectedAssets)
        //       : null,
        //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // );
      },
    );
  }

  @override
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) {
    final AssetEntityImageProvider imageProvider = AssetEntityImageProvider(
      asset,
      isOriginal: false,
      thumbnailSize: gridThumbnailSize,
    );
    SpecialImageType? type;
    if (imageProvider.imageFileType == ImageFileType.gif) {
      type = SpecialImageType.gif;
    } else if (imageProvider.imageFileType == ImageFileType.heic) {
      type = SpecialImageType.heic;
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: RepaintBoundary(
            child: AssetEntityGridItemBuilder(
              image: imageProvider,
              failedItemBuilder: failedItemBuilder,
            ),
          ),
        ),
        if (type == SpecialImageType.gif) gifIndicator(context, asset),
        if (asset.type == AssetType.video) videoIndicator(context, asset),
      ],
    );
  }

  @override
  Widget loadingIndicator(BuildContext context) {
    return Center(
      child: Selector<DefaultAssetPickerProvider, bool>(
        selector: (_, DefaultAssetPickerProvider p) => p.isAssetsEmpty,
        builder: (_, bool isAssetsEmpty, __) {
          if (isAssetsEmpty) {
            return ScaleText(
              textDelegate.emptyList,
              maxScaleFactor: 1.5,
              semanticsLabel: semanticsTextDelegate.emptyList,
            );
          }
          return PlatformProgressIndicator(
            color: theme.iconTheme.color,
            size: context.mediaQuery.size.width / gridCount / 3,
          );
        },
      ),
    );
  }

  /// While the picker is switching path, this will displayed.
  /// If the user tapped on it, it'll collapse the list widget.
  ///
  @override
  Widget pathEntityListBackdrop(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSwitchingPath,
      builder: (_, bool isSwitchingPath, __) => Positioned.fill(
        child: IgnorePointer(
          ignoring: !isSwitchingPath,
          ignoringSemantics: true,
          child: GestureDetector(
            onTap: () => this.isSwitchingPath.value = false,
            child: AnimatedOpacity(
              duration: switchingPathDuration,
              opacity: isSwitchingPath ? .75 : 0,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget pathEntityListWidget(BuildContext context) {
    return Positioned.fill(
      top: isAppleOS ? context.topPadding + kToolbarHeight : 0,
      bottom: null,
      child: ValueListenableBuilder<bool>(
        valueListenable: isSwitchingPath,
        builder: (_, bool isSwitchingPath, Widget? child) => Semantics(
          hidden: isSwitchingPath ? null : true,
          child: AnimatedAlign(
            duration: switchingPathDuration,
            curve: switchingPathCurve,
            alignment: Alignment.bottomCenter,
            heightFactor: isSwitchingPath ? 1 : 0,
            child: AnimatedOpacity(
              duration: switchingPathDuration,
              curve: switchingPathCurve,
              opacity: !isAppleOS || isSwitchingPath ? 1 : 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight:
                        context.mediaQuery.size.height * (isAppleOS ? .6 : .8),
                  ),
                  color: theme.colorScheme.background,
                  child: child,
                ),
              ),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ValueListenableBuilder<PermissionState>(
              valueListenable: permission,
              builder: (_, PermissionState ps, Widget? child) => Semantics(
                label: '${semanticsTextDelegate.viewingLimitedAssetsTip}, '
                    '${semanticsTextDelegate.changeAccessibleLimitedAssets}',
                button: true,
                onTap: PhotoManager.presentLimited,
                hidden: !isPermissionLimited,
                focusable: isPermissionLimited,
                excludeSemantics: true,
                child: isPermissionLimited ? child : const SizedBox.shrink(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text.rich(
                  TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text: textDelegate.viewingLimitedAssetsTip,
                      ),
                      TextSpan(
                        text: ' '
                            '${textDelegate.changeAccessibleLimitedAssets}',
                        style: TextStyle(color: interactiveTextColor(context)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = PhotoManager.presentLimited,
                      ),
                    ],
                  ),
                  style: context.themeData.textTheme.caption?.copyWith(
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            Flexible(
              child: Consumer<DefaultAssetPickerProvider>(
                builder: (_, DefaultAssetPickerProvider p, __) {
                  return ListView.separated(
                    padding: const EdgeInsetsDirectional.only(top: 1),
                    shrinkWrap: true,
                    itemCount: p.pathsList.length,
                    itemBuilder: (BuildContext c, int i) => pathEntityWidget(
                      context: c,
                      list: p.pathsList,
                      index: i,
                      isAudio: p.requestType == RequestType.audio,
                    ),
                    separatorBuilder: (_, __) => Container(
                      margin: const EdgeInsetsDirectional.only(start: 60),
                      height: 1,
                      color: theme.canvasColor,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget pathEntitySelector(BuildContext context) {
    return UnconstrainedBox(
      child: GestureDetector(
        onTap: () {
          Feedback.forTap(context);
          isSwitchingPath.value = !isSwitchingPath.value;
        },
        child: Container(
          height: appBarItemHeight,
          constraints: BoxConstraints(
            maxWidth: context.mediaQuery.size.width * 0.5,
          ),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
          // decoration: BoxDecoration(
          //   borderRadius: BorderRadius.circular(999),
          //   color: theme.dividerColor,
          // ),
          child: Selector<DefaultAssetPickerProvider, AssetPathEntity?>(
            selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
            builder: (_, AssetPathEntity? p, Widget? w) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (p != null)
                  Flexible(
                    child: ScaleText(
                      isPermissionLimited && p.isAll
                          ? textDelegate.accessiblePathName
                          : p.isAll
                              ? '모든 사진'
                              : p.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      maxScaleFactor: 1.2,
                      semanticsLabel: isPermissionLimited && p.isAll
                          ? semanticsTextDelegate.accessiblePathName
                          : p.name,
                    ),
                  ),
                w!,
              ],
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 5),
              child: ValueListenableBuilder<bool>(
                valueListenable: isSwitchingPath,
                builder: (_, bool isSwitchingPath, Widget? w) {
                  return Transform.rotate(
                    angle: isSwitchingPath ? math.pi : 0,
                    alignment: Alignment.center,
                    child: w,
                  );
                },
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget pathEntityWidget({
    required BuildContext context,
    required Map<AssetPathEntity, Uint8List?> list,
    required int index,
    bool isAudio = false,
  }) {
    final AssetPathEntity pathEntity = list.keys.elementAt(index);
    final Uint8List? data = list.values.elementAt(index);

    Widget builder() {
      if (isAudio) {
        return ColoredBox(
          color: theme.colorScheme.primary.withOpacity(0.12),
          child: const Center(child: Icon(Icons.audiotrack)),
        );
      }

      // The reason that the `thumbData` should be checked at here to see if it
      // is null is that even the image file is not exist, the `File` can still
      // returned as it exist, which will cause the thumb bytes return null.
      //
      if (data != null) {
        return Image.memory(data, fit: BoxFit.cover);
      }
      return ColoredBox(color: theme.colorScheme.primary.withOpacity(0.12));
    }

    final String name = isPermissionLimited && pathEntity.isAll
        ? textDelegate.accessiblePathName
        : pathEntity.isAll == true
            ? '모든 사진'
            : pathEntity.name;
    final String semanticsName = isPermissionLimited && pathEntity.isAll
        ? semanticsTextDelegate.accessiblePathName
        : pathEntity.name;
    final String semanticsCount = '${pathEntity.assetCount}';

    return Selector<DefaultAssetPickerProvider, AssetPathEntity?>(
      selector: (_, DefaultAssetPickerProvider p) => p.currentPath,
      builder: (_, AssetPathEntity? currentPathEntity, __) {
        final bool isSelected = currentPathEntity == pathEntity;
        return Semantics(
          label: '$semanticsName, '
              '${semanticsTextDelegate.sUnitAssetCountLabel}: '
              '$semanticsCount',
          selected: isSelected,
          onTapHint: semanticsTextDelegate.sActionSwitchPathLabel,
          button: false,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              splashFactory: InkSplash.splashFactory,
              onTap: () {
                Feedback.forTap(context);
                context
                    .read<DefaultAssetPickerProvider>()
                    .switchPath(pathEntity);
                isSwitchingPath.value = false;
                gridScrollController.jumpTo(0);
              },
              child: SizedBox(
                height: isAppleOS ? 64 : 52,
                child: Row(
                  children: <Widget>[
                    RepaintBoundary(
                      child: AspectRatio(aspectRatio: 1, child: builder()),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 15,
                          end: 20,
                        ),
                        child: ExcludeSemantics(
                          child: Row(
                            children: <Widget>[
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 10,
                                  ),
                                  child: ScaleText(
                                    name,
                                    style: const TextStyle(fontSize: 17),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              ScaleText(
                                '($semanticsCount)',
                                style: TextStyle(
                                  color: theme.textTheme.caption?.color,
                                  fontSize: 17,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      AspectRatio(
                        aspectRatio: 1,
                        child: Icon(Icons.check, color: themeColor, size: 26),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget previewButton(BuildContext context) {
    Future<void> _onTap() async {
      final DefaultAssetPickerProvider p =
          context.read<DefaultAssetPickerProvider>();
      final List<AssetEntity> _selectedAssets = p.selectedAssets;
      final List<AssetEntity> _selected;
      if (isWeChatMoment) {
        _selected = _selectedAssets
            .where((AssetEntity e) => e.type == AssetType.image)
            .toList();
      } else {
        _selected = _selectedAssets;
      }
      final List<AssetEntity>? result = await AssetPickerViewer.pushToViewer(
        context,
        currentIndex: 0,
        previewAssets: _selected,
        previewThumbnailSize: previewThumbnailSize,
        selectedAssets: _selected,
        selectorProvider: provider,
        themeData: theme,
        maxAssets: p.maxAssets,
      );
      if (result != null) {
        Navigator.of(context).maybePop(result);
      }
    }

    return Consumer<DefaultAssetPickerProvider>(
      builder: (_, DefaultAssetPickerProvider p, Widget? child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isSwitchingPath,
          builder: (_, bool isSwitchingPath, __) => Semantics(
            enabled: p.isSelectedNotEmpty,
            focusable: !isSwitchingPath,
            hidden: isSwitchingPath,
            onTapHint: semanticsTextDelegate.sActionPreviewHint,
            child: child,
          ),
        );
      },
      child: Consumer<DefaultAssetPickerProvider>(
        builder: (_, DefaultAssetPickerProvider p, __) => GestureDetector(
          onTap: p.isSelectedNotEmpty ? _onTap : null,
          child: Selector<DefaultAssetPickerProvider, String>(
            selector: (_, DefaultAssetPickerProvider p) =>
                p.selectedDescriptions,
            builder: (BuildContext c, __, ___) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ScaleText(
                '${textDelegate.preview}'
                '${p.isSelectedNotEmpty ? ' (${p.selectedAssets.length})' : ''}',
                style: TextStyle(
                  color: p.isSelectedNotEmpty
                      ? null
                      : c.themeData.textTheme.caption?.color,
                  fontSize: 17,
                ),
                maxScaleFactor: 1.2,
                semanticsLabel: '${semanticsTextDelegate.preview}'
                    '${p.isSelectedNotEmpty ? ' (${p.selectedAssets.length})' : ''}',
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget itemBannedIndicator(BuildContext context, AssetEntity asset) {
    return Consumer<DefaultAssetPickerProvider>(
      builder: (_, DefaultAssetPickerProvider p, __) {
        final bool isDisabled =
            (!p.selectedAssets.contains(asset) && p.selectedMaximumAssets) ||
                (isWeChatMoment &&
                    asset.type == AssetType.video &&
                    p.selectedAssets.isNotEmpty);
        if (isDisabled) {
          return Container(
            color: theme.colorScheme.onBackground.withOpacity(.75),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget selectIndicator(BuildContext context, int index, AssetEntity asset) {
    final double indicatorSize = context.mediaQuery.size.width / gridCount / 3;
    final Duration duration = switchingPathDuration * 0.75;
    late int index;
    return Selector<DefaultAssetPickerProvider, String>(
      selector: (_, DefaultAssetPickerProvider p) {
        index = p.selectedAssets.indexOf(asset);
        return p.selectedDescriptions;
      },
      builder: (BuildContext context, String descriptions, __) {
        final bool selected = descriptions.contains(asset.toString());

        final Widget innerSelector = AnimatedContainer(
          duration: duration,
          width: indicatorSize / (isAppleOS ? 1.25 : 1.5),
          height: indicatorSize / (isAppleOS ? 1.25 : 1.5),
          padding: EdgeInsets.all(indicatorSize / 10),
          decoration: BoxDecoration(
            border: !selected
                ? Border.all(
                    color: context.themeData.selectedRowColor,
                    width: indicatorSize / 25,
                  )
                : null,
            color: selected ? themeColor : null,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: duration,
            reverseDuration: duration,
            child: selected
                ? Container(
                    child: Align(
                      alignment: Alignment.center,
                      child: ScaleText(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
        final Widget selectorWidget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => selectAsset(context, asset, selected),
          child: Container(
            margin: EdgeInsets.all(indicatorSize / 4),
            width: isPreviewEnabled ? indicatorSize : null,
            height: isPreviewEnabled ? indicatorSize : null,
            alignment: AlignmentDirectional.topEnd,
            child: (!isPreviewEnabled && isSingleAssetMode && !selected)
                ? const SizedBox.shrink()
                : innerSelector,
          ),
        );
        if (isPreviewEnabled) {
          return PositionedDirectional(
            top: 0,
            end: 0,
            child: selectorWidget,
          );
        }
        return selectorWidget;
      },
    );
  }

  @override
  Widget selectedBackdrop(BuildContext context, int index, AssetEntity asset) {
    final double indicatorSize = context.mediaQuery.size.width / gridCount / 3;
    return Positioned.fill(
      child: GestureDetector(
        onTap: isPreviewEnabled
            ? () => _pushAssetToViewer(context, index, asset)
            : null,
        child: Consumer<DefaultAssetPickerProvider>(
          builder: (_, DefaultAssetPickerProvider p, __) {
            final int index = p.selectedAssets.indexOf(asset);
            final bool selected = index != -1;
            return Container(
              decoration: selected
                  ? BoxDecoration(border: Border.all(color: themeColor!))
                  : null,
              child: AnimatedContainer(
                duration: switchingPathDuration,
                padding: EdgeInsets.all(indicatorSize * .35),
                color: selected
                    ? theme.colorScheme.onBackground.withOpacity(.45)
                    : theme.backgroundColor.withOpacity(.1),
                // child: selected && !isSingleAssetMode
                //     ? Align(
                //         alignment: AlignmentDirectional.topStart,
                //         child: SizedBox(
                //           height: indicatorSize / 2.5,
                //           child: FittedBox(
                //             alignment: AlignmentDirectional.topStart,
                //             fit: BoxFit.cover,
                //             child: Text(
                //               '${index + 1}',
                //               style: TextStyle(
                //                 color: theme.textTheme.bodyText1?.color
                //                     ?.withOpacity(.75),
                //                 fontWeight: FontWeight.w600,
                //                 height: 1,
                //               ),
                //             ),
                //           ),
                //         ),
                //       )
                //     : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Videos often contains various of color in the cover,
  /// so in order to keep the content visible in most cases,
  /// the color of the indicator has been set to [Colors.white].
  ///
  @override
  Widget videoIndicator(BuildContext context, AssetEntity asset) {
    return PositionedDirectional(
      start: 0,
      end: 0,
      bottom: 0,
      child: Container(
        width: double.maxFinite,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.bottomCenter,
            end: AlignmentDirectional.topCenter,
            colors: <Color>[theme.dividerColor, Colors.transparent],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.videocam, size: 22, color: Colors.white),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4),
                child: ScaleText(
                  textDelegate.durationIndicatorBuilder(
                    Duration(seconds: asset.duration),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  strutStyle: const StrutStyle(
                    forceStrutHeight: true,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  maxScaleFactor: 1.2,
                  semanticsLabel:
                      semanticsTextDelegate.durationIndicatorBuilder(
                    Duration(seconds: asset.duration),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Schedule the scroll position's restoration callback if this feature
    // is enabled and offsets are different.
    if (keepScrollOffset && Singleton.scrollPosition != null) {
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        // Update only if the controller has clients.
        if (gridScrollController.hasClients) {
          gridScrollController.jumpTo(Singleton.scrollPosition!.pixels);
        }
      });
    }
    return CNP<DefaultAssetPickerProvider>.value(
      value: provider,
      builder: (BuildContext context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Theme(
            data: theme,
            child: Material(
              color: theme.canvasColor,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (isAppleOS)
                    appleOSLayout(context)
                  else
                    androidLayout(context),
                  if (Platform.isIOS) iOSPermissionOverlay(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
