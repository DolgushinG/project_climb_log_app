import 'package:flutter/material.dart';

/// Web: поддержка жеста «свайп назад» на iOS PWA (popstate → Navigator.pop вместо перезагрузки).
export 'WebBackHandler_stub.dart'
    if (dart.library.html) 'WebBackHandler_web.dart';
