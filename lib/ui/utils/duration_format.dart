import '../../l10n/app_localizations.dart';

String formatDuration(Duration d) {
  if (d.inSeconds <= 0) return '0:00';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$m:$ss';
}

String formatLongDuration(AppLocalizations l10n, Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return l10n.durationHoursMinutes(h, m);
  return l10n.durationMinutes(m);
}
