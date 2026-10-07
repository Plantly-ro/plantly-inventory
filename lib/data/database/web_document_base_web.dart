import 'package:web/web.dart' as web;

/// `document.baseURI` — the `<base href>` the app is served under (not the
/// current route, which the path URL strategy changes per screen).
String documentBaseUri() => web.document.baseURI;
