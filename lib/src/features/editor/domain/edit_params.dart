class EditParams {
  const EditParams({
    this.exposure = 0,
    this.brilliance = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.blackPoint = 0,
    this.saturation = 0,
    this.vibrance = 0,
    this.warmth = 0,
    this.sharpness = 0,
    this.rotation = 0,
  });

  final double exposure;
  final double brilliance;
  final double brightness;
  final double contrast;
  final double highlights;
  final double shadows;
  final double blackPoint;
  final double saturation;
  final double vibrance;
  final double warmth;
  final double sharpness;
  final double rotation;

  EditParams copyWith({
    double? exposure,
    double? brilliance,
    double? brightness,
    double? contrast,
    double? highlights,
    double? shadows,
    double? blackPoint,
    double? saturation,
    double? vibrance,
    double? warmth,
    double? sharpness,
    double? rotation,
  }) {
    return EditParams(
      exposure: exposure ?? this.exposure,
      brilliance: brilliance ?? this.brilliance,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      blackPoint: blackPoint ?? this.blackPoint,
      saturation: saturation ?? this.saturation,
      vibrance: vibrance ?? this.vibrance,
      warmth: warmth ?? this.warmth,
      sharpness: sharpness ?? this.sharpness,
      rotation: rotation ?? this.rotation,
    );
  }

  static const neutral = EditParams();
}
