import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yobalema/core/api/yobalema_api.dart';
import 'package:yobalema/core/utils/error_helper.dart';

const _storedToken = 'stored-token';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('cleanErrorMessage tests', () {
    test('Cleans ClientException failed to fetch string completely', () {
      const rawError = 'ClientException: Failed to fetch, uri=http://localhost:4000/api/auth/login';
      final clean = cleanErrorMessage(rawError);
      expect(clean.contains('Failed to fetch'), false);
      expect(clean.contains('localhost:4000'), false);
      expect(clean.contains('ClientException'), false);
      expect(clean, 'Serveur injoignable. Vérifiez votre connexion internet ou réessayez plus tard.');
    });

    test('Cleans corrupted replaceFirst result Clientfailed to fetch', () {
      const rawError = 'Clientfailed to fetch,uri=http://localhost:4000/api/auth/login';
      final clean = cleanErrorMessage(rawError);
      expect(clean.contains('Clientfailed'), false);
      expect(clean.contains('localhost:4000'), false);
      expect(clean, 'Serveur injoignable. Vérifiez votre connexion internet ou réessayez plus tard.');
    });

    test('Cleans SocketException connection refused', () {
      const rawError = 'SocketException: OS Error: Connection refused, errno = 111, address = localhost, port = 4000';
      final clean = cleanErrorMessage(rawError);
      expect(clean.contains('SocketException'), false);
      expect(clean.contains('errno = 111'), false);
      expect(clean, 'Serveur injoignable. Vérifiez votre connexion internet ou réessayez plus tard.');
    });

    test('Preserves user-friendly validation messages', () {
      const validationError = 'Exception: Identifiants invalides ou mot de passe incorrect.';
      final clean = cleanErrorMessage(validationError);
      expect(clean, 'Identifiants invalides ou mot de passe incorrect.');
    });
  });

  group('YobalemaApi session validation tests', () {
    test('validates and refreshes the cached user before restoring it', () async {
      SharedPreferences.setMockInitialValues({
        'yobalema_token': _storedToken,
        'yobalema_user': '{"id":"user-1","phone":"+221770000001","role":"PASSENGER"}',
        'yobalema_role': 'PASSENGER',
      });
      final api = YobalemaApi(
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer $_storedToken');
          return http.Response('{"id":"user-1","phone":"+221770000001","role":"PASSENGER","name":"Validated"}', 200);
        }),
      );

      final session = await api.restoreSession(validate: true);

      expect(session?['role'], 'PASSENGER');
      expect((session?['user'] as Map)['name'], 'Validated');
    });

    test('clears an expired cached token after a 401 response', () async {
      SharedPreferences.setMockInitialValues({
        'yobalema_token': _storedToken,
        'yobalema_user': '{"id":"user-1","role":"PASSENGER"}',
        'yobalema_role': 'PASSENGER',
      });
      final api = YobalemaApi(
        client: MockClient((request) async => http.Response('{"error":"Token invalide ou expiré"}', 401)),
      );

      final session = await api.restoreSession(validate: true);
      final prefs = await SharedPreferences.getInstance();

      expect(session, isNull);
      expect(prefs.getString('yobalema_token'), isNull);
      expect(api.token, isNull);
    });

    test('keeps the cached session only when the backend is unreachable', () async {
      SharedPreferences.setMockInitialValues({
        'yobalema_token': _storedToken,
        'yobalema_user': '{"id":"user-1","role":"PASSENGER"}',
        'yobalema_role': 'PASSENGER',
      });
      final api = YobalemaApi(
        client: MockClient((request) async => throw http.ClientException('Connection refused')),
      );

      final session = await api.restoreSession(validate: true);

      expect(session?['token'], _storedToken);
      expect((session?['user'] as Map)['id'], 'user-1');
    });
  });

  group('YobalemaApi authentication contract tests', () {
    test('login sends credentials and stores the returned token', () async {
      SharedPreferences.setMockInitialValues({});
      final api = YobalemaApi(
        client: MockClient((request) async => http.Response(
          '{"token":"fresh-token","user":{"id":"driver-1","role":"DRIVER"}}',
          200,
        )),
      );

      final result = await api.login('+221770000001', 'password');
      final prefs = await SharedPreferences.getInstance();

      expect(result['token'], 'fresh-token');
      expect(api.token, 'fresh-token');
      expect(prefs.getString('yobalema_token'), 'fresh-token');
      expect(prefs.getString('yobalema_role'), 'DRIVER');
    });

      test('login propagates a backend authentication error', () async {
        final api = YobalemaApi(
          client: MockClient((request) async =>
              http.Response('{"error":"Identifiants invalides"}', 401)),
        );

        expect(
          () => api.login('+221770000001', 'wrong'),
          throwsA(
            predicate<Object>(
              (error) => error.toString().contains('Identifiants invalides'),
            ),
          ),
        );
      });

      test('ride history does not hide an expired session', () async {
        final api = YobalemaApi(
          client: MockClient((request) async =>
              http.Response('{"error":"Token invalide ou expiré"}', 401)),
        )..token = _storedToken;

        expect(
          api.ridesHistory(),
          throwsA(predicate<Object>(
            (error) => error.toString().contains('Token invalide ou expiré'),
          )),
        );
      });

      test('notifications do not hide an expired session', () async {
        final api = YobalemaApi(
          client: MockClient((request) async =>
              http.Response('{"error":"Token invalide ou expiré"}', 401)),
        )..token = _storedToken;

        expect(
          api.notifications(),
          throwsA(predicate<Object>(
            (error) => error.toString().contains('Token invalide ou expiré'),
          )),
        );
      });
    });
}

