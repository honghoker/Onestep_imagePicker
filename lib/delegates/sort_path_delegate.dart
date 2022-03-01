///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020-05-30 13:08
///
import 'package:photo_manager/photo_manager.dart';

/// Delegate to sort asset path entities.
///
/// Define [sort] to sort the asset path list.
/// Usually integrate with [List.sort].
abstract class SortPathDelegate<Path> {
  const SortPathDelegate();

  void sort(List<Path> list);

  static const SortPathDelegate<AssetPathEntity> common =
      CommonSortPathDelegate();
}

/// Common sort path delegate.
///
/// This delegate will bring "Recent" (All photos), "Camera", "Screenshot(?s)"
/// to the front of the paths list.
class CommonSortPathDelegate extends SortPathDelegate<AssetPathEntity> {
  const CommonSortPathDelegate();

  @override
  void sort(List<AssetPathEntity> list) {
    if (list.any((AssetPathEntity e) => e.lastModified != null)) {
      list.sort((AssetPathEntity path1, AssetPathEntity path2) {
        if (path1.lastModified == null || path2.lastModified == null) {
          return 0;
        }
        if (path2.lastModified!.isAfter(path1.lastModified!)) {
          return 1;
        }
        return -1;
      });
    }
    list.sort((AssetPathEntity path1, AssetPathEntity path2) {
      if (path1.isAll) {
        return -1;
      }
      if (path2.isAll) {
        return 1;
      }
      if (_isCamera(path1)) {
        return -1;
      }
      if (_isCamera(path2)) {
        return 1;
      }
      if (_isScreenShot(path1)) {
        return -1;
      }
      if (_isScreenShot(path2)) {
        return 1;
      }
      return 0;
    });
  }

  int otherSort(AssetPathEntity path1, AssetPathEntity path2) {
    return path1.name.compareTo(path2.name);
  }

  bool _isCamera(AssetPathEntity entity) {
    return entity.name == 'Camera';
  }

  bool _isScreenShot(AssetPathEntity entity) {
    return entity.name == 'Screenshots' || entity.name == 'Screenshot';
  }
}
