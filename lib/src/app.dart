import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/editor/presentation/editor_screen.dart';

class PhotoEditorAiApp extends StatelessWidget {
  const PhotoEditorAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Editor AI',
      theme: AppTheme.light(),
      home: const EditorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
