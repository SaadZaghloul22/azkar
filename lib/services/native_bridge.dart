import 'dart:convert';

import 'package:flutter/services.dart';

import '../state/settings.dart';

/// Talks to the Kotlin side: floating azkar service, overlay permission,
/// battery settings and the home-screen widget.
class NativeBridge {
  static const _ch = MethodChannel('azkarak/native');

  static Future<bool> canDrawOverlays() async =>
      await _ch.invokeMethod<bool>('canDrawOverlays') ?? false;

  static Future<void> openOverlaySettings() => _ch.invokeMethod('openOverlaySettings');

  static Future<void> openBatterySettings() => _ch.invokeMethod('openBatterySettings');

  static Future<bool> isOverlayRunning() async =>
      await _ch.invokeMethod<bool>('isOverlayRunning') ?? false;

  /// Starts (or restarts) the floating azkar service with [config].
  /// [customTexts] are the user's own azkar, included when enabled.
  static Future<void> startOverlay(OverlayConfig config, List<String> customTexts) =>
      _ch.invokeMethod('startOverlay', {
        'config': jsonEncode({
          ...config.toJson(),
          'custom': config.includeCustom ? customTexts : <String>[],
        }),
      });

  /// Last attempt to show the floating window: status ("shown", "no_permission",
  /// "error:..."), time, phone manufacturer and Android SDK level.
  static Future<Map<String, Object?>> overlayStatus() async =>
      (await _ch.invokeMapMethod<String, Object?>('overlayStatus')) ?? const {};

  static Future<void> stopOverlay() => _ch.invokeMethod('stopOverlay');

  /// Shows one floating zekr right away so the user can preview the design.
  static Future<void> previewOverlay(OverlayConfig config, List<String> customTexts) =>
      _ch.invokeMethod('previewOverlay', {
        'config': jsonEncode({
          ...config.toJson(),
          'custom': config.includeCustom ? customTexts : <String>[],
        }),
      });

  static Future<void> refreshWidget() => _ch.invokeMethod('refreshWidget');

  static Future<bool> requestPinWidget() async =>
      await _ch.invokeMethod<bool>('requestPinWidget') ?? false;
}
