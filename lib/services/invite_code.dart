import 'dart:math';

/// Clinic invite codes, e.g. `DOCRS-7K4MQ-92XPT`.
///
/// The leader shares the code (or a link containing it) and the person joining
/// either opens the link or types the code. Ten random characters from a 31-letter
/// alphabet is about 50 bits, too many to guess. The alphabet leaves out 0/O, 1/I/L
/// so a code read aloud or typed from a photo is not misread.
class InviteCode {
  InviteCode._();

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const _prefix = 'DOCRS';
  static const _length = 10;

  /// A new random code in its display form.
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final chars = [for (var i = 0; i < _length; i++) _alphabet[rng.nextInt(_alphabet.length)]].join();
    return _format(chars);
  }

  /// The canonical code hidden in whatever the user typed or pasted: a bare code,
  /// a code without dashes, lower case, or a whole invite link. Null if none.
  static String? parse(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    // A link: take the value of ?join=CODE, or the last path/fragment piece.
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      text = uri.queryParameters['join'] ?? uri.fragment.split('/').last;
    }

    var chars = text.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    if (chars.length == _prefix.length + _length && chars.startsWith(_prefix)) {
      chars = chars.substring(_prefix.length);
    }
    if (chars.length != _length) return null;
    if (chars.split('').any((c) => !_alphabet.contains(c))) return null;
    return _format(chars);
  }

  /// The link that opens the app and fills the code in.
  static String linkFor(String code, Uri appAddress) =>
      appAddress.removeFragment().replace(queryParameters: {'join': code}).toString();

  static String _format(String chars) => '$_prefix-${chars.substring(0, 5)}-${chars.substring(5)}';
}
