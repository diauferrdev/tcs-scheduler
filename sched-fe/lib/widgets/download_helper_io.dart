import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Mobile/Desktop implementation of download helper
Future<void> downloadFile(String url, String fileName, List<int> bytes) async {
  // Get downloads directory (or documents if not available)
  final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';

  // Write file
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  // Return path for opening
  // Caller should handle opening the file
}
