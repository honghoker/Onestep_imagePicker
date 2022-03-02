///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2020-10-31 00:15
///
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:onestep_imagepicker/widget/asset_picker_viewer.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../constants/custom_scroll_physics.dart';
import '../constants/enums.dart';
import '../constants/extensions.dart';
import '../delegates/asset_picker_builder_delegate.dart';
import '../delegates/asset_picker_text_delegate.dart';
import '../internal/singleton.dart';
import '../provider/asset_picker_provider.dart';
import '../provider/asset_picker_viewer_provider.dart';
import '../widget/builder/audio_page_builder.dart';
import '../widget/builder/fade_image_builder.dart';
import '../widget/builder/image_page_builder.dart';
import '../widget/builder/value_listenable_builder_2.dart';
import '../widget/builder/video_page_builder.dart';
import '../widget/scale_text.dart';

abstract class AssetPickerViewerBuilderDelegate<Asset, Path> {
  AssetPickerViewerBuilderDelegate({
    required this.previewAssets,
    required this.themeData,
    required this.currentIndex,
    this.selectorProvider,
    this.provider,
    this.selectedAssets,
    this.maxAssets,
    this.shouldReversePreview = false,
    this.selectPredicate,
  });

  /// [ChangeNotifier] for photo selector viewer.
  final AssetPickerViewerProvider<Asset>? provider;

  /// Assets provided to preview.
  final List<Asset> previewAssets;

  /// Theme for the viewer.
  final ThemeData themeData;

  /// Selected assets.
  final List<Asset>? selectedAssets;

  /// Provider for [AssetPicker].
  final AssetPickerProvider<Asset, Path>? selectorProvider;

  /// Whether the preview sequence is reversed.
  ///
  /// Usually this will be true when users are previewing on Apple OS and
  /// clicked one item of the asset grid.
  final bool shouldReversePreview;

  /// {@macro wechat_assets_picker.AssetSelectPredicate}
  final AssetSelectPredicate<Asset>? selectPredicate;

  /// [StreamController] for viewing page index update.
  ///
  /// The main purpose is to narrow down build parts when index is changing,
  /// prevent widely [setState] and causing other widgets rebuild.
  final StreamController<int> pageStreamController =
      StreamController<int>.broadcast();

  /// The [ScrollController] for the previewing assets list.
  final ScrollController previewingListController = ScrollController();

  /// Whether detail widgets displayed.
  final ValueNotifier<bool> isDisplayingDetail = ValueNotifier<bool>(true);

  /// The [State] for a viewer.
  late final AssetPickerViewerState<Asset, Path> viewerState;

  /// The [TickerProvider] for animations.
  late final TickerProvider vsync;

  /// [AnimationController] for double tap animation.
  late final AnimationController doubleTapAnimationController;

  /// [CurvedAnimation] for double tap.
  late final Animation<double> doubleTapCurveAnimation;

  /// [Animation] for double tap.
  Animation<double>? doubleTapAnimation;

  /// Callback for double tap.
  late VoidCallback doubleTapListener;

  /// [PageController] for assets preview [PageView].
  ExtendedPageController get pageController => _pageController;
  late final ExtendedPageController _pageController = ExtendedPageController(
    initialPage: currentIndex,
  );

  /// Current previewing index in assets.
  int currentIndex;

  /// Maximum count for asset selection.
  final int? maxAssets;

  /// Whether the viewer is under preview mode for selected assets.
  late final bool isSelectedPreviewing = selectedAssets == previewAssets;

  /// Getter for the current asset.
  Asset get currentAsset => previewAssets.elementAt(currentIndex);

  /// Height for bottom preview widget.
  double get bottomPreviewHeight => 90.0;

  /// Height for bottom bar widget.
  double get bottomBarHeight => 50.0;

  double get bottomDetailHeight => bottomPreviewHeight + bottomBarHeight;

  /// Whether the current platform is Apple OS.
  bool get isAppleOS => Platform.isIOS || Platform.isMacOS;

  AssetPickerTextDelegate get textDelegate => Singleton.textDelegate;

  AssetPickerTextDelegate get semanticsTextDelegate =>
      Singleton.textDelegate.semanticsTextDelegate;

  /// Call when viewer is calling [initState].
  void initStateAndTicker(
    AssetPickerViewerState<Asset, Path> s,
    TickerProvider v,
  ) {
    viewerState = s;
    vsync = v;
    doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: v,
    );
    doubleTapCurveAnimation = CurvedAnimation(
      parent: doubleTapAnimationController,
      curve: Curves.easeInOut,
    );
  }

  /// Keep a dispose method to sync with [State].
  void dispose() {
    provider?.dispose();
    pageController.dispose();
    pageStreamController.close();
    previewingListController.dispose();
    selectedNotifier.dispose();
    isDisplayingDetail.dispose();
    doubleTapAnimationController
      ..stop()
      ..reset()
      ..dispose();
  }

  /// Produce [OrdinalSortKey] with the fixed name.
  OrdinalSortKey ordinalSortKey(double value) {
    return OrdinalSortKey(value, name: 'AssetPickerViewerBuilderDelegate');
  }

  /// Execute scale animation when double tap.
  void updateAnimation(ExtendedImageGestureState state) {
    final double begin = state.gestureDetails!.totalScale!;
    final double end = state.gestureDetails!.totalScale! == 1.0 ? 3.0 : 1.0;
    final Offset pointerDownPosition = state.pointerDownPosition!;

    doubleTapAnimation?.removeListener(doubleTapListener);
    doubleTapAnimationController
      ..stop()
      ..reset();
    doubleTapListener = () {
      state.handleDoubleTap(
        scale: doubleTapAnimation!.value,
        doubleTapPosition: pointerDownPosition,
      );
    };
    doubleTapAnimation = Tween<double>(
      begin: begin,
      end: end,
    ).animate(doubleTapCurveAnimation)
      ..addListener(doubleTapListener);
    doubleTapAnimationController.forward();
  }

  /// The length getter for selected assets currently.
  int get selectedCount => selectedAssets?.length ?? 0;

  bool get selectedMaximumAssets =>
      selectedAssets != null && selectedAssets!.length == maxAssets;

  /// Construct a notifier to notify
  /// whether if a new asset is selected or unselected.
  late final ValueNotifier<int> selectedNotifier =
      ValueNotifier<int>(selectedCount);

  void unSelectAsset(Asset entity) {
    provider?.unSelectAssetEntity(entity);
    if (!isSelectedPreviewing) {
      selectedAssets?.remove(entity);
    }
    if (selectedCount != selectedNotifier.value) {
      selectedNotifier.value = selectedCount;
    }
  }

  void selectAsset(Asset entity) {
    if (maxAssets != null && selectedCount >= maxAssets!) {
      return;
    }
    provider?.selectAssetEntity(entity);
    if (!isSelectedPreviewing) {
      selectedAssets?.add(entity);
    }
    if (selectedCount != selectedNotifier.value) {
      selectedNotifier.value = selectedCount;
    }
  }

  Future<void> onChangingSelected(
    BuildContext context,
    Asset asset,
    bool isSelected,
  ) async {
    final bool? selectPredicateResult = await selectPredicate?.call(
      context,
      asset,
      isSelected,
    );
    if (selectPredicateResult == false) {
      return;
    }
    if (isSelected) {
      unSelectAsset(asset);
      return;
    }
    selectAsset(asset);
  }

  /// Method to switch [isDisplayingDetail].
  void switchDisplayingDetail({bool? value}) {
    isDisplayingDetail.value = value ?? !isDisplayingDetail.value;
  }

  /// Sync selected assets currently with asset picker provider.
  Future<bool> syncSelectedAssetsWhenPop() async {
    if (provider?.currentlySelectedAssets != null) {
      selectorProvider?.selectedAssets = provider!.currentlySelectedAssets;
    }
    return true;
  }

  /// Split page builder according to type of asset.
  Widget assetPageBuilder(BuildContext context, int index);

  /// Common image load state changed callback with [Widget].
  Widget previewWidgetLoadStateChanged(
    BuildContext context,
    ExtendedImageState state, {
    bool hasLoaded = false,
  }) {
    Widget loader;
    switch (state.extendedImageLoadState) {
      case LoadState.completed:
        loader = state.completedWidget;
        if (!hasLoaded) {
          loader = FadeImageBuilder(child: loader);
        }
        break;
      case LoadState.failed:
        loader = failedItemBuilder(context);
        break;
      default:
        loader = const SizedBox.shrink();
        break;
    }
    return loader;
  }

  /// The item widget when [AssetEntity.thumbData] load failed.
  Widget failedItemBuilder(BuildContext context) {
    return Center(
      child: ScaleText(
        textDelegate.loadFailed,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18.0),
        semanticsLabel: semanticsTextDelegate.loadFailed,
      ),
    );
  }

  /// Confirm button.
  Widget confirmButton(BuildContext context);

  /// Select button.
  Widget selectButton(BuildContext context);

  /// Thumb item widgets in bottom detail.
  Widget bottomDetailItemBuilder(BuildContext context, int index);

  /// Detail widget aligned to bottom.
  Widget bottomDetailBuilder(BuildContext context);

  /// Yes, the build method.
  Widget build(BuildContext context);
}

class DefaultAssetPickerViewerBuilderDelegate
    extends AssetPickerViewerBuilderDelegate<AssetEntity, AssetPathEntity> {
  DefaultAssetPickerViewerBuilderDelegate({
    required int currentIndex,
    required List<AssetEntity> previewAssets,
    AssetPickerProvider<AssetEntity, AssetPathEntity>? selectorProvider,
    required ThemeData themeData,
    AssetPickerViewerProvider<AssetEntity>? provider,
    List<AssetEntity>? selectedAssets,
    this.previewThumbnailSize,
    this.specialPickerType,
    int? maxAssets,
    bool shouldReversePreview = false,
    AssetSelectPredicate<AssetEntity>? selectPredicate,
  }) : super(
          currentIndex: currentIndex,
          previewAssets: previewAssets,
          provider: provider,
          themeData: themeData,
          selectedAssets: selectedAssets,
          selectorProvider: selectorProvider,
          maxAssets: maxAssets,
          shouldReversePreview: shouldReversePreview,
          selectPredicate: selectPredicate,
        );

  /// Thumb size for the preview of images in the viewer.
  final ThumbnailSize? previewThumbnailSize;

  /// The current special picker type for the viewer.
  ///
  /// If the type is not null, the title of the viewer will not display.
  final SpecialPickerType? specialPickerType;

  /// Whether the [SpecialPickerType.wechatMoment] is enabled.
  bool get isWeChatMoment =>
      specialPickerType == SpecialPickerType.wechatMoment;

  /// Whether there are videos in preview/selected assets.
  bool get hasVideo =>
      previewAssets.any((AssetEntity e) => e.type == AssetType.video) ||
      (selectedAssets?.any((AssetEntity e) => e.type == AssetType.video) ??
          false);

  @override
  Widget assetPageBuilder(BuildContext context, int index) {
    final AssetEntity asset = previewAssets.elementAt(index);
    final Widget _builder;
    switch (asset.type) {
      case AssetType.audio:
        _builder = AudioPageBuilder(asset: asset);
        break;
      case AssetType.image:
        _builder = ImagePageBuilder(
          asset: asset,
          delegate: this,
          previewThumbnailSize: previewThumbnailSize,
        );
        break;
      case AssetType.video:
        _builder = VideoPageBuilder(
          asset: asset,
          delegate: this,
          hasOnlyOneVideoAndMoment: isWeChatMoment && hasVideo,
        );
        break;
      case AssetType.other:
        _builder = Center(
          child: ScaleText(
            textDelegate.unSupportedAssetType,
            semanticsLabel: semanticsTextDelegate.unSupportedAssetType,
          ),
        );
        break;
    }
    return MergeSemantics(
      child: Consumer<AssetPickerViewerProvider<AssetEntity>?>(
        builder: (
          BuildContext c,
          AssetPickerViewerProvider<AssetEntity>? p,
          Widget? w,
        ) {
          final bool isSelected =
              (p?.currentlySelectedAssets ?? selectedAssets)?.contains(asset) ==
                  true;
          String hint = '';
          if (asset.type == AssetType.audio || asset.type == AssetType.video) {
            hint += '${semanticsTextDelegate.sNameDurationLabel}: ';
            hint += textDelegate.durationIndicatorBuilder(asset.videoDuration);
          }
          if (asset.title?.isNotEmpty == true) {
            hint += ', ${asset.title}';
          }
          return Semantics(
            label: '${semanticsTextDelegate.semanticTypeLabel(asset.type)}'
                '${index + 1}, '
                '${asset.createDateTime.toString().replaceAll('.000', '')}',
            selected: isSelected,
            hint: hint,
            image:
                asset.type == AssetType.image || asset.type == AssetType.video,
            child: w,
          );
        },
        child: _builder,
      ),
    );
  }

  /// Preview item widgets for audios.
  Widget _audioPreviewItem(AssetEntity asset) {
    return ColoredBox(
      color: viewerState.context.themeData.dividerColor,
      child: const Center(child: Icon(Icons.audiotrack)),
    );
  }

  /// Preview item widgets for images.
  Widget _imagePreviewItem(AssetEntity asset) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: ExtendedImage(
          image: AssetEntityImageProvider(asset, isOriginal: false),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// Preview item widgets for video.
  Widget _videoPreviewItem(AssetEntity asset) {
    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          _imagePreviewItem(asset),
          Center(
            child: Icon(
              Icons.video_library,
              color: themeData.iconTheme.color?.withOpacity(0.54),
            ),
          ),
        ],
      ),
    );
  }

  /// The back button when previewing video in [SpecialPickerType.wechatMoment].
  Widget momentVideoBackButton(BuildContext context) {
    return PositionedDirectional(
      start: 16,
      top: context.topPadding + 16,
      child: Semantics(
        sortKey: ordinalSortKey(0),
        child: IconButton(
          onPressed: Navigator.of(context).maybePop,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tight(const Size.square(28)),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          iconSize: 18,
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: themeData.iconTheme.color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.keyboard_return_rounded,
              color: themeData.canvasColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget bottomDetailBuilder(BuildContext context) {
    final Color _backgroundColor = themeData.primaryColor.withOpacity(.9);
    return ValueListenableBuilder2<bool, int>(
      firstNotifier: isDisplayingDetail,
      secondNotifier: selectedNotifier,
      builder: (_, bool v, __, Widget? child) => AnimatedPositionedDirectional(
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOut,
        bottom: v ? 0 : -(context.bottomPadding + bottomDetailHeight),
        start: 0,
        end: 0,
        height: context.bottomPadding + bottomDetailHeight,
        child: child!,
      ),
      child: CNP<AssetPickerViewerProvider<AssetEntity>?>.value(
        value: provider,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            if (provider != null)
              ValueListenableBuilder<int>(
                valueListenable: selectedNotifier,
                builder: (_, int count, __) => Container(
                  width: count > 0 ? double.maxFinite : 0,
                  height: bottomPreviewHeight,
                  color: _backgroundColor,
                  child: ListView.builder(
                    controller: previewingListController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    physics: const ClampingScrollPhysics(),
                    itemCount: count,
                    itemBuilder: bottomDetailItemBuilder,
                  ),
                ),
              ),
            Container(
              height: bottomBarHeight + context.bottomPadding,
              padding: const EdgeInsets.symmetric(horizontal: 20.0)
                  .copyWith(bottom: context.bottomPadding),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    width: 1.0,
                    color: themeData.canvasColor,
                  ),
                ),
                color: _backgroundColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Spacer(),
                  if (isAppleOS && (provider != null || isWeChatMoment))
                    confirmButton(context)
                  else
                    selectButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget bottomDetailItemBuilder(BuildContext context, int index) {
    const double padding = 8.0;

    void onTap(AssetEntity asset) {
      final int page;
      if (previewAssets != selectedAssets) {
        page = previewAssets.indexOf(asset);
      } else {
        page = index;
      }
      if (pageController.page == page.toDouble()) {
        return;
      }
      pageController.jumpToPage(page);
      final double offset =
          (index - 0.5) * (bottomPreviewHeight - padding * 3) -
              context.mediaQuery.size.width / 4;
      previewingListController.animateTo(
        math.max(0, offset),
        curve: Curves.ease,
        duration: kThemeChangeDuration,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 2,
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: StreamBuilder<int>(
          initialData: currentIndex,
          stream: pageStreamController.stream,
          builder: (_, AsyncSnapshot<int> snapshot) {
            final AssetEntity asset = selectedAssets!.elementAt(index);
            final bool isViewing = previewAssets[snapshot.data!] == asset;
            final Widget _item = () {
              switch (asset.type) {
                case AssetType.image:
                  return _imagePreviewItem(asset);
                case AssetType.video:
                  return _videoPreviewItem(asset);
                case AssetType.audio:
                  return _audioPreviewItem(asset);
                default:
                  return const SizedBox.shrink();
              }
            }();
            return Semantics(
              label: '${semanticsTextDelegate.semanticTypeLabel(asset.type)}'
                  '${index + 1}',
              selected: isViewing,
              onTap: () => onTap(asset),
              onTapHint: semanticsTextDelegate.sActionPreviewHint,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onTap(asset),
                child: Selector<AssetPickerViewerProvider<AssetEntity>?,
                    List<AssetEntity>?>(
                  selector: (_, AssetPickerViewerProvider<AssetEntity>? p) =>
                      p?.currentlySelectedAssets,
                  child: _item,
                  builder: (
                    _,
                    List<AssetEntity>? currentlySelectedAssets,
                    Widget? w,
                  ) {
                    final bool isSelected =
                        currentlySelectedAssets?.contains(asset) ?? false;
                    return Stack(
                      children: <Widget>[
                        w!,
                        AnimatedContainer(
                          duration: kThemeAnimationDuration,
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            border: isViewing
                                ? Border.all(
                                    color: themeData.colorScheme.secondary,
                                    width: 3,
                                  )
                                : null,
                            color: isSelected
                                ? null
                                : themeData.colorScheme.surface
                                    .withOpacity(0.54),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// AppBar widget.
  Widget appBar(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDisplayingDetail,
      builder: (_, bool value, Widget? child) => AnimatedPositionedDirectional(
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOut,
        top: value ? 0.0 : -(context.topPadding + kToolbarHeight),
        start: 0.0,
        end: 0.0,
        height: context.topPadding + kToolbarHeight,
        child: child!,
      ),
      child: Container(
        padding: EdgeInsetsDirectional.only(top: context.topPadding),
        color: themeData.canvasColor,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  sortKey: ordinalSortKey(0),
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: Navigator.of(context).maybePop,
                  ),
                ),
              ),
            ),
            if (!isAppleOS && specialPickerType == null)
              Expanded(
                child: Center(
                  child: Semantics(
                    sortKey: ordinalSortKey(0.1),
                    child: StreamBuilder<int>(
                      initialData: currentIndex,
                      stream: pageStreamController.stream,
                      builder: (_, AsyncSnapshot<int> snapshot) => ScaleText(
                        '${snapshot.data! + 1}/${previewAssets.length}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (isAppleOS && provider != null)
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Semantics(
                    sortKey: ordinalSortKey(0.2),
                    child: selectButton(context),
                  ),
                ),
              )
            else if (isAppleOS)
              const Spacer(),
            if (!isAppleOS && (provider != null || isWeChatMoment))
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Semantics(
                    sortKey: ordinalSortKey(0.3),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: confirmButton(context),
                    ),
                  ),
                ),
              )
            else if (!isAppleOS)
              const Spacer(),
          ],
        ),
      ),
    );
  }

  /// It'll pop with [AssetPickerProvider.selectedAssets] when there are
  /// any assets were chosen. Then, the assets picker will pop too.
  @override
  Widget confirmButton(BuildContext context) {
    return CNP<AssetPickerViewerProvider<AssetEntity>?>.value(
      value: provider,
      child: Consumer<AssetPickerViewerProvider<AssetEntity>?>(
        builder: (_, AssetPickerViewerProvider<AssetEntity>? provider, __) {
          assert(
            isWeChatMoment || provider != null,
            'Viewer provider must not be null'
            'when the special type is not WeChat moment.',
          );

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (isWeChatMoment && hasVideo) {
                Navigator.of(context).pop(<AssetEntity>[currentAsset]);
                return;
              }
              if (provider!.isSelectedNotEmpty) {
                Navigator.of(context).pop(provider.currentlySelectedAssets);
                return;
              }
              // selectAsset(currentAsset);
              // Navigator.of(context).pop(
              //   selectedAssets ?? <AssetEntity>[currentAsset],
              // );
            },
            child: Container(
              height: 32.0,
              child: Align(
                alignment: Alignment.centerRight,
                child: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(fontSize: 17, height: 1),
                    children: <TextSpan>[
                      if (provider!.isSelectedNotEmpty)
                        TextSpan(
                          text: '${provider.currentlySelectedAssets.length}',
                          style: TextStyle(
                            color: themeData.colorScheme.secondary,
                            height: 1,
                          ),
                        ),
                      TextSpan(
                        text: ' ${textDelegate.confirm}',
                        style: TextStyle(
                          color: provider.isSelectedNotEmpty
                              ? themeData.textTheme.bodyText1?.color
                              : themeData.textTheme.caption?.color,
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
          //   minWidth: () {
          //     if (isWeChatMoment && hasVideo) {
          //       return 48.0;
          //     }
          //     return provider!.isSelectedNotEmpty ? 48.0 : 20.0;
          //   }(),
          //   height: 32.0,
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   // color: themeData.colorScheme.secondary,
          //   // shape: RoundedRectangleBorder(
          //   //   borderRadius: BorderRadius.circular(3.0),
          //   // ),
          //   child: ScaleText(
          //     () {
          //       if (isWeChatMoment && hasVideo) {
          //         return textDelegate.confirm;
          //       }
          //       if (provider!.isSelectedNotEmpty) {
          //         return '${textDelegate.confirm}'
          //             ' (${provider.currentlySelectedAssets.length}'
          //             '/'
          //             '${selectorProvider!.maxAssets})';
          //       }
          //       return textDelegate.confirm;
          //     }(),
          //     style: TextStyle(
          //       color: themeData.textTheme.bodyText1?.color,
          //       fontSize: 17,
          //       fontWeight: FontWeight.normal,
          //     ),
          //     semanticsLabel: () {
          //       if (isWeChatMoment && hasVideo) {
          //         return semanticsTextDelegate.confirm;
          //       }
          //       if (provider!.isSelectedNotEmpty) {
          //         return '${semanticsTextDelegate.confirm}'
          //             ' (${provider.currentlySelectedAssets.length}'
          //             '/'
          //             '${selectorProvider!.maxAssets})';
          //       }
          //       return semanticsTextDelegate.confirm;
          //     }(),
          //   ),
          //   onPressed: () {
          //     if (isWeChatMoment && hasVideo) {
          //       Navigator.of(context).pop(<AssetEntity>[currentAsset]);
          //       return;
          //     }
          //     if (provider!.isSelectedNotEmpty) {
          //       Navigator.of(context).pop(provider.currentlySelectedAssets);
          //       return;
          //     }
          //     selectAsset(currentAsset);
          //     Navigator.of(context).pop(
          //       selectedAssets ?? <AssetEntity>[currentAsset],
          //     );
          //   },
          //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          // );
        },
      ),
    );
  }

  /// Select button for apple OS.
  Widget _appleOSSelectButton(
    BuildContext context,
    bool isSelected,
    AssetEntity asset,
  ) {
    if (!isSelected && selectedMaximumAssets) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Feedback.forTap(context);
          onChangingSelected(context, asset, isSelected);
        },
        child: AnimatedContainer(
          duration: kThemeAnimationDuration,
          width: 28.0,
          decoration: BoxDecoration(
            border: !isSelected
                ? Border.all(color: themeData.iconTheme.color!)
                : null,
            color: isSelected ? themeData.colorScheme.secondary : null,
            shape: BoxShape.circle,
          ),
          child: const Center(child: Icon(Icons.check, size: 20.0)),
        ),
      ),
    );
  }

  /// Select button for Android.
  Widget _androidSelectButton(
    BuildContext context,
    bool isSelected,
    AssetEntity asset,
  ) {
    return Checkbox(
      value: isSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999999),
      ),
      onChanged: (_) => onChangingSelected(context, asset, isSelected),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget selectButton(BuildContext context) {
    return CNP<AssetPickerViewerProvider<AssetEntity>>.value(
      value: provider!,
      builder: (_, Widget? w) => StreamBuilder<int>(
        initialData: currentIndex,
        stream: pageStreamController.stream,
        builder: (BuildContext _, AsyncSnapshot<int> s) {
          final AssetEntity asset = previewAssets.elementAt(s.data!);
          return Selector<AssetPickerViewerProvider<AssetEntity>,
              List<AssetEntity>>(
            selector: (_, AssetPickerViewerProvider<AssetEntity> p) =>
                p.currentlySelectedAssets,
            builder: (BuildContext c, List<AssetEntity> assets, _) {
              final bool isSelected = assets.contains(asset);
              return Semantics(
                selected: isSelected,
                label: semanticsTextDelegate.select,
                onTap: () => onChangingSelected(context, asset, isSelected),
                onTapHint: semanticsTextDelegate.select,
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    if (isAppleOS)
                      _appleOSSelectButton(c, isSelected, asset)
                    else
                      _androidSelectButton(c, isSelected, asset),
                    if (!isAppleOS)
                      ScaleText(
                        textDelegate.select,
                        style: const TextStyle(fontSize: 17, height: 1),
                        semanticsLabel: semanticsTextDelegate.select,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _pageViewBuilder(BuildContext context) {
    return Semantics(
      sortKey: ordinalSortKey(1),
      child: ExtendedImageGesturePageView.builder(
        physics: previewAssets.length == 1
            ? const CustomClampingScrollPhysics()
            : const CustomBouncingScrollPhysics(),
        controller: pageController,
        itemCount: previewAssets.length,
        itemBuilder: assetPageBuilder,
        reverse: shouldReversePreview,
        onPageChanged: (int index) {
          currentIndex = index;
          pageStreamController.add(index);
        },
        scrollDirection: Axis.horizontal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: syncSelectedAssetsWhenPop,
      child: Theme(
        data: themeData,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: themeData.appBarTheme.systemOverlayStyle ??
              (themeData.effectiveBrightness.isDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark),
          child: Material(
            color: themeData.colorScheme.onSecondary,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: _pageViewBuilder(context)),
                if (isWeChatMoment && hasVideo) ...<Widget>[
                  momentVideoBackButton(context),
                  PositionedDirectional(
                    end: 16,
                    bottom: context.bottomPadding + 16,
                    child: confirmButton(context),
                  ),
                ] else ...<Widget>[
                  appBar(context),
                  if (selectedAssets != null ||
                      (isWeChatMoment && hasVideo && isAppleOS))
                    bottomDetailBuilder(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
