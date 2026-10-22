import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Why a location request did not produce a coordinate.
enum LocationFailure {
  /// The user declined, or has not been asked yet and declined when asked.
  permissionDenied,

  /// Declined with "don't ask again" — only the system settings screen can
  /// undo this, so the UI has to offer that rather than asking again.
  permissionPermanentlyDenied,

  /// Location is switched off device-wide.
  servicesDisabled,

  /// No fix arrived in time.
  timeout,

  unavailable,
}

/// The result of asking for the device's position.
class DeviceLocationResult {
  const DeviceLocationResult.success({
    required this.latitude,
    required this.longitude,
    this.accuracyMetres,
  }) : failure = null;

  const DeviceLocationResult.failure(this.failure)
      : latitude = null,
        longitude = null,
        accuracyMetres = null;

  final double? latitude;
  final double? longitude;
  final double? accuracyMetres;
  final LocationFailure? failure;

  bool get isSuccess => failure == null && latitude != null && longitude != null;
}

/// A single GPS fix, on demand.
///
/// Implemented over the platform's own `LocationManager` through the
/// `com.mediassist.app/location` channel rather than a plugin: the app wants
/// one coordinate when the user taps a button, never a stream and never
/// anything in the background, and a dependency that can do continuous
/// tracking would be a larger permission surface than the feature needs.
class DeviceLocationService extends GetxService {
  static DeviceLocationService get to => Get.find();

  static const MethodChannel _channel =
      MethodChannel('com.mediassist.app/location');

  /// Whether location permission is already held, without prompting.
  Future<bool> get hasPermission async {
    if (!Platform.isAndroid) return false;
    return await ph.Permission.locationWhenInUse.isGranted;
  }

  /// Asks for location permission, prompting if it has not been asked before.
  Future<ph.PermissionStatus> requestPermission() async {
    if (!Platform.isAndroid) return ph.PermissionStatus.denied;
    return await ph.Permission.locationWhenInUse.request();
  }

  /// Takes one fix, requesting permission first if needed.
  ///
  /// [timeout] bounds the wait for a live fix; a cached fix from the last ten
  /// minutes short-circuits it entirely, which is what makes the common case
  /// feel instant.
  Future<DeviceLocationResult> currentPosition({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!Platform.isAndroid) {
      return const DeviceLocationResult.failure(LocationFailure.unavailable);
    }

    final status = await ph.Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      final requested = await requestPermission();
      if (!requested.isGranted) {
        return DeviceLocationResult.failure(
          requested.isPermanentlyDenied
              ? LocationFailure.permissionPermanentlyDenied
              : LocationFailure.permissionDenied,
        );
      }
    }

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'current',
        {'timeoutMs': timeout.inMilliseconds},
      );
      if (raw == null) {
        return const DeviceLocationResult.failure(LocationFailure.unavailable);
      }
      final latitude = (raw['latitude'] as num?)?.toDouble();
      final longitude = (raw['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return const DeviceLocationResult.failure(LocationFailure.unavailable);
      }
      return DeviceLocationResult.success(
        latitude: latitude,
        longitude: longitude,
        accuracyMetres: (raw['accuracy'] as num?)?.toDouble(),
      );
    } on PlatformException catch (e) {
      debugPrint('📍 Location request failed: ${e.code} ${e.message}');
      return DeviceLocationResult.failure(_failureFor(e.code));
    } catch (e) {
      debugPrint('📍 Location request failed: $e');
      return const DeviceLocationResult.failure(LocationFailure.unavailable);
    }
  }

  static LocationFailure _failureFor(String code) {
    switch (code) {
      case 'permission_denied':
        return LocationFailure.permissionDenied;
      case 'location_off':
        return LocationFailure.servicesDisabled;
      case 'timeout':
        return LocationFailure.timeout;
      default:
        return LocationFailure.unavailable;
    }
  }

  /// Opens the app's system settings page, for the permanently-denied case.
  Future<void> openSystemSettings() => ph.openAppSettings();
}
