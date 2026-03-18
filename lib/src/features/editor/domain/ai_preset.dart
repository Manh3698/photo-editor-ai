import 'edit_params.dart';

class AiPreset {
  const AiPreset({
    required this.id,
    required this.name,
    required this.reason,
    required this.params,
  });

  final String id;
  final String name;
  final String reason;
  final EditParams params;
}
