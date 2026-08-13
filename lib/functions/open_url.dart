import 'package:url_launcher/url_launcher.dart' as url_launcher;

void openUrl(String url) async {
  try {
    await url_launcher.launchUrl(
      Uri.parse(url),
      mode: url_launcher.LaunchMode.externalApplication,
    );
  } catch (_) {
  }
}
