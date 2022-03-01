///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020/7/8 12:32
///

/// Provide some special picker types to integrate
/// un-common pick pattern.
enum SpecialPickerType {
  /// WeChat Moments mode.
  ///
  /// The user can only select *one video* or *multiple images* at the same time,
  /// and those two asset types cannot be selected at the same time.
  wechatMoment,

  /// Disable preview of assets.
  ///
  /// There is no preview mode when clicking grid items.
  /// In multiple select mode, any click (either on the select indicator or on
  /// the asset itself) will select the asset.
  /// In single select mode, any click directly selects the asset and returns.
  noPreview,
}

/// Provide an item slot for custom widget insertion.
enum SpecialItemPosition {
  /// Not insert to the list.
  none,

  /// Add as leading of the list.
  prepend,

  /// Add as trailing of the list.
  append,
}
