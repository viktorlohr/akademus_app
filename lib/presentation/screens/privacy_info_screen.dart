import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_chrome.dart';

class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  final Color myBlue = const Color(0xFF264358);

  Future<String> _loadHtml(BuildContext context) async {
    final bundle = DefaultAssetBundle.of(context);
    final impressum = await bundle.loadString('assets/impressum.html');
    final datenschutz = await bundle.loadString('assets/datenschutz.html');
    return '${_extractBody(impressum)}<hr>${_extractBody(datenschutz)}';
  }

  String _extractBody(String html) {
    final match = RegExp(
      r'<body>([\s\S]*)<\/body>',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1) ?? html;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impressum | Datenschutz'),
        backgroundColor: Colors.white,
        foregroundColor: myBlue,
        elevation: 0,
      ),
      body: AppBackground(
        child: FutureBuilder<String>(
          future: _loadHtml(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: snapshot.hasData
                    ? SelectionArea(
                        child: Html(
                          data: snapshot.data!,
                          onLinkTap: (url, attributes, element) {
                            if (url == null) return;
                            launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          style: {
                            'body': Style(
                              fontSize: FontSize(14),
                              lineHeight: LineHeight(1.5),
                              color: Colors.black87,
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                            ),
                            'h1': Style(
                              color: myBlue,
                              fontSize: FontSize(20),
                            ),
                            'h2': Style(
                              color: myBlue,
                              fontSize: FontSize(16),
                            ),
                            '.address-box': Style(
                              backgroundColor: Colors.grey.shade100,
                              padding: HtmlPaddings.all(12),
                            ),
                          },
                        ),
                      )
                    : const Text('Inhalt konnte nicht geladen werden.'),
              ),
            );
          },
        ),
      ),
    );
  }
}
