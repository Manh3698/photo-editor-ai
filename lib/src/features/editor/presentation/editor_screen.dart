import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../application/editor_controller.dart';
import '../domain/ai_preset.dart';
import '../domain/edit_params.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _promptController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  _AdjustmentKey _selectedAdjustment = _AdjustmentKey.exposure;
  // Split-view divider position (0.0 = all original, 1.0 = all edited).
  double _splitPosition = 0.5;
  bool _splitView = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final samplePresets = ref.watch(aiPresetRepositoryProvider).samplePresets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Photo Editor'),
        actions: <Widget>[
          IconButton(
            onPressed: state.history.isEmpty ? null : controller.undo,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: state.future.isEmpty ? null : controller.redo,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
          IconButton(
            onPressed: state.originalImage == null
                ? null
                : () => setState(() => _splitView = !_splitView),
            icon: Icon(_splitView ? Icons.compare : Icons.compare_outlined),
            tooltip: 'Split before/after',
          ),
          IconButton(
            onPressed: controller.toggleBeforeAfter,
            icon: Icon(state.showBeforeAfter ? Icons.visibility : Icons.visibility_off_outlined),
            tooltip: 'Before / After',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: GestureDetector(
                onVerticalDragUpdate: state.originalImage == null
                    ? null
                    : (details) {
                        // Drag up = increase value, drag down = decrease.
                        final delta = -details.delta.dy * 0.4;
                        final current = _valueForKey(
                          state.currentParams,
                          _selectedAdjustment,
                        );
                        final (min, max) = _rangeForKey(_selectedAdjustment);
                        final next = (current + delta).clamp(min, max);
                        _updateAdjustment(
                          ref.read(editorControllerProvider.notifier),
                          _selectedAdjustment,
                          next,
                        );
                      },
                child: _PreviewArea(
                  bytes: state.originalImage,
                  params:
                      state.showBeforeAfter ? EditParams.neutral : state.currentParams,
                  cropAspectRatio: state.cropAspectRatio,
                  splitView: _splitView,
                  splitPosition: _splitPosition,
                  onSplitDrag: (pos) => setState(() => _splitPosition = pos),
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Upload image'),
                        ),
                        OutlinedButton.icon(
                          onPressed: state.originalImage == null || state.isExporting
                              ? null
                              : () async {
                                  final exported = await controller.exportCurrent();
                                  if (!context.mounted || exported == null) {
                                    return;
                                  }

                                  final saved = await controller.saveToGallery(exported);
                                  if (!context.mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        saved
                                            ? 'Da luu anh vao thu vien may.'
                                            : 'Khong luu duoc anh. Kiem tra quyen Photos/Storage.',
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.download_outlined),
                          label: Text(state.isExporting ? 'Saving...' : 'Save to device'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _CropSection(
                      selectedRatio: state.cropAspectRatio,
                      onSelected: controller.setCropAspectRatio,
                    ),
                    const SizedBox(height: 12),
                    _PresetRow(
                      title: 'Sample presets',
                      presets: samplePresets,
                      onSelect: controller.applyPreset,
                      sourceImage: state.originalImage,
                    ),
                    const SizedBox(height: 12),
                    _PromptSection(
                      controller: _promptController,
                      isLoading: state.isLoadingAi,
                      onGenerate: () async {
                        controller.setPrompt(_promptController.text);
                        await controller.suggestWithPrompt();
                      },
                    ),
                    const SizedBox(height: 14),
                    _PresetRow(
                      title: 'AI suggestions',
                      presets: state.aiPresets,
                      onSelect: controller.applyPreset,
                      sourceImage: state.originalImage,
                    ),
                    const SizedBox(height: 18),
                    _AdjustmentSelector(
                      selected: _selectedAdjustment,
                      onSelected: (key) {
                        setState(() {
                          _selectedAdjustment = key;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActiveAdjustmentSlider(
                      keyType: _selectedAdjustment,
                      value: _valueForKey(state.currentParams, _selectedAdjustment),
                      onChanged: (value) =>
                          _updateAdjustment(controller, _selectedAdjustment, value),
                    ),
                    if (state.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    ref.read(editorControllerProvider.notifier).setImage(bytes);
  }

  double _valueForKey(EditParams params, _AdjustmentKey key) {
    switch (key) {
      case _AdjustmentKey.exposure:
        return params.exposure;
      case _AdjustmentKey.brilliance:
        return params.brilliance;
      case _AdjustmentKey.highlights:
        return params.highlights;
      case _AdjustmentKey.shadows:
        return params.shadows;
      case _AdjustmentKey.contrast:
        return params.contrast;
      case _AdjustmentKey.blackPoint:
        return params.blackPoint;
      case _AdjustmentKey.saturation:
        return params.saturation;
      case _AdjustmentKey.vibrance:
        return params.vibrance;
      case _AdjustmentKey.warmth:
        return params.warmth;
      case _AdjustmentKey.sharpness:
        return params.sharpness;
      case _AdjustmentKey.brightness:
        return params.brightness;
      case _AdjustmentKey.rotation:
        return params.rotation;
    }
  }

  void _updateAdjustment(
    EditorController controller,
    _AdjustmentKey key,
    double value,
  ) {
    switch (key) {
      case _AdjustmentKey.exposure:
        controller.updateSingleParam(exposure: value);
        return;
      case _AdjustmentKey.brilliance:
        controller.updateSingleParam(brilliance: value);
        return;
      case _AdjustmentKey.highlights:
        controller.updateSingleParam(highlights: value);
        return;
      case _AdjustmentKey.shadows:
        controller.updateSingleParam(shadows: value);
        return;
      case _AdjustmentKey.contrast:
        controller.updateSingleParam(contrast: value);
        return;
      case _AdjustmentKey.blackPoint:
        controller.updateSingleParam(blackPoint: value);
        return;
      case _AdjustmentKey.saturation:
        controller.updateSingleParam(saturation: value);
        return;
      case _AdjustmentKey.vibrance:
        controller.updateSingleParam(vibrance: value);
        return;
      case _AdjustmentKey.warmth:
        controller.updateSingleParam(warmth: value);
        return;
      case _AdjustmentKey.sharpness:
        controller.updateSingleParam(sharpness: value);
        return;
      case _AdjustmentKey.brightness:
        controller.updateSingleParam(brightness: value);
        return;
      case _AdjustmentKey.rotation:
        controller.updateSingleParam(rotation: value);
        return;
    }
  }

  (double, double) _rangeForKey(_AdjustmentKey key) {
    if (key == _AdjustmentKey.rotation) return (-45, 45);
    return (-100, 100);
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({
    required this.bytes,
    required this.params,
    required this.cropAspectRatio,
    required this.splitView,
    required this.splitPosition,
    required this.onSplitDrag,
  });

  final Uint8List? bytes;
  final EditParams params;
  final double? cropAspectRatio;
  final bool splitView;
  final double splitPosition;
  final ValueChanged<double> onSplitDrag;

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return Card(
        child: Center(
          child: Text(
            'Chua co anh. Bam Upload image de bat dau.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    final colorFilter = ColorFilter.matrix(_buildMatrix(params));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            if (!splitView) {
              return _buildSingle(colorFilter, w, h, context);
            }
            return _buildSplit(colorFilter, w, h, context);
          },
        ),
      ),
    );
  }

  Widget _buildSingle(
    ColorFilter colorFilter,
    double w,
    double h,
    BuildContext context,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Transform.rotate(
          angle: params.rotation * 0.0174533,
          child: ColorFiltered(
            colorFilter: colorFilter,
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 4,
              child: Image.memory(bytes!, fit: BoxFit.contain),
            ),
          ),
        ),
        if (cropAspectRatio != null)
          FractionallySizedBox(
            widthFactor: 0.82,
            child: AspectRatio(
              aspectRatio: cropAspectRatio!,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSplit(
    ColorFilter colorFilter,
    double w,
    double h,
    BuildContext context,
  ) {
    final dividerX = (splitPosition * w).clamp(4.0, w - 4.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        final newPos = ((details.localPosition.dx) / w).clamp(0.05, 0.95);
        onSplitDrag(newPos);
      },
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: <Widget>[
            // Original (full width underneath)
            Transform.rotate(
              angle: params.rotation * 0.0174533,
              child: Image.memory(bytes!, width: w, height: h, fit: BoxFit.contain),
            ),
            // Edited (clipped to left side of divider)
            ClipRect(
              clipper: _SideClipper(dividerX, w, h),
              child: Transform.rotate(
                angle: params.rotation * 0.0174533,
                child: ColorFiltered(
                  colorFilter: colorFilter,
                  child: Image.memory(
                    bytes!,
                    width: w,
                    height: h,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Divider line + handle
            Positioned(
              left: dividerX - 1,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Row(
                  children: <Widget>[
                    Container(width: 2, color: Colors.white),
                  ],
                ),
              ),
            ),
            Positioned(
              left: dividerX - 18,
              top: h / 2 - 18,
              child: IgnorePointer(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.compare_arrows, size: 20),
                ),
              ),
            ),
            // Labels
            const Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: _SplitLabel('BEFORE'),
              ),
            ),
            const Positioned(
              right: 8,
              top: 8,
              child: IgnorePointer(
                child: _SplitLabel('AFTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds a 4×5 ColorFilter matrix that replicates the export algorithm
  // (image_export_service.dart) as closely as a linear transform allows.
  //
  // Processing order mirrors the export: tone curve → saturation → warmth → sharpness.
  List<double> _buildMatrix(EditParams p) {
    // ── Tone-curve parameters (all offsets in [0,255] space) ──────────────────
    final tC = 1.0 + p.contrast / 100.0;          // contrast factor (around 128)
    final tE = 1.0 + p.exposure / 200.0;           // exposure multiplier
    final tB = (p.brightness / 100.0) * 255.0;    // brightness additive
    final tBr = (p.brilliance / 100.0) * 22.0;    // brilliance additive
    final tH = (p.highlights / 100.0) * 28.0;     // highlights additive budget
    final tSh = (p.shadows / 100.0) * 28.0;       // shadows additive budget
    final tBk = (p.blackPoint / 100.0) * 24.0;   // black-point lift

    // Highlights/shadows linear approximation:
    //   export applies +tH to pixels above 50% luma, +tSh to pixels below.
    //   A proportional approximation: +tH*(v/255) + tSh*(1-v/255)
    //   = v*(tH-tSh)/255 + tSh  →  folds into gain and offset.
    final hs = 1.0 + (tH - tSh) / 255.0;

    // Combined tone: v_out = v * toneG + toneO
    final toneG = tC * tE * hs;
    final toneO = (128.0 * (1.0 - tC) * tE + tB + tBr) * hs + tSh - tBk;

    // ── Saturation + vibrance (BT.709 luma weights, cross-channel mixing) ─────
    // Matches export formula: sat_out = luma + (in - luma) * satGain
    // where luma = wr*R + wg*G + wb*B.  Vibrance averaged as ~0.4 scale.
    final satGain =
        (1.0 + (p.saturation / 100.0) * 0.8) * (1.0 + (p.vibrance / 100.0) * 0.4);
    final q = 1.0 - satGain; // cross-channel weight
    const wr = 0.2126;
    const wg = 0.7152;
    const wb = 0.0722;

    // After composing tone + saturation (proof: sat_R = toneG*(satGain+q*wr)*r
    //   + toneG*q*wg*g + toneG*q*wb*b + toneO, because wr+wg+wb=1):
    final crr = toneG * (satGain + q * wr);
    final crg = toneG * q * wg;
    final crb = toneG * q * wb;
    final cgr = toneG * q * wr;
    final cgg = toneG * (satGain + q * wg);
    final cgb = toneG * q * wb;
    final cbr = toneG * q * wr;
    final cbg = toneG * q * wg;
    final cbb = toneG * (satGain + q * wb);

    // ── Warmth (per-channel multiplier) + sharpness (scale around 128) ────────
    final warmth = p.warmth / 100.0;
    final warmR = 1.0 + warmth * 0.12;
    final warmB = 1.0 - warmth * 0.12;
    final sharpGain = 1.0 + (p.sharpness / 100.0) * 0.18;
    final sharpOffset = 128.0 * (1.0 - sharpGain); // additive to center at 128

    final sR = warmR * sharpGain;
    final sG = sharpGain;
    final sB = warmB * sharpGain;

    return <double>[
      crr * sR, crg * sR, crb * sR, 0, toneO * sR + sharpOffset,
      cgr * sG, cgg * sG, cgb * sG, 0, toneO * sG + sharpOffset,
      cbr * sB, cbg * sB, cbb * sB, 0, toneO * sB + sharpOffset,
      0, 0, 0, 1, 0,
    ];
  }
}

class _SideClipper extends CustomClipper<Rect> {
  const _SideClipper(this.dividerX, this.w, this.h);
  final double dividerX;
  final double w;
  final double h;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, dividerX, h);

  @override
  bool shouldReclip(_SideClipper old) =>
      old.dividerX != dividerX || old.w != w || old.h != h;
}

class _SplitLabel extends StatelessWidget {
  const _SplitLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CropSection extends StatelessWidget {
  const _CropSection({
    required this.selectedRatio,
    required this.onSelected,
  });

  final double? selectedRatio;
  final ValueChanged<double?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Crop ratio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Free'),
              selected: selectedRatio == null,
              onSelected: (_) => onSelected(null),
            ),
            ChoiceChip(
              label: const Text('1:1'),
              selected: selectedRatio == 1,
              onSelected: (_) => onSelected(1),
            ),
            ChoiceChip(
              label: const Text('4:5'),
              selected: selectedRatio == 4 / 5,
              onSelected: (_) => onSelected(4 / 5),
            ),
            ChoiceChip(
              label: const Text('16:9'),
              selected: selectedRatio == 16 / 9,
              onSelected: (_) => onSelected(16 / 9),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Anh goc duoc giu nguyen khi chinh sua. Crop chi ap dung luc export.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.controller,
    required this.isLoading,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('AI prompt', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText:
                      'Vi du: Lam anh am hon, da trong hon, giu chi tiet vung sang',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: isLoading ? null : onGenerate,
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Suggest'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.title,
    required this.presets,
    required this.onSelect,
    this.sourceImage,
  });

  final String title;
  final List<AiPreset> presets;
  final ValueChanged<AiPreset> onSelect;
  final Uint8List? sourceImage;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: sourceImage != null ? 116 : 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final preset = presets[index];
              return _PresetCard(
                preset: preset,
                sourceImage: sourceImage,
                onTap: () => onSelect(preset),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: presets.length,
          ),
        ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.onTap,
    this.sourceImage,
  });

  final AiPreset preset;
  final VoidCallback onTap;
  final Uint8List? sourceImage;

  // Reuse the same matrix builder from _PreviewArea.
  static List<double> _matrix(EditParams p) {
    final tC = 1.0 + p.contrast / 100.0;
    final tE = 1.0 + p.exposure / 200.0;
    final tB = (p.brightness / 100.0) * 255.0;
    final tBr = (p.brilliance / 100.0) * 22.0;
    final tH = (p.highlights / 100.0) * 28.0;
    final tSh = (p.shadows / 100.0) * 28.0;
    final tBk = (p.blackPoint / 100.0) * 24.0;
    final hs = 1.0 + (tH - tSh) / 255.0;
    final toneG = tC * tE * hs;
    final toneO = (128.0 * (1.0 - tC) * tE + tB + tBr) * hs + tSh - tBk;
    final satGain =
        (1.0 + (p.saturation / 100.0) * 0.8) * (1.0 + (p.vibrance / 100.0) * 0.4);
    final qv = 1.0 - satGain;
    const wr = 0.2126;
    const wg = 0.7152;
    const wb = 0.0722;
    final crr = toneG * (satGain + qv * wr);
    final crg = toneG * qv * wg;
    final crb = toneG * qv * wb;
    final cgr = toneG * qv * wr;
    final cgg = toneG * (satGain + qv * wg);
    final cgb = toneG * qv * wb;
    final cbr = toneG * qv * wr;
    final cbg = toneG * qv * wg;
    final cbb = toneG * (satGain + qv * wb);
    final warmth = p.warmth / 100.0;
    final warmR = 1.0 + warmth * 0.12;
    final warmB = 1.0 - warmth * 0.12;
    final sharpGain = 1.0 + (p.sharpness / 100.0) * 0.18;
    final sharpOffset = 128.0 * (1.0 - sharpGain);
    final sR = warmR * sharpGain;
    final sG = sharpGain;
    final sB = warmB * sharpGain;
    return <double>[
      crr * sR, crg * sR, crb * sR, 0, toneO * sR + sharpOffset,
      cgr * sG, cgg * sG, cgb * sG, 0, toneO * sG + sharpOffset,
      cbr * sB, cbg * sB, cbb * sB, 0, toneO * sB + sharpOffset,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (sourceImage != null)
                SizedBox(
                  height: 70,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_matrix(preset.params)),
                    child: Image.memory(
                      sourceImage!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preset.name,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sourceImage == null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        preset.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AdjustmentKey {
  exposure,
  brilliance,
  highlights,
  shadows,
  contrast,
  blackPoint,
  saturation,
  vibrance,
  warmth,
  sharpness,
  brightness,
  rotation,
}

class _AdjustmentSelector extends StatelessWidget {
  const _AdjustmentSelector({
    required this.selected,
    required this.onSelected,
  });

  final _AdjustmentKey selected;
  final ValueChanged<_AdjustmentKey> onSelected;

  static const _items = <(_AdjustmentKey, String, IconData)>[
    (_AdjustmentKey.exposure, 'Exposure', Icons.brightness_6_outlined),
    (_AdjustmentKey.brilliance, 'Brilliance', Icons.auto_awesome_outlined),
    (_AdjustmentKey.highlights, 'Highlights', Icons.wb_sunny_outlined),
    (_AdjustmentKey.shadows, 'Shadows', Icons.nights_stay_outlined),
    (_AdjustmentKey.contrast, 'Contrast', Icons.contrast_outlined),
    (_AdjustmentKey.blackPoint, 'Black Point', Icons.adjust_outlined),
    (_AdjustmentKey.saturation, 'Saturation', Icons.palette_outlined),
    (_AdjustmentKey.vibrance, 'Vibrance', Icons.color_lens_outlined),
    (_AdjustmentKey.warmth, 'Warmth', Icons.thermostat_outlined),
    (_AdjustmentKey.sharpness, 'Sharpness', Icons.details_outlined),
    (_AdjustmentKey.brightness, 'Brightness', Icons.light_mode_outlined),
    (_AdjustmentKey.rotation, 'Rotate', Icons.rotate_right_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (key, title, icon) = _items[index];
          final isSelected = selected == key;
          return GestureDetector(
            onTap: () => onSelected(key),
            child: SizedBox(
              width: 88,
              child: Column(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActiveAdjustmentSlider extends StatelessWidget {
  const _ActiveAdjustmentSlider({
    required this.keyType,
    required this.value,
    required this.onChanged,
  });

  final _AdjustmentKey keyType;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = _titleForKey(keyType);
    final (min, max) = _rangeForKey(keyType);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(value.toStringAsFixed(1)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  String _titleForKey(_AdjustmentKey key) {
    switch (key) {
      case _AdjustmentKey.exposure:
        return 'Exposure';
      case _AdjustmentKey.brilliance:
        return 'Brilliance';
      case _AdjustmentKey.highlights:
        return 'Highlights';
      case _AdjustmentKey.shadows:
        return 'Shadows';
      case _AdjustmentKey.contrast:
        return 'Contrast';
      case _AdjustmentKey.blackPoint:
        return 'Black Point';
      case _AdjustmentKey.saturation:
        return 'Saturation';
      case _AdjustmentKey.vibrance:
        return 'Vibrance';
      case _AdjustmentKey.warmth:
        return 'Warmth';
      case _AdjustmentKey.sharpness:
        return 'Sharpness';
      case _AdjustmentKey.brightness:
        return 'Brightness';
      case _AdjustmentKey.rotation:
        return 'Rotate';
    }
  }

  (double, double) _rangeForKey(_AdjustmentKey key) {
    if (key == _AdjustmentKey.rotation) {
      return (-45, 45);
    }
    return (-100, 100);
  }
}