import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/genius_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/genius/genius_client.dart';

/// App settings dialog. Currently contains the language picker and the
/// Genius settings: token + auto-enrich-on-import flag.
///
/// Owns both the content and the buttons within a single widget tree, so
/// saving is done directly from `_save()` without passing callbacks through
/// `actions`.
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late final TextEditingController _tokenController;
  bool _testing = false;
  String? _testResult; // null = idle
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(geniusTokenProvider);
    _tokenController = TextEditingController(text: current ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final value = _tokenController.text.trim();
    await ref
        .read(geniusTokenProvider.notifier)
        .set(value.isEmpty ? null : value);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          value.isEmpty ? l10n.settingsTokenRemoved : l10n.settingsTokenSaved,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _tokenController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _testResult = l10n.settingsEnterTokenToTest;
        _testOk = false;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = GeniusClient(raw);
    try {
      final hits = await client.search('test', perPage: 1);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = true;
        _testResult = l10n.settingsTokenWorks(hits.length);
      });
    } on GeniusException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = l10n.settingsGenericError('$e');
      });
    } finally {
      client.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.settingsTitle,
                style: const TextStyle(
                  fontFamily: AppFonts.family,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LabeledField(
                        label: l10n.settingsLanguageLabel,
                        child: const _LanguagePicker(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        l10n.settingsGeniusDescription,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: l10n.settingsGeniusTokenLabel,
                        child: _TokenInput(controller: _tokenController),
                      ),
                      const SizedBox(height: 6),
                      const _TokenStatusRow(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _TestButton(
                            testing: _testing,
                            onPressed: _test,
                          ),
                          if (_testResult != null)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  _testResult!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.family,
                                    color: _testOk
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: l10n.settingsAutoEnrichLabel,
                        child: const _AutoEnrichToggle(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.settingsGetTokenInstructions,
                        style: const TextStyle(
                          fontFamily: AppFonts.family,
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      const _LyricsSourceInfo(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: l10n.settingsCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: l10n.settingsSave,
                    primary: true,
                    onTap: _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _TokenInput extends StatefulWidget {
  final TextEditingController controller;
  const _TokenInput({required this.controller});

  @override
  State<_TokenInput> createState() => _TokenInputState();
}

class _TokenInputState extends State<_TokenInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: TextField(
        controller: widget.controller,
        cursorColor: AppColors.textPrimary,
        style: const TextStyle(
          fontFamily: AppFonts.family,
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: l10n.settingsTokenHint,
          hintStyle: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textMuted,
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: _focused
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  final bool testing;
  final VoidCallback onPressed;
  const _TestButton({required this.testing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: testing ? null : onPressed,
      icon: testing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.wifi_tethering_error_outlined, size: 18),
      label: Text(testing ? l10n.settingsTesting : l10n.settingsTest),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _AutoEnrichToggle extends ConsumerWidget {
  const _AutoEnrichToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final value = ref.watch(geniusAutoEnrichProvider);
    final hasClient = ref.watch(geniusClientProvider) != null;
    // Without a valid token the toggle is disabled: the feature wouldn't
    // work anyway (in `LibraryController.scan` a null enricher means the
    // branch is skipped), and the user should see why.
    final disabled = !hasClient;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled
            ? null
            : () => ref.read(geniusAutoEnrichProvider.notifier).set(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: disabled ? false : value,
                onChanged: disabled
                    ? null
                    : (v) => ref
                        .read(geniusAutoEnrichProvider.notifier)
                        .set(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  disabled
                      ? l10n.settingsSetTokenFirst
                      : l10n.settingsAutoEnrichDescription,
                  style: const TextStyle(
                    fontFamily: AppFonts.family,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small status indicator: "Token saved" / "Token not set".
/// Reactive — updates as soon as the user presses "Save" in this dialog,
/// or changes the token elsewhere.
class _TokenStatusRow extends ConsumerWidget {
  const _TokenStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final token = ref.watch(geniusTokenProvider);
    final hasToken = token != null && token.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasToken ? Colors.greenAccent : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          hasToken ? l10n.settingsTokenStatusSaved : l10n.settingsTokenStatusNotSet,
          style: TextStyle(
            fontFamily: AppFonts.family,
            color: hasToken ? AppColors.textSecondary : AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: primary
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: primary ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Info section: lyrics are fetched from LRCLib automatically and require
/// no setup.
class _LyricsSourceInfo extends StatelessWidget {
  const _LyricsSourceInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settingsLyricsSectionTitle,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.settingsLyricsDescription,
          style: const TextStyle(
            fontFamily: AppFonts.family,
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// A row of buttons for picking the UI language (English / Русский).
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    return Row(
      children: [
        _LanguageOption(
          label: 'English',
          selected: current.languageCode == 'en',
          onTap: () => ref.read(localeProvider.notifier).set(const Locale('en')),
        ),
        const SizedBox(width: 8),
        _LanguageOption(
          label: 'Русский',
          selected: current.languageCode == 'ru',
          onTap: () => ref.read(localeProvider.notifier).set(const Locale('ru')),
        ),
      ],
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? Colors.white.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the settings dialog.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const SettingsDialog(),
  );
}
