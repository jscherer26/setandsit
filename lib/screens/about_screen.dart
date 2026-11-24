import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AboutScreen({super.key, required this.onBack});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '0.1.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          if (info.version.isNotEmpty) _version = info.version;
          if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {
      // Graceful fallback to defaults in test or unsupported environments
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _sendFeedback() async {
    final emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'codejuggler26@gmail.com',
      query: _encodeQueryParameters({
        'subject': 'Set&Sit Pre-Release Feedback',
        'body': 'App Version: v$_version (Build $_buildNumber)\n\nFeedback:\n',
      }),
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint('[AboutScreen] Error launching email client: $e');
    }
  }

  Widget _buildLeadingCircle(BuildContext context, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: semantic.sandSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 22,
        color: colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('About Set&Sit'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card with Transparent App Icon, Title, Version & Pre-Release Badge
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/icon/app_icon_transparent.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: semantic.sandSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.spa_rounded,
                            size: 40,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Set&Sit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$_version (Build $_buildNumber)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: semantic.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: semantic.sandSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Pre-Release',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mission Statement Card (in italic font)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Text(
                    'Trauma-sensitive practices designed to fit your unique timeframe.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Voice Technology
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: _buildLeadingCircle(context, Icons.record_voice_over),
                  title: Text(
                    'Voice Technology',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Powered by ElevenLabs 11 v4 voice technology.',
                    style: TextStyle(
                      fontSize: 12,
                      color: semantic.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Send Feedback
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: _buildLeadingCircle(context, Icons.mail_outline_rounded),
                  title: Text(
                    'Send Feedback',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Help us improve during pre-release by sharing your experience.',
                    style: TextStyle(
                      fontSize: 12,
                      color: semantic.muted,
                    ),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    color: semantic.muted,
                    size: 20,
                  ),
                  onTap: _sendFeedback,
                ),
              ),
              const SizedBox(height: 16),

              // Open Source Licenses
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  leading: _buildLeadingCircle(context, Icons.description_outlined),
                  title: Text(
                    'Open Source Licenses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'View software licenses for dependencies',
                    style: TextStyle(
                      fontSize: 12,
                      color: semantic.muted,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: semantic.muted,
                    size: 22,
                  ),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Set&Sit',
                      applicationVersion: 'v$_version (Build $_buildNumber)',
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
