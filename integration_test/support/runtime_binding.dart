import 'dart:async';
import 'dart:convert';
import 'package:integration_test/integration_test.dart';

class SynCareIntegrationBinding extends IntegrationTestWidgetsFlutterBinding {
  final fixture = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> callback(Map<String, String> params) async {
    final message = params['message'];
    if (params['command'] == 'request_data' &&
        message != null &&
        message.startsWith('syncare-fixture:')) {
      if (fixture.isCompleted) {
        return {
          'isError': false,
          'response': {'message': 'fixture_already_received'},
        };
      }
      try {
        final value = jsonDecode(
          utf8.decode(
            base64Url.decode(message.substring('syncare-fixture:'.length)),
          ),
        );
        if (value is! Map<String, dynamic>) throw const FormatException();
        fixture.complete(value);
        return {
          'isError': false,
          'response': {'message': 'fixture_received'},
        };
      } catch (_) {
        return {
          'isError': true,
          'response': {'message': 'invalid_private_fixture'},
        };
      }
    }
    return super.callback(params);
  }
}
