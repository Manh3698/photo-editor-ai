import 'dart:typed_data';

import 'ai_preset.dart';
import 'edit_params.dart';

class EditorState {
  const EditorState({
    this.originalImage,
    this.currentParams = EditParams.neutral,
    this.history = const [],
    this.future = const [],
    this.isLoadingAi = false,
    this.isExporting = false,
    this.aiPresets = const [],
    this.prompt = '',
    this.showBeforeAfter = false,
    this.cropAspectRatio,
    this.lastExportedBytes,
    this.errorMessage,
  });

  final Uint8List? originalImage;
  final EditParams currentParams;
  final List<EditParams> history;
  final List<EditParams> future;
  final bool isLoadingAi;
  final bool isExporting;
  final List<AiPreset> aiPresets;
  final String prompt;
  final bool showBeforeAfter;
  final double? cropAspectRatio;
  final Uint8List? lastExportedBytes;
  final String? errorMessage;

  EditorState copyWith({
    Uint8List? originalImage,
    bool clearImage = false,
    EditParams? currentParams,
    List<EditParams>? history,
    List<EditParams>? future,
    bool? isLoadingAi,
    bool? isExporting,
    List<AiPreset>? aiPresets,
    String? prompt,
    bool? showBeforeAfter,
    double? cropAspectRatio,
    bool clearCropAspectRatio = false,
    Uint8List? lastExportedBytes,
    bool clearLastExportedBytes = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EditorState(
      originalImage: clearImage ? null : (originalImage ?? this.originalImage),
      currentParams: currentParams ?? this.currentParams,
      history: history ?? this.history,
      future: future ?? this.future,
      isLoadingAi: isLoadingAi ?? this.isLoadingAi,
      isExporting: isExporting ?? this.isExporting,
      aiPresets: aiPresets ?? this.aiPresets,
      prompt: prompt ?? this.prompt,
      showBeforeAfter: showBeforeAfter ?? this.showBeforeAfter,
        cropAspectRatio: clearCropAspectRatio
          ? null
          : (cropAspectRatio ?? this.cropAspectRatio),
      lastExportedBytes: clearLastExportedBytes
          ? null
          : (lastExportedBytes ?? this.lastExportedBytes),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
