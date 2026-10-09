import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web;

import 'url_strategy.dart';

void configureUrlStrategy() {
  rememberLaunchHref(web.window.location.href);
  usePathUrlStrategy();
}
