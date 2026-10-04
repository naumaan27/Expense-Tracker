/// Helper for custom recurring frequencies (e.g. every 3 months, 5 years, etc.).
class CustomRecurrence {
  const CustomRecurrence({
    required this.interval,
    required this.unit,
  });

  final int interval; // e.g. 3, 5, 2
  final String unit; // 'days', 'weeks', 'months', 'years'

  static CustomRecurrence? parse(String? note) {
    if (note == null || note.isEmpty) return null;
    final match = RegExp(r'\[repeat:(\d+):([a-z]+)\]').firstMatch(note);
    if (match != null) {
      final interval = int.tryParse(match.group(1) ?? '1') ?? 1;
      final unit = match.group(2) ?? 'months';
      return CustomRecurrence(interval: interval, unit: unit);
    }
    return null;
  }

  /// Appends or updates the `[repeat:interval:unit]` tag in [originalNote].
  static String embedInNote(String? originalNote, CustomRecurrence? recurrence) {
    final clean = cleanNote(originalNote);
    if (recurrence == null) return clean;
    final tag = '[repeat:${recurrence.interval}:${recurrence.unit.toLowerCase()}]';
    return clean.isEmpty ? tag : '$clean $tag';
  }

  /// Strips the internal recurrence tag from user-facing notes.
  static String cleanNote(String? note) {
    if (note == null) return '';
    return note.replaceAll(RegExp(r'\s*\[repeat:\d+:[a-z]+\]'), '').trim();
  }

  /// Human-readable label (e.g. "Every 3 months", "Every 5 years", "Every 2 weeks").
  String format() {
    final u = unit.toLowerCase();
    final singular = u.endsWith('s') ? u.substring(0, u.length - 1) : u;
    final word = interval == 1 ? singular : (u.endsWith('s') ? u : '${u}s');
    return 'Every $interval $word';
  }
}
