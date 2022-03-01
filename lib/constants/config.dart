///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2022/2/14 13:25
///
import 'package:flutter/material.dart';
import 'package:onestep_imagepicker/delegates/asset_picker_text_delegate.dart';
import 'package:photo_manager/photo_manager.dart';

import '../delegates/asset_picker_builder_delegate.dart';
import '../delegates/sort_path_delegate.dart';
import 'constants.dart';
import 'enums.dart';

class AssetPickerConfig {
  const AssetPickerConfig({
    this.selectedAssets,
    this.maxAssets = 9,
    this.pageSize = 80,
    this.gridThumbnailSize = defaultAssetGridPreviewSize,
    this.pathThumbnailSize = defaultPathThumbnailSize,
    this.previewThumbnailSize,
    this.specialPickerType,
    this.keepScrollOffset = false,
    this.requestType = RequestType.common,
    this.sortPathDelegate,
    this.filterOptions,
    this.gridCount = 4,
    this.themeColor,
    this.pickerTheme,
    this.textDelegate,
    this.specialItemPosition = SpecialItemPosition.none,
    this.specialItemBuilder,
    this.loadingIndicatorBuilder,
    this.allowSpecialItemWhenEmpty = false,
    this.selectPredicate,
    this.shouldRevertGrid,
  })  : assert(maxAssets >= 1, 'maxAssets must be greater than 1.'),
        assert(
          pickerTheme == null || themeColor == null,
          'pickerTheme and themeColor cannot be set at the same time.',
        ),
        assert(
          pageSize % gridCount == 0,
          'pageSize must be a multiple of gridCount.',
        ),
        assert(
          specialPickerType != SpecialPickerType.wechatMoment ||
              requestType == RequestType.common,
          'SpecialPickerType.wechatMoment and requestType '
          'cannot be set at the same time.',
        ),
        assert(
          (specialItemBuilder == null &&
                  identical(specialItemPosition, SpecialItemPosition.none)) ||
              (specialItemBuilder != null &&
                  !identical(specialItemPosition, SpecialItemPosition.none)),
          'Custom item did not set properly.',
        );

  /// Selected assets.
  final List<AssetEntity>? selectedAssets;

  /// Maximum count for asset selection.
  final int maxAssets;

  /// Assets should be loaded per page.
  ///
  /// Use `null` to display all assets into a single grid.
  final int pageSize;

  /// Thumbnail size in the grid.
  ///
  /// This only works on images and videos since other types does not have to
  /// request for the thumbnail data. The preview can speed up by reducing it.
  ///
  /// This cannot be `null` or a large value since you shouldn't use the
  /// original data for the grid.
  final ThumbnailSize gridThumbnailSize;

  /// Thumbnail size for path selector.
  final ThumbnailSize pathThumbnailSize;

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

  /// Request assets type.
  final RequestType requestType;

  /// Delegate to sort asset path entities.
  final SortPathDelegate<AssetPathEntity>? sortPathDelegate;

  /// Filter options for the picker.
  ///
  /// Will be merged into the base configuration.
  final FilterOptionGroup? filterOptions;

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

  final AssetPickerTextDelegate? textDelegate;

  /// Allow users set a special item in the picker with several positions.
  final SpecialItemPosition specialItemPosition;

  /// The widget builder for the the special item.
  final WidgetBuilder? specialItemBuilder;

  /// Indicates the loading status for the builder.
  final IndicatorBuilder? loadingIndicatorBuilder;

  /// Whether the special item will display or not when assets is empty.
  final bool allowSpecialItemWhenEmpty;

  /// {@macro wechat_assets_picker.AssetSelectPredicate}
  final AssetSelectPredicate<AssetEntity>? selectPredicate;

  /// Whether the assets grid should revert.
  ///
  /// [Null] means judging by [isAppleOS].
  final bool? shouldRevertGrid;
}
