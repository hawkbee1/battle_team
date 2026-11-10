import 'dart:io';

/// Accepts [host]'s self-signed certificate in every `dart:io` HTTP client:
/// the host lookup and the battle socket reach the local stack through
/// Traefik's default certificate.
void trustHost(String host) {
  HttpOverrides.global = _TrustHost(host);
}

class _TrustHost extends HttpOverrides {
  new(this.host);

  final String host;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (_, certificateHost, _) =>
            certificateHost == host;
}
