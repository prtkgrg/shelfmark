import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureStoragePermission() async {
  if (await Permission.manageExternalStorage.isGranted) return true;
  final manageStatus = await Permission.manageExternalStorage.request();
  if (manageStatus.isGranted) return true;

  // Fallback for Android < 11 where MANAGE_EXTERNAL_STORAGE doesn't apply.
  final storageStatus = await Permission.storage.request();
  return storageStatus.isGranted;
}
