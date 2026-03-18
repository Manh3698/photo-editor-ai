import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_preset_repository.dart';
import '../data/gallery_save_service.dart';
import '../data/image_export_service.dart';
import '../domain/ai_preset.dart';
import '../domain/edit_params.dart';
import '../domain/editor_state.dart';

final aiPresetRepositoryProvider = Provider<AiPresetRepository>((ref) {
  return const AiPresetRepository();
});

final imageExportServiceProvider = Provider<ImageExportService>((ref) {
  return const ImageExportService();
});

final gallerySaveServiceProvider = Provider<GallerySaveService>((ref) {
  return const GallerySaveService();
});

final editorControllerProvider =
    StateNotifierProvider<EditorController, EditorState>((ref) {
  final repo = ref.watch(aiPresetRepositoryProvider);
  final exportService = ref.watch(imageExportServiceProvider);
  final gallerySaveService = ref.watch(gallerySaveServiceProvider);
  return EditorController(repo, exportService, gallerySaveService);
});

class EditorController extends StateNotifier<EditorState> {
  EditorController(
    this._aiPresetRepository,
    this._imageExportService,
    this._gallerySaveService,
  )
      : super(const EditorState());

  final AiPresetRepository _aiPresetRepository;
  final ImageExportService _imageExportService;
  final GallerySaveService _gallerySaveService;

  void setImage(Uint8List bytes) {
    state = state.copyWith(
      originalImage: bytes,
      currentParams: EditParams.neutral,
      history: <EditParams>[],
      future: <EditParams>[],
      aiPresets: <AiPreset>[],
      clearCropAspectRatio: true,
      clearLastExportedBytes: true,
      clearError: true,
    );
  }

  void setCropAspectRatio(double? ratio) {
    state = state.copyWith(cropAspectRatio: ratio);
  }

  void setPrompt(String value) {
    state = state.copyWith(prompt: value);
  }

  void updateParams(EditParams next) {
    final history = List<EditParams>.from(state.history)..add(state.currentParams);
    state = state.copyWith(
      currentParams: next,
      history: history,
      future: <EditParams>[],
    );
  }

  void updateSingleParam({
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
    updateParams(
      state.currentParams.copyWith(
        exposure: exposure,
        brilliance: brilliance,
        brightness: brightness,
        contrast: contrast,
        highlights: highlights,
        shadows: shadows,
        blackPoint: blackPoint,
        saturation: saturation,
        vibrance: vibrance,
        warmth: warmth,
        sharpness: sharpness,
        rotation: rotation,
      ),
    );
  }

  void undo() {
    if (state.history.isEmpty) {
      return;
    }

    final history = List<EditParams>.from(state.history);
    final previous = history.removeLast();
    final future = List<EditParams>.from(state.future)..add(state.currentParams);

    state = state.copyWith(
      currentParams: previous,
      history: history,
      future: future,
    );
  }

  void redo() {
    if (state.future.isEmpty) {
      return;
    }

    final future = List<EditParams>.from(state.future);
    final next = future.removeLast();
    final history = List<EditParams>.from(state.history)..add(state.currentParams);

    state = state.copyWith(
      currentParams: next,
      history: history,
      future: future,
    );
  }

  void toggleBeforeAfter() {
    state = state.copyWith(showBeforeAfter: !state.showBeforeAfter);
  }

  Future<void> suggestWithPrompt() async {
    state = state.copyWith(isLoadingAi: true, clearError: true);

    try {
      final presets = await _aiPresetRepository.suggestPresets(
        state.prompt,
        imageBytes: state.originalImage,
      );

      state = state.copyWith(
        aiPresets: presets,
        isLoadingAi: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingAi: false,
        errorMessage: 'Khong the goi AI luc nay. Da fallback ve preset local.',
      );
    }
  }

  void applyPreset(AiPreset preset) {
    updateParams(preset.params);
  }

  Future<Uint8List?> exportCurrent() async {
    final bytes = state.originalImage;
    if (bytes == null) {
      return null;
    }

    state = state.copyWith(isExporting: true, clearError: true);

    try {
      final exported = await _imageExportService.export(
        sourceBytes: bytes,
        params: state.currentParams,
        cropAspectRatio: state.cropAspectRatio,
      );

      state = state.copyWith(
        isExporting: false,
        lastExportedBytes: exported,
      );
      return exported;
    } catch (_) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Export that bai. Vui long thu lai.',
      );
      return null;
    }
  }

  Future<bool> saveToGallery(Uint8List bytes) {
    return _gallerySaveService.saveJpeg(bytes);
  }
}
