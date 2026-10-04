import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/branding/app_info.dart';
import '../../core/branding/brand_mark.dart';

/// About screen displaying app details and developer profile.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Extract initials from developer name (e.g. "Nauman" -> "N", "Nauman Khan" -> "NK")
    final nameParts = AppInfo.developer.trim().split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : nameParts.isNotEmpty && nameParts[0].isNotEmpty
            ? nameParts[0][0].toUpperCase()
            : 'NW';

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          40 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          const SizedBox(height: 12),
          const Center(child: BrandMark(size: 92)),
          const SizedBox(height: 20),
          const Center(child: BrandWordmark(fontSize: 34)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              AppInfo.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(child: _VersionPill()),
          const SizedBox(height: 22),

          // Share Button
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: () => _shareApp(buttonContext),
              icon: const Icon(Icons.share_rounded, size: 20),
              label: const Text('Share Net Worth'),
            ),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                AppInfo.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ),

          _sectionLabel(context, 'Developer'),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: CircleAvatar(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  title: Text(
                    AppInfo.developer,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    AppInfo.developerRole,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                _LinkTile(
                  icon: Icons.badge_outlined,
                  label: 'LinkedIn',
                  value: AppInfo.linkedinHandle.isNotEmpty
                      ? '/in/${AppInfo.linkedinHandle}'
                      : AppInfo.linkedinUrl,
                  url: AppInfo.linkedinUrl,
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                _LinkTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: AppInfo.personalEmail,
                  url: 'mailto:${AppInfo.personalEmail}',
                  copyValue: AppInfo.personalEmail,
                ),
                Divider(height: 1, indent: 60, color: cs.outline),
                _LinkTile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Instagram',
                  value: AppInfo.instagramHandle.isNotEmpty
                      ? '@${AppInfo.instagramHandle}'
                      : AppInfo.instagramUrl,
                  url: AppInfo.instagramUrl,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              AppInfo.copyright,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Offline-first · built with Flutter',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// Tap to copy the exact build label.
class _VersionPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        await Clipboard.setData(
          const ClipboardData(text: '${AppInfo.name} ${AppInfo.versionLabel}'),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Version copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Version ${AppInfo.versionLabel}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Future<bool> _tryLaunch(String url) async {
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

Future<void> _openUrl(
  BuildContext context,
  String url, {
  String? copyValue,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await _tryLaunch(url)) return;

  final fallback = copyValue ?? url;
  await Clipboard.setData(ClipboardData(text: fallback));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Copied — $fallback')));
}

Future<void> _shareApp(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      text: AppInfo.shareText,
      subject: AppInfo.name,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.value,
    this.url,
    this.copyValue,
    this.onTap,
  }) : assert(url != null || onTap != null);

  final IconData icon;
  final String label;
  final String value;
  final String? url;
  final String? copyValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(
        url != null ? Icons.open_in_new_rounded : Icons.chevron_right_rounded,
        size: 18,
        color: cs.onSurfaceVariant,
      ),
      onTap: onTap ?? () => _openUrl(context, url!, copyValue: copyValue),
    );
  }
}
