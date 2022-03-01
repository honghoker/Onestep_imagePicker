///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020/3/31 15:28
///
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/constants.dart';
import '../delegates/sort_path_delegate.dart';
import '../internal/singleton.dart';

/// [ChangeNotifier] for assets picker.
///
/// The provider maintain all methods that control assets and paths.
/// By extending it you can customize how you can get all assets or paths,
/// how to fetch the next page of assets,
/// and how to get the thumbnail data of a path.
abstract class AssetPickerProvider<Asset, Path> extends ChangeNotifier {
  AssetPickerProvider({
    this.maxAssets = 9,
    this.pageSize = 320,
    this.pathThumbnailSize = defaultPathThumbnailSize,
    List<Asset>? selectedAssets,
  }) {
    if (selectedAssets?.isNotEmpty == true) {
      _selectedAssets = List<Asset>.from(selectedAssets!);
    }
  }

  /// Maximum count for asset selection.
  final int maxAssets;

  /// Assets should be loaded per page.
  ///
  /// Use `null` to display all assets into a single grid.
  final int pageSize;

  /// Thumbnail size for path selector.
  final ThumbnailSize pathThumbnailSize;

  /// Clear all fields when dispose.
  @override
  void dispose() {
    _isAssetsEmpty = false;
    _pathsList.clear();
    _currentPath = null;
    _currentAssets.clear();
    _selectedAssets.clear();
    super.dispose();
  }

  /// Get paths.
  Future<void> getPaths();

  /// Get the thumbnail from the first asset under the specific path entity.
  Future<Uint8List?> getThumbnailFromPath(Path path);

  /// Switch between paths.
  Future<void> switchPath([Path? path]);

  /// Get assets under the specific path entity.
  Future<void> getAssetsFromPath(int page, Path path);

  /// Load more assets.
  Future<void> loadMoreAssets();

  /// Whether there are assets on the devices.
  bool get isAssetsEmpty => _isAssetsEmpty;
  bool _isAssetsEmpty = false;

  set isAssetsEmpty(bool value) {
    if (value == _isAssetsEmpty) {
      return;
    }
    _isAssetsEmpty = value;
    notifyListeners();
  }

  /// Whether there are any assets can be displayed.
  bool get hasAssetsToDisplay => _hasAssetsToDisplay;
  bool _hasAssetsToDisplay = false;

  set hasAssetsToDisplay(bool value) {
    if (value == _hasAssetsToDisplay) {
      return;
    }
    _hasAssetsToDisplay = value;
    notifyListeners();
  }

  /// Whether more assets are waiting for a load.
  bool get hasMoreToLoad => _currentAssets.length < _totalAssetsCount;

  /// The current page for assets list.
  int get currentAssetsListPage =>
      (math.max(1, _currentAssets.length) / pageSize).ceil();

  /// Total count for assets.
  int get totalAssetsCount => _totalAssetsCount;
  int _totalAssetsCount = 0;

  set totalAssetsCount(int value) {
    if (value == _totalAssetsCount) {
      return;
    }
    _totalAssetsCount = value;
    notifyListeners();
  }

  /// Map for all path entity.
  ///
  /// Using [Map] in order to save the thumbnail data
  /// for the first asset under the path.
  Map<Path, Uint8List?> get pathsList => _pathsList;
  final Map<Path, Uint8List?> _pathsList = <Path, Uint8List?>{};

  /// Set thumbnail [data] for the specific [path].
  void setPathThumbnail(Path path, Uint8List? data) {
    _pathsList[path] = data;
    notifyListeners();
  }

  /// How many path has a valid thumb data.
  ///
  /// This getter provides a "Should Rebuild" condition judgement to [Selector]
  /// with the path entities widget.
  int get validPathThumbnailsCount =>
      _pathsList.values.where((Uint8List? d) => d != null).length;

  /// The path which is currently using.
  Path? get currentPath => _currentPath;
  Path? _currentPath;

  set currentPath(Path? value) {
    if (value == null || value == _currentPath) {
      return;
    }
    _currentPath = value;
    notifyListeners();
  }

  /// Assets under current path entity.
  List<Asset> get currentAssets => _currentAssets;
  List<Asset> _currentAssets = <Asset>[];

  set currentAssets(List<Asset> value) {
    if (value == _currentAssets) {
      return;
    }
    _currentAssets = List<Asset>.from(value);
    notifyListeners();
  }

  /// Selected assets.
  List<Asset> get selectedAssets => _selectedAssets;
  List<Asset> _selectedAssets = <Asset>[];

  set selectedAssets(List<Asset> value) {
    if (value == _selectedAssets) {
      return;
    }
    _selectedAssets = List<Asset>.from(value);
    notifyListeners();
  }

  /// Descriptions for selected assets currently.
  ///
  /// This getter provides a "Should Rebuild" condition judgement to [Selector]
  /// with the preview widget's selective part.
  String get selectedDescriptions => _selectedAssets.fold(
        <String>[],
        (List<String> list, Asset a) => list..add(a.toString()),
      ).join();

  bool get isSelectedNotEmpty => selectedAssets.isNotEmpty;

  bool get selectedMaximumAssets => selectedAssets.length == maxAssets;

  /// Select asset.
  void selectAsset(Asset item) {
    if (selectedAssets.length == maxAssets || selectedAssets.contains(item)) {
      return;
    }
    final List<Asset> _set = List<Asset>.from(selectedAssets);
    _set.add(item);
    selectedAssets = _set;
  }

  /// Un-select asset.
  void unSelectAsset(Asset item) {
    final List<Asset> _set = List<Asset>.from(selectedAssets);
    _set.remove(item);
    selectedAssets = _set;
  }
}

class DefaultAssetPickerProvider
    extends AssetPickerProvider<AssetEntity, AssetPathEntity> {
  DefaultAssetPickerProvider({
    List<AssetEntity>? selectedAssets,
    this.requestType = RequestType.image,
    this.sortPathDelegate = SortPathDelegate.common,
    this.filterOptions,
    int maxAssets = 9,
    int pageSize = 80,
    ThumbnailSize pathThumbnailSize = const ThumbnailSize.square(80),
  }) : super(
          maxAssets: maxAssets,
          pageSize: pageSize,
          pathThumbnailSize: pathThumbnailSize,
          selectedAssets: selectedAssets,
        ) {
    Singleton.sortPathDelegate = sortPathDelegate ?? SortPathDelegate.common;
    // Call [getAssetList] with route duration when constructing.
    Future<void>(() async {
      await getPaths();
      await getAssetsFromCurrentPath();
    });
  }

  /// Request assets type.
  final RequestType requestType;

  /// Delegate to sort asset path entities.
  final SortPathDelegate<AssetPathEntity>? sortPathDelegate;

  /// Filter options for the picker.
  ///
  /// Will be merged into the base configuration.
  final FilterOptionGroup? filterOptions;

  @override
  Future<void> getPaths() async {
    // Initial base options.
    // Enable need title for audios and image to get proper display.
    final FilterOptionGroup options = FilterOptionGroup(
      imageOption: const FilterOption(
        needTitle: true,
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      audioOption: const FilterOption(
        needTitle: true,
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
      containsPathModified: true,
    );

    // Merge user's filter option into base options if it's not null.
    if (filterOptions != null) {
      options.merge(filterOptions!);
    }

    final List<AssetPathEntity> _list = await PhotoManager.getAssetPathList(
      type: requestType,
      filterOption: options,
    );

    // Sort path using sort path delegate.
    Singleton.sortPathDelegate.sort(_list);

    for (final AssetPathEntity pathEntity in _list) {
      // Use sync method to avoid unnecessary wait.
      _pathsList[pathEntity] = null;
      if (requestType != RequestType.audio) {
        getThumbnailFromPath(pathEntity).then((Uint8List? data) {
          _pathsList[pathEntity] = data;
          notifyListeners();
        });
      }
    }

    // Set first path entity as current path entity.
    if (_pathsList.isNotEmpty) {
      _currentPath ??= pathsList.keys.elementAt(0);
    }
  }

  @override
  Future<void> getAssetsFromPath(int page, AssetPathEntity path) async {
    final List<AssetEntity> list = await path.getAssetListPaged(
      page: page,
      size: pageSize,
    );
    _currentAssets = List<AssetEntity>.of(list);
    _hasAssetsToDisplay = currentAssets.isNotEmpty;
    notifyListeners();
  }

  @override
  Future<void> loadMoreAssets() async {
    final List<AssetEntity> list = await currentPath!.getAssetListPaged(
      page: currentAssetsListPage,
      size: pageSize,
    );
    final List<AssetEntity> assets = List<AssetEntity>.of(list);
    if (assets.isNotEmpty && currentAssets.contains(assets[0])) {
      return;
    }
    final List<AssetEntity> tempList = <AssetEntity>[];
    tempList.addAll(_currentAssets);
    tempList.addAll(assets);
    currentAssets = tempList;
  }

  @override
  Future<void> switchPath([AssetPathEntity? path]) async {
    assert(
      () {
        if (_currentPath == null && path == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Empty $AssetPathEntity was switched.'),
            ErrorDescription(
              'Neither currentPathEntity nor pathEntity is non-null, '
              'which makes this method useless.',
            ),
            ErrorHint(
              'You need to pass a non-null $AssetPathEntity '
              'or call this method when currentPathEntity is not null.',
            ),
          ]);
        }
        return true;
      }(),
    );
    if (_currentPath == null && path == null) {
      return;
    }
    path ??= _currentPath!;
    _currentPath = path;
    _totalAssetsCount = path.assetCount;
    notifyListeners();
    await getAssetsFromPath(0, currentPath!);
  }

  @override
  Future<Uint8List?> getThumbnailFromPath(
    AssetPathEntity path,
  ) async {
    assert(
      () {
        if (path.assetCount < 1) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('No assets in the path ${path.id}.'),
            ErrorDescription(
              'Thumbnail can only obtained when the path contains assets.',
            ),
          ]);
        }
        return true;
      }(),
    );
    final AssetEntity asset =
        (await path.getAssetListRange(start: 0, end: 1)).single;
    final Uint8List? assetData = await asset.thumbnailDataWithSize(
      pathThumbnailSize,
    );
    return assetData;
  }

  /// Get assets list from current path entity.
  Future<void> getAssetsFromCurrentPath() async {
    if (_pathsList.isNotEmpty) {
      _currentPath = _pathsList.keys.elementAt(0);
      totalAssetsCount = currentPath!.assetCount;
      await getAssetsFromPath(0, currentPath!);
    } else {
      isAssetsEmpty = true;
    }
  }
}
