import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../domain/edit_params.dart';

class ImageExportService {
  const ImageExportService();

  static const _maxPixelsWeb =
      int.fromEnvironment('EXPORT_MAX_PIXELS_WEB', defaultValue: 2 * 1024 * 1024);
  static const _maxPixelsNative =
      int.fromEnvironment('EXPORT_MAX_PIXELS_NATIVE', defaultValue: 12 * 1024 * 1024);
  static const _jpegQualityWeb =
      int.fromEnvironment('EXPORT_JPEG_QUALITY_WEB', defaultValue: 88);
  static const _jpegQualityNative =
      int.fromEnvironment('EXPORT_JPEG_QUALITY_NATIVE', defaultValue: 92);

  Future<Uint8List> export({
    required Uint8List sourceBytes,
    required EditParams params,
    required double? cropAspectRatio,
  }) async {
    final request = _ExportRequest(
      sourceBytes,
      params,
      cropAspectRatio,
      maxPixels: kIsWeb ? _maxPixelsWeb : _maxPixelsNative,
      jpegQuality: kIsWeb ? _jpegQualityWeb : _jpegQualityNative,
    );

    // On web, compute does not move work to a true background isolate.
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return _processImage(request);
    }

    return compute(_processImage, request);
  }
}

class _ExportRequest {
  const _ExportRequest(
    this.sourceBytes,
    this.params,
    this.cropAspectRatio, {
    required this.maxPixels,
    required this.jpegQuality,
  });

  final Uint8List sourceBytes;
  final EditParams params;
  final double? cropAspectRatio;
  final int maxPixels;
  final int jpegQuality;
}

Uint8List _processImage(_ExportRequest input) {
  final decoded = img.decodeImage(input.sourceBytes);
  if (decoded == null) {
    return input.sourceBytes;
  }

  var output = img.Image.from(decoded);

  if (input.cropAspectRatio != null) {
    output = _centerCropWithRatio(output, input.cropAspectRatio!);
  }

  if (input.params.rotation.abs() > 0.1) {
    output = img.copyRotate(output, angle: input.params.rotation);
  }

  output = _resizeToMaxPixels(output, input.maxPixels);

  final hasAnyAdjustment =
      input.params.exposure.abs() > 0.01 ||
      input.params.brilliance.abs() > 0.01 ||
      input.params.brightness.abs() > 0.01 ||
      input.params.contrast.abs() > 0.01 ||
      input.params.highlights.abs() > 0.01 ||
      input.params.shadows.abs() > 0.01 ||
      input.params.blackPoint.abs() > 0.01 ||
      input.params.saturation.abs() > 0.01 ||
      input.params.vibrance.abs() > 0.01 ||
      input.params.warmth.abs() > 0.01 ||
      input.params.sharpness.abs() > 0.01;

  if (!hasAnyAdjustment) {
    final passthrough = img.encodeJpg(output, quality: input.jpegQuality);
    return Uint8List.fromList(passthrough);
  }

  final contrast = 1 + (input.params.contrast / 100.0);
  final brightnessOffset = (input.params.brightness / 100.0) * 255.0;
  final exposureGain = 1 + (input.params.exposure / 200.0);
  final brilliance = input.params.brilliance / 100.0;
  final highlights = input.params.highlights / 100.0;
  final shadows = input.params.shadows / 100.0;
  final blackPoint = input.params.blackPoint / 100.0;
  final saturation = input.params.saturation / 100.0;
  final vibrance = input.params.vibrance / 100.0;
  final warmth = input.params.warmth / 100.0;
  final sharpness = input.params.sharpness / 100.0;

  final satGain = 1 + saturation * 0.8;
  final vibGain = 1 + vibrance * 0.6;
  final sharpGain = 1 + sharpness * 0.18;
  final warmR = 1 + warmth * 0.12;
  final warmB = 1 - warmth * 0.12;
  final applyColorMix = saturation.abs() > 0.001 || vibrance.abs() > 0.001;
  final applyWarmth = warmth.abs() > 0.001;
  final applySharpness = sharpness.abs() > 0.001;

  for (final pixel in output) {
    var r = _adjustChannel(
      pixel.r.toDouble(),
      contrast: contrast,
      brightnessOffset: brightnessOffset,
      exposureGain: exposureGain,
      brilliance: brilliance,
      highlights: highlights,
      shadows: shadows,
      blackPoint: blackPoint,
    );
    var g = _adjustChannel(
      pixel.g.toDouble(),
      contrast: contrast,
      brightnessOffset: brightnessOffset,
      exposureGain: exposureGain,
      brilliance: brilliance,
      highlights: highlights,
      shadows: shadows,
      blackPoint: blackPoint,
    );
    var b = _adjustChannel(
      pixel.b.toDouble(),
      contrast: contrast,
      brightnessOffset: brightnessOffset,
      exposureGain: exposureGain,
      brilliance: brilliance,
      highlights: highlights,
      shadows: shadows,
      blackPoint: blackPoint,
    );

    if (applyColorMix) {
      final luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      final localVibrance =
          1 + (1 - (luma - 0.5).abs() * 2).clamp(0.0, 1.0) * (vibGain - 1);

      r = (luma * 255.0) + (r - luma * 255.0) * satGain * localVibrance;
      g = (luma * 255.0) + (g - luma * 255.0) * satGain * localVibrance;
      b = (luma * 255.0) + (b - luma * 255.0) * satGain * localVibrance;
    }

    if (applyWarmth) {
      r = r * warmR;
      b = b * warmB;
    }

    if (applySharpness) {
      r = (r - 128.0) * sharpGain + 128.0;
      g = (g - 128.0) * sharpGain + 128.0;
      b = (b - 128.0) * sharpGain + 128.0;
    }

    pixel
      ..r = r.clamp(0.0, 255.0).toInt()
      ..g = g.clamp(0.0, 255.0).toInt()
      ..b = b.clamp(0.0, 255.0).toInt();
  }

  final encoded = img.encodeJpg(output, quality: input.jpegQuality);
  return Uint8List.fromList(encoded);
}

img.Image _resizeToMaxPixels(img.Image image, int maxPixels) {
  final currentPixels = image.width * image.height;
  if (currentPixels <= maxPixels) {
    return image;
  }

  final scale = math.sqrt(maxPixels / currentPixels);
  final newWidth = (image.width * scale).round().clamp(1, image.width);
  final newHeight = (image.height * scale).round().clamp(1, image.height);

  return img.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );
}

img.Image _centerCropWithRatio(img.Image image, double ratio) {
  final srcW = image.width.toDouble();
  final srcH = image.height.toDouble();
  final srcRatio = srcW / srcH;

  int cropW;
  int cropH;
  if (srcRatio > ratio) {
    cropH = srcH.toInt();
    cropW = (cropH * ratio).round();
  } else {
    cropW = srcW.toInt();
    cropH = (cropW / ratio).round();
  }

  final x = ((srcW - cropW) / 2).round().clamp(0, image.width - 1);
  final y = ((srcH - cropH) / 2).round().clamp(0, image.height - 1);
  final safeW = cropW.clamp(1, image.width - x);
  final safeH = cropH.clamp(1, image.height - y);

  return img.copyCrop(image, x: x, y: y, width: safeW, height: safeH);
}

double _adjustChannel(
  double value, {
  required double contrast,
  required double brightnessOffset,
  required double exposureGain,
  required double brilliance,
  required double highlights,
  required double shadows,
  required double blackPoint,
}) {
  var adjusted = (value - 128.0) * contrast + 128.0;
  adjusted = adjusted * exposureGain + brightnessOffset;
  adjusted += brilliance * 22.0;

  final luminance = adjusted / 255.0;
  if (luminance > 0.5) {
    adjusted += highlights * 28.0;
  } else {
    adjusted += shadows * 28.0;
  }

  adjusted -= blackPoint * 24.0;

  return adjusted.clamp(0.0, 255.0);
}
