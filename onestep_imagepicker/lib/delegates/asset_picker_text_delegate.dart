///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020/4/7 10:25
///
import 'package:flutter/rendering.dart';
import 'package:photo_manager/photo_manager.dart' show AssetType;

/// All text delegates.
final List<AssetPickerTextDelegate> assetPickerTextDelegates =
    <AssetPickerTextDelegate>[
  AssetPickerTextDelegate(),
  KoreanAssetPickerTextDelegate(),
  EnglishAssetPickerTextDelegate(),
];

/// Obtain the text delegate from the given locale.
AssetPickerTextDelegate assetPickerTextDelegateFromLocale(Locale? locale) {
  if (locale == null) {
    return AssetPickerTextDelegate();
  }
  final String languageCode = locale.languageCode.toLowerCase();
  for (final AssetPickerTextDelegate delegate in assetPickerTextDelegates) {
    if (delegate.languageCode == languageCode) {
      return delegate;
    }
  }
  return AssetPickerTextDelegate();
}

/// Text delegate that controls text in widgets.
class AssetPickerTextDelegate {
  String get languageCode => 'ko';

  /// Confirm string for the confirm button.
  String get confirm => '완료';

  /// Cancel string for back button.
  String get cancel => '취소';

  /// Edit string for edit button.
  String get edit => '편집';

  /// GIF indicator string.
  String get gifIndicator => 'GIF';

  /// Load failed string for item.
  String get loadFailed => '로딩 실패';

  /// Original string for original selection.
  String get original => '원본';

  /// Preview string for preview button.
  String get preview => '선택된 사진보기';

  /// Select string for select button.
  String get select => '선택';

  /// Empty list string for empty asset list.
  String get emptyList => '선택되지 않았어요';

  /// Un-supported asset type string for assets that
  /// belongs to [AssetType.other].
  String get unSupportedAssetType => 'HEIC 파일은 지원되지 않아요.';

  /// "Unable to access all assets in album".
  String get unableToAccessAll => '장치에 접근할 수 없어요.';

  String get viewingLimitedAssetsTip => '앱에서 접근할 수 있는 사진과 앨범만 보여요.';

  String get changeAccessibleLimitedAssets => '사진 및 앨범 접근 권한 업데이트';

  String get accessAllTip => '앱은 장치의 일부 사진 및 앨범에만 접근할 수 있습니다. '
      '시스템 설정으로 이동하여 앱이 장치의 모든 사진 및 앨범에 접근할 수 있도록 허용해주세요.';

  String get goToSystemSettings => '시스템 설정으로 이동';

  /// "Continue accessing some assets".
  String get accessLimitedAssets => '제한된 권한으로 계속 진행';

  String get accessiblePathName => '접근가능한 사진 및 앨범';

  /// This is used in video asset item in the picker, in order
  /// to display the duration of the video or audio type of asset.
  String durationIndicatorBuilder(Duration duration) {
    const String separator = ':';
    final String minute = duration.inMinutes.toString().padLeft(2, '0');
    final String second =
        ((duration - Duration(minutes: duration.inMinutes)).inSeconds)
            .toString()
            .padLeft(2, '0');
    return '$minute$separator$second';
  }

  /// Semantics fields.
  ///
  /// Fields below are only for semantics usage. For customizable these fields,
  /// head over to [EnglishAssetPickerTextDelegate] for fields understanding.
  String get sTypeAudioLabel => 'Audio';

  String get sTypeImageLabel => 'Image';

  String get sTypeVideoLabel => 'Video';

  String get sTypeOtherLabel => 'Other asset';

  String semanticTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.audio:
        return sTypeAudioLabel;
      case AssetType.image:
        return sTypeImageLabel;
      case AssetType.video:
        return sTypeVideoLabel;
      case AssetType.other:
        return sTypeOtherLabel;
    }
  }

  String get sActionPlayHint => 'play';

  String get sActionPreviewHint => 'preview';

  String get sActionSelectHint => 'select';

  String get sActionSwitchPathLabel => 'switch path';

  String get sActionUseCameraHint => 'use camera';

  String get sNameDurationLabel => 'duration';

  String get sUnitAssetCountLabel => 'count';

  /// Fallback delegate for semantics determined by platform.
  ///
  /// The purpose of this field is to provide a fallback delegate references
  /// when a language does not supported by Talkback or VoiceOver. Set this to
  /// another text delegate makes screen readers read accordingly.
  ///
  /// See also:
  ///  * Talkback: https://support.google.com/accessibility/android/answer/11101402)
  ///  * VoiceOver: https://support.apple.com/en-us/HT206175
  AssetPickerTextDelegate get semanticsTextDelegate => this;
}

/// [AssetPickerTextDelegate] implements with English.
/// English Localization
class KoreanAssetPickerTextDelegate extends AssetPickerTextDelegate {
  @override
  String get languageCode => 'ko';

  @override
  String get confirm => '완료';

  @override
  String get cancel => '취소';

  @override
  String get edit => '편집';

  @override
  String get gifIndicator => 'GIF';

  @override
  String get loadFailed => '로딩 실패';

  @override
  String get original => '원본';

  @override
  String get preview => '선택된 사진보기';

  @override
  String get select => '선택';

  @override
  String get emptyList => '선택되지 않았어요';

  @override
  String get unSupportedAssetType => 'HEIC 파일은 지원되지 않아요.';

  @override
  String get unableToAccessAll => '장치에 접근할 수 없어요.';

  @override
  String get viewingLimitedAssetsTip => '앱에서 접근할 수 있는 사진과 앨범만 보여요.';

  @override
  String get changeAccessibleLimitedAssets => '사진 및 앨범 접근 권한 업데이트';

  @override
  String get accessAllTip => '앱은 장치의 일부 사진 및 앨범에만 접근할 수 있습니다. '
      '시스템 설정으로 이동하여 앱이 장치의 모든 사진 및 앨범에 접근할 수 있도록 허용해주세요.';

  @override
  String get goToSystemSettings => '시스템 설정으로 이동';

  @override
  String get accessLimitedAssets => '제한된 권한으로 계속 진행';

  @override
  String get accessiblePathName => '접근가능한 사진 및 앨범';

  @override
  String get sTypeAudioLabel => 'Audio';

  @override
  String get sTypeImageLabel => 'Image';

  @override
  String get sTypeVideoLabel => 'Video';

  @override
  String get sTypeOtherLabel => 'Other asset';

  @override
  String get sActionPlayHint => 'play';

  @override
  String get sActionPreviewHint => 'preview';

  @override
  String get sActionSelectHint => 'select';

  @override
  String get sActionSwitchPathLabel => 'switch path';

  @override
  String get sActionUseCameraHint => 'use camera';

  @override
  String get sNameDurationLabel => 'duration';

  @override
  String get sUnitAssetCountLabel => 'count';
}

/// [AssetPickerTextDelegate] implements with English.
/// English Localization
class EnglishAssetPickerTextDelegate extends AssetPickerTextDelegate {
  @override
  String get languageCode => 'en';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get edit => 'Edit';

  @override
  String get gifIndicator => 'GIF';

  @override
  String get loadFailed => 'Load failed';

  @override
  String get original => 'Origin';

  @override
  String get preview => 'Preview';

  @override
  String get select => 'Select';

  @override
  String get emptyList => 'Empty list';

  @override
  String get unSupportedAssetType => 'Unsupported HEIC asset type.';

  @override
  String get unableToAccessAll => 'Unable to access all assets on the device';

  @override
  String get viewingLimitedAssetsTip =>
      'Only view assets and albums accessible to app.';

  @override
  String get changeAccessibleLimitedAssets =>
      'Click to update accessible assets';

  @override
  String get accessAllTip => 'App can only access some assets on the device. '
      'Go to system settings and allow app to access all assets on the device.';

  @override
  String get goToSystemSettings => 'Go to system settings';

  @override
  String get accessLimitedAssets => 'Continue with limited access';

  @override
  String get accessiblePathName => 'Accessible assets';

  @override
  String get sTypeAudioLabel => 'Audio';

  @override
  String get sTypeImageLabel => 'Image';

  @override
  String get sTypeVideoLabel => 'Video';

  @override
  String get sTypeOtherLabel => 'Other asset';

  @override
  String get sActionPlayHint => 'play';

  @override
  String get sActionPreviewHint => 'preview';

  @override
  String get sActionSelectHint => 'select';

  @override
  String get sActionSwitchPathLabel => 'switch path';

  @override
  String get sActionUseCameraHint => 'use camera';

  @override
  String get sNameDurationLabel => 'duration';

  @override
  String get sUnitAssetCountLabel => 'count';
}
