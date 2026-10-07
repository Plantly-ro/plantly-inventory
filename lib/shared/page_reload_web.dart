import 'package:web/web.dart' as web;

/// `location.replace(<base href>)`: back to the app root without leaving
/// the signed-in page in the history.
void reloadAppRoot() => web.window.location.replace(web.document.baseURI);
