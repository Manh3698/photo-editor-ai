import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../domain/ai_preset.dart';
import '../domain/edit_params.dart';

class AiPresetRepository {
  const AiPresetRepository();

  static const _presetApiUrl = String.fromEnvironment('AI_PRESET_API_URL');
  static const _llmApiUrl = String.fromEnvironment('AI_LLM_API_URL');
  static const _llmApiKey = String.fromEnvironment('AI_LLM_API_KEY');
  static const _llmModel = String.fromEnvironment('AI_LLM_MODEL', defaultValue: 'gpt-4o-mini');

  List<AiPreset> get samplePresets {
    return <AiPreset>[
      _samplePreset(
        name: 'Portrait Soft',
        reason: 'Da min, tang do sang va giu mau da tu nhien.',
        params: const EditParams(
          exposure: 10,
          brilliance: 22,
          brightness: 8,
          highlights: -10,
          shadows: 14,
          contrast: 6,
          blackPoint: -6,
          saturation: 8,
          vibrance: 16,
          warmth: 10,
          sharpness: 8,
        ),
      ),
      _samplePreset(
        name: 'Landscape Pop',
        reason: 'Tang do net va mau cho phong canh, bo troi trong hon.',
        params: const EditParams(
          exposure: 6,
          brilliance: 12,
          brightness: 4,
          highlights: -22,
          shadows: 18,
          contrast: 14,
          blackPoint: 10,
          saturation: 18,
          vibrance: 20,
          warmth: 4,
          sharpness: 20,
        ),
      ),
      _samplePreset(
        name: 'Golden Hour',
        reason: 'Am hon, diu hon va nhin cinematic vao cuoi ngay.',
        params: const EditParams(
          exposure: 8,
          brilliance: 10,
          brightness: 5,
          highlights: -16,
          shadows: 10,
          contrast: 8,
          blackPoint: 6,
          saturation: 10,
          vibrance: 14,
          warmth: 24,
          sharpness: 6,
        ),
      ),
      _samplePreset(
        name: 'Crisp Night',
        reason: 'Kiem soat vung sang, day chi tiet vung toi, tang do net.',
        params: const EditParams(
          exposure: -8,
          brilliance: 18,
          brightness: -6,
          highlights: -30,
          shadows: 22,
          contrast: 18,
          blackPoint: 18,
          saturation: 4,
          vibrance: 10,
          warmth: -8,
          sharpness: 26,
        ),
      ),
      _samplePreset(
        name: 'Film Cool',
        reason: 'Tong mau lanh, tuong phan vua phai va black point sau.',
        params: const EditParams(
          exposure: -2,
          brilliance: 6,
          brightness: -4,
          highlights: -10,
          shadows: 8,
          contrast: 16,
          blackPoint: 22,
          saturation: -8,
          vibrance: 2,
          warmth: -18,
          sharpness: 10,
        ),
      ),
    ];
  }

  Future<List<AiPreset>> suggestPresets(
    String prompt, {
    Uint8List? imageBytes,
  }) async {
    if (_presetApiUrl.isNotEmpty) {
      final remotePresets = await _suggestFromApi(prompt, imageBytes: imageBytes);
      if (remotePresets.isNotEmpty) {
        return remotePresets;
      }
    }

    if (_llmApiUrl.isNotEmpty && _llmApiKey.isNotEmpty) {
      final llmPresets = await _suggestFromLlm(prompt, imageBytes: imageBytes);
      if (llmPresets.isNotEmpty) {
        return llmPresets;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    return _fallbackPresets(prompt);
  }

  Future<List<AiPreset>> _suggestFromApi(
    String prompt, {
    Uint8List? imageBytes,
  }) async {
    try {
      final uri = Uri.parse(_presetApiUrl);
      final body = <String, dynamic>{'prompt': prompt};
      if (imageBytes != null) {
        body['image_base64'] = base64Encode(imageBytes);
      }
      final response = await http
          .post(
            uri,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <AiPreset>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <AiPreset>[];
      }

      final rawPresets = decoded['presets'];
      if (rawPresets is! List) {
        return <AiPreset>[];
      }

      final parsed = <AiPreset>[];
      const id = Uuid();
      for (final item in rawPresets) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final params = item['params'];
        if (params is! Map<String, dynamic>) {
          continue;
        }

        parsed.add(
          AiPreset(
            id: (item['id'] as String?) ?? id.v4(),
            name: (item['name'] as String?) ?? 'AI Preset',
            reason: (item['reason'] as String?) ?? 'Auto generated from API.',
            params: EditParams(
              exposure: _asDouble(params['exposure']),
              brilliance: _asDouble(params['brilliance']),
              brightness: _asDouble(params['brightness']),
              contrast: _asDouble(params['contrast']),
              highlights: _asDouble(params['highlights']),
              shadows: _asDouble(params['shadows']),
              blackPoint: _asDouble(params['blackPoint']),
              saturation: _asDouble(params['saturation']),
              vibrance: _asDouble(params['vibrance']),
              warmth: _asDouble(params['warmth']),
              sharpness: _asDouble(params['sharpness']),
              rotation: _asDouble(params['rotation']),
            ),
          ),
        );
      }

      return parsed.take(5).toList();
    } catch (_) {
      return <AiPreset>[];
    }
  }

  // ── System prompt ─────────────────────────────────────────────────────────
  static const _systemPrompt = '''
You are an expert photo-retouching AI. Your job is to analyse an image (when provided) and the user's creative intent, then recommend 3 distinct adjustment presets.

Return ONLY valid JSON — no markdown fences, no extra text — in exactly this schema:
{"presets": [{"name": string, "reason": string, "params": {"exposure": number, "brilliance": number, "brightness": number, "highlights": number, "shadows": number, "contrast": number, "blackPoint": number, "saturation": number, "vibrance": number, "warmth": number, "sharpness": number, "rotation": number}}]}

Param semantics (all values -100 to 100, default 0):
- exposure: overall EV shift. Positive = brighter overall.
- brilliance: lift midtones and recover detail without blowing highlights.
- brightness: simple linear brightness offset.
- highlights: pull down (negative) or push up blown highlights.
- shadows: lift (positive) or crush shadows.
- contrast: S-curve strength around midpoint 128.
- blackPoint: raise (positive) to crush blacks; lower for lifted / faded look.
- saturation: global colour intensity (negative = desaturate).
- vibrance: boost muted colours while protecting skin tones.
- warmth: positive = warmer/golden, negative = cooler/blue.
- sharpness: micro-contrast edge enhancement.
- rotation: degrees to rotate (-45..45).

Return exactly 3 presets with distinct styles: one "Natural", one "Dramatic", one "Moody". Each "reason" must be 1 concise sentence explaining which image characteristics led to these specific values.'''
;

  Future<List<AiPreset>> _suggestFromLlm(
    String prompt, {
    Uint8List? imageBytes,
  }) async {
    try {
      final uri = Uri.parse(_llmApiUrl);

      // Build the user message — include the image when available (vision models).
      final Object userContent;
      if (imageBytes != null) {
        final b64 = base64Encode(imageBytes);
        userContent = <Object>[
          <String, String>{
            'type': 'text',
            'text': 'User intent: ${prompt.trim().isEmpty ? 'auto enhance this image' : prompt.trim()}',
          },
          <String, Object>{
            'type': 'image_url',
            'image_url': <String, String>{
              'url': 'data:image/jpeg;base64,$b64',
              'detail': 'low',
            },
          },
        ];
      } else {
        userContent = 'User intent: ${prompt.trim().isEmpty ? 'auto enhance image' : prompt.trim()}';
      }

      final response = await http
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_llmApiKey',
            },
            body: jsonEncode(
              <String, dynamic>{
                'model': _llmModel,
                'temperature': 0.4,
                'max_tokens': 800,
                'messages': <Map<String, Object>>[
                  <String, String>{
                    'role': 'system',
                    'content': _systemPrompt,
                  },
                  <String, Object>{
                    'role': 'user',
                    'content': userContent,
                  },
                ],
              },
            ),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <AiPreset>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return <AiPreset>[];
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return <AiPreset>[];
      }

      final firstChoice = choices.first;
      if (firstChoice is! Map<String, dynamic>) {
        return <AiPreset>[];
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        return <AiPreset>[];
      }

      final content = message['content'];
      if (content is! String || content.trim().isEmpty) {
        return <AiPreset>[];
      }

      final parsedJson = _decodeLooseJson(content);
      if (parsedJson == null) {
        return <AiPreset>[];
      }

      return _parsePresets(parsedJson).take(5).toList();
    } catch (_) {
      return <AiPreset>[];
    }
  }

  dynamic _decodeLooseJson(String text) {
    final trimmed = text.trim();
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      final withoutFence = trimmed
          .replaceAll('```json', '')
          .replaceAll('```JSON', '')
          .replaceAll('```', '')
          .trim();

      final start = withoutFence.indexOf('{');
      final end = withoutFence.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final candidate = withoutFence.substring(start, end + 1);
        try {
          return jsonDecode(candidate);
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }

  List<AiPreset> _parsePresets(dynamic jsonObject) {
    if (jsonObject is! Map<String, dynamic>) {
      return <AiPreset>[];
    }

    final rawPresets = jsonObject['presets'];
    if (rawPresets is! List) {
      return <AiPreset>[];
    }

    const id = Uuid();
    final parsed = <AiPreset>[];
    for (final item in rawPresets) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final params = item['params'];
      if (params is! Map<String, dynamic>) {
        continue;
      }

      parsed.add(
        AiPreset(
          id: (item['id'] as String?) ?? id.v4(),
          name: (item['name'] as String?) ?? 'AI Preset',
          reason: (item['reason'] as String?) ?? 'Generated by LLM endpoint.',
          params: EditParams(
            exposure: _clampParam(_asDouble(params['exposure'])),
            brilliance: _clampParam(_asDouble(params['brilliance'])),
            brightness: _clampParam(_asDouble(params['brightness'])),
            contrast: _clampParam(_asDouble(params['contrast'])),
            highlights: _clampParam(_asDouble(params['highlights'])),
            shadows: _clampParam(_asDouble(params['shadows'])),
            blackPoint: _clampParam(_asDouble(params['blackPoint'])),
            saturation: _clampParam(_asDouble(params['saturation'])),
            vibrance: _clampParam(_asDouble(params['vibrance'])),
            warmth: _clampParam(_asDouble(params['warmth'])),
            sharpness: _clampParam(_asDouble(params['sharpness'])),
            rotation: _clampParam(_asDouble(params['rotation'])),
          ),
        ),
      );
    }

    return parsed;
  }

  List<AiPreset> _fallbackPresets(String prompt) {
    final random = Random(prompt.trim().hashCode);
    const id = Uuid();

    double pick(double min, double max) {
      final value = min + (max - min) * random.nextDouble();
      return double.parse(value.toStringAsFixed(1));
    }

    return List<AiPreset>.generate(3, (index) {
      return AiPreset(
        id: id.v4(),
        name: 'AI Preset ${index + 1}',
        reason: _reasonForPrompt(prompt, index),
        params: EditParams(
          exposure: pick(-30, 30),
          brilliance: pick(-35, 35),
          brightness: pick(-20, 20),
          contrast: pick(-30, 30),
          highlights: pick(-40, 40),
          shadows: pick(-40, 40),
          blackPoint: pick(-35, 35),
          saturation: pick(-35, 35),
          vibrance: pick(-35, 35),
          warmth: pick(-30, 30),
          sharpness: pick(-25, 25),
          rotation: 0,
        ),
      );
    });
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  double _clampParam(double value) {
    return value.clamp(-100, 100).toDouble();
  }

  String _reasonForPrompt(String prompt, int index) {
    if (prompt.trim().isEmpty) {
      return 'Can bang anh de nhin tu nhien hon.';
    }

    const variants = <String>[
      'Tap trung lam ro chu the theo mo ta prompt.',
      'Tang do tuong phan nhe de phu hop phong cach prompt.',
      'Can bang vung sang va vung toi theo prompt da nhap.',
    ];

    return variants[index % variants.length];
  }

  AiPreset _samplePreset({
    required String name,
    required String reason,
    required EditParams params,
  }) {
    final normalizedId = name.toLowerCase().replaceAll(' ', '_');
    return AiPreset(
      id: 'sample_$normalizedId',
      name: name,
      reason: reason,
      params: params,
    );
  }
}
