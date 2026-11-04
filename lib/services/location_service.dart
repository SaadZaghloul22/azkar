import 'package:geolocator/geolocator.dart';

enum LocationResult { ok, serviceOff, denied, deniedForever, error }

class LocationFix {
  final LocationResult result;
  final double? lat;
  final double? lng;
  const LocationFix(this.result, [this.lat, this.lng]);
}

/// Gets the device location once, only after the user has agreed in the UI.
/// The location stays on the device and is used only for prayer times and qibla.
class LocationService {
  static Future<LocationFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix(LocationResult.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) return const LocationFix(LocationResult.denied);
      if (perm == LocationPermission.deniedForever) {
        return const LocationFix(LocationResult.deniedForever);
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return const LocationFix(LocationResult.error);
      return LocationFix(LocationResult.ok, pos.latitude, pos.longitude);
    } catch (_) {
      return const LocationFix(LocationResult.error);
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();
  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static String message(LocationResult r) {
    switch (r) {
      case LocationResult.serviceOff:
        return 'خدمة الموقع مغلقة. فعّلها من إعدادات الهاتف ثم حاول مرة أخرى.';
      case LocationResult.denied:
        return 'لم يتم منح إذن الموقع. يمكنك المحاولة مرة أخرى.';
      case LocationResult.deniedForever:
        return 'إذن الموقع مرفوض دائمًا. افتح إعدادات التطبيق وامنح الإذن.';
      case LocationResult.error:
        return 'تعذّر تحديد الموقع. تأكد من تفعيل GPS وحاول في مكان مفتوح.';
      case LocationResult.ok:
        return '';
    }
  }
}
