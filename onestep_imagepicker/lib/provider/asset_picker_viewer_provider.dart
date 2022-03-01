///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020/3/31 15:37
///
import 'package:flutter/material.dart';

/// [ChangeNotifier] for assets picker viewer.
/// provider model.
class AssetPickerViewerProvider<A> extends ChangeNotifier {
  /// Copy selected assets for editing when constructing.

  AssetPickerViewerProvider(List<A>? assets) {
    _currentlySelectedAssets = List<A>.from(assets ?? <A>[]);
  }

  /// Selected assets in the viewer.
  late List<A> _currentlySelectedAssets;

  List<A> get currentlySelectedAssets => _currentlySelectedAssets;

  set currentlySelectedAssets(List<A> value) {
    if (value == _currentlySelectedAssets) {
      return;
    }
    _currentlySelectedAssets = value;
    notifyListeners();
  }

  bool get isSelectedNotEmpty => currentlySelectedAssets.isNotEmpty;

  /// Select asset.
  void selectAssetEntity(A entity) {
    final List<A> set = List<A>.from(currentlySelectedAssets);
    set.add(entity);
    currentlySelectedAssets = List<A>.from(set);
  }

  /// Un-select asset.
  void unSelectAssetEntity(A entity) {
    final List<A> set = List<A>.from(currentlySelectedAssets);
    set.remove(entity);
    currentlySelectedAssets = List<A>.from(set);
  }
}
