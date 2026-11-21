import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Simple representation of a picked signature file for processing and testing.
class PickedSignatureFile {
  final String name;
  final Uint8List bytes;
  final int? size;

  const PickedSignatureFile({
    required this.name,
    required this.bytes,
    this.size,
  });
}

/// Result of signature file validation.
class SignatureValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Uint8List? bytes;
  final String? fileName;

  const SignatureValidationResult.success({
    required this.bytes,
    required this.fileName,
  })  : isValid = true,
        errorMessage = null;

  const SignatureValidationResult.failure(this.errorMessage)
      : isValid = false,
        bytes = null,
        fileName = null;
}

/// Service to handle signature file picking, validation, and encoding.
class SignatureService {
  static const int maxFileSize = 1024 * 1024; // 1 MB (1,048,576 bytes)
  static const List<int> pngMagicBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  /// Test injection hook to simulate file selection in automated tests.
  static Future<PickedSignatureFile?> Function()? filePickerOverride;

  /// Validates a raw file payload for PNG format and 1 MB max size.
  static SignatureValidationResult validateSignatureFile({
    required String fileName,
    required Uint8List bytes,
    int? size,
  }) {
    final effectiveSize = size ?? bytes.length;

    // 1. File size check (Max 1 MB)
    if (effectiveSize > maxFileSize) {
      final sizeMb = (effectiveSize / (1024 * 1024)).toStringAsFixed(2);
      return SignatureValidationResult.failure(
        'File size exceeds 1 MB limit ($sizeMb MB). Please select a PNG image under 1 MB.',
      );
    }

    // 2. Extension check
    final lowerName = fileName.toLowerCase();
    if (!lowerName.endsWith('.png')) {
      return const SignatureValidationResult.failure(
        'Invalid file format. Only transparent PNG images (.png) are supported.',
      );
    }

    // 3. PNG header magic bytes check
    if (bytes.length < 8) {
      return const SignatureValidationResult.failure(
        'Invalid image format. Selected file is not a valid PNG image.',
      );
    }

    for (int i = 0; i < 8; i++) {
      if (bytes[i] != pngMagicBytes[i]) {
        return const SignatureValidationResult.failure(
          'Invalid image format. Selected file is not a valid PNG image.',
        );
      }
    }

    return SignatureValidationResult.success(bytes: bytes, fileName: fileName);
  }

  /// Opens file picker restricted to PNG images and validates the result.
  /// Returns null if user cancelled without selecting a file.
  static Future<SignatureValidationResult?> pickAndValidateSignature() async {
    if (filePickerOverride != null) {
      final picked = await filePickerOverride!();
      if (picked == null) return null;
      return validateSignatureFile(
        fileName: picked.name,
        bytes: picked.bytes,
        size: picked.size,
      );
    }

    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
    );

    if (files.isEmpty) {
      return null; // User cancelled
    }

    final file = files.first;
    try {
      final bytes = await file.readAsBytes();
      final size = file.lengthSync() ?? bytes.length;
      return validateSignatureFile(
        fileName: file.name,
        bytes: bytes,
        size: size,
      );
    } catch (_) {
      return const SignatureValidationResult.failure(
        'Unable to read file content. Please try another PNG file.',
      );
    }
  }

  /// Helper to generate a minimal valid 1x1 transparent PNG for tests.
  static Uint8List createDummyPngBytes() {
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG Magic Header
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND
      0x42, 0x60, 0x82,
    ]);
  }
}
