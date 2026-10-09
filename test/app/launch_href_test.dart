import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/app/url_strategy.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';

void main() {
  test('launch URL is kept with its #fragment and handed out once (web /join#c= invite)', () {
    rememberLaunchHref('https://inventory.plantly.ro/join#c=ABCD2345');
    rememberLaunchHref('https://inventory.plantly.ro/join'); // later reads (history rewrote it) never win
    final href = takeLaunchHref();
    expect(href, 'https://inventory.plantly.ro/join#c=ABCD2345');
    expect(extractJoinCode(Uri.parse(href!)), 'ABCD2345');
    expect(takeLaunchHref(), isNull, reason: 'consumed');
  });

  test('both invite forms resolve: /join?c= and /join#c=', () {
    expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join?c=abcd-2345')), 'ABCD2345');
    expect(extractJoinCode(Uri.parse('https://inventory.plantly.ro/join#c=abcd-2345')), 'ABCD2345');
  });
}
