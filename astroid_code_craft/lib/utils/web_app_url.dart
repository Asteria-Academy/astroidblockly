import 'package:flutter/foundation.dart';

/// Builds the URL used by the embedded Blockly web app.
Uri buildWebAppUri({String? action, String? projectId}) {
  final Uri base = kIsWeb
      ? Uri.parse('${Uri.base.origin}/assets/assets/web_build/index.html')
      : Uri.parse('http://localhost:8080/web_build/index.html');

  return base.replace(queryParameters: {
    if (action != null) 'action': action,
    if (projectId != null && projectId.isNotEmpty) 'id': projectId,
  });
}
