///
/// [Author] Alex (https://github.com/AlexV525)
/// [Date] 2022/2/6 14:57
///
import 'dart:developer';

import 'package:flutter/foundation.dart';

/// Log only when debugging.
void realDebugPrint(dynamic message) {
  if (!kReleaseMode) {
    log('$message');
  }
}
