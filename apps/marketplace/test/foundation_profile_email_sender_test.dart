@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends FirebaseAuthPlatform {
  String? uid = 'owner_a';
  bool closeOnListen = false;
  bool verified = true;
  String? emailOverride;
  var events = StreamController<UserPlatform?>.broadcast();
  late Future<void> Function(String) reloading;
  Completer<void>? signoutPending;
  final reloads = <String>[], signouts = <String?>[];
  int listening = 0, cancelled = 0;
  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseAuthPlatform setInitialValues(
          {PigeonUserDetails? currentUser, String? languageCode}) =>
      this;
  @override
  UserPlatform? get currentUser => uid == null ? null : _User(this, uid!);
  @override
  Stream<UserPlatform?> authStateChanges() =>
      Stream<UserPlatform?>.multi((sink) {
        listening++;
        var released = false;
        void release() {
          if (released) return;
          released = true;
          cancelled++;
        }

        sink.add(currentUser);
        if (closeOnListen) {
          sink.onCancel = release;
          sink.close();
          return;
        }
        final subscription = events.stream
            .listen(sink.add, onError: sink.addError, onDone: sink.close);
        sink.onCancel = () async {
          release();
          await subscription.cancel();
        };
      });
  void emit(String? owner) {
    uid = owner;
    events.add(currentUser);
  }

  @override
  Future<void> signOut() async {
    final owner = uid;
    signouts.add(owner);
    await signoutPending?.future;
    if (uid == owner) emit(null);
  }
}

class _Factor extends MultiFactorPlatform {
  _Factor(super.auth);
}

class _User extends UserPlatform {
  _User(this.owner, String uid)
      : super(
            owner,
            _Factor(owner),
            PigeonUserDetails(
                userInfo: PigeonUserInfo(
                    uid: uid,
                    isAnonymous: false,
                    isEmailVerified: owner.verified,
                    email: owner.emailOverride ?? '$uid@example.invalid',
                    displayName: 'sdk-$uid'),
                providerData: []));
  final _Auth owner;
  @override
  Future<void> reload() async {
    owner.reloads.add(uid);
    await owner.reloading(uid);
  }
}

class _Headers implements HttpHeaders {
  final values = <String, List<String>>{
    'content-type': ['application/json; charset=utf-8']
  };
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void forEach(void Function(String, List<String>) action) =>
      values.forEach(action);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body);
  @override
  final int statusCode;
  final String body;
  @override
  final _Headers headers = _Headers();
  @override
  int get contentLength => utf8.encode(body).length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  String get reasonPhrase => 'local fixture response';
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(utf8.encode(body)).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.client, this.method, this.uri);
  final _Client client;
  @override
  final String method;
  @override
  final Uri uri;
  final bytes = <int>[];
  @override
  final _Headers headers = _Headers();
  @override
  bool followRedirects = false, persistentConnection = false;
  @override
  int maxRedirects = 5, contentLength = -1;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() => client.reply(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  late Future<HttpClientResponse> Function(_Request) reply;
  final requests = <_Request>[];
  int closed = 0;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (method != 'POST' || !url.path.endsWith('/sendEmailOTP')) {
      throw StateError('Unexpected local fixture route');
    }
    final request = _Request(this, method, url);
    requests.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {
    closed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  late _Auth auth;
  late AuthService service;
  late _Client client;
  Future<void> drain() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> send() => HttpOverrides.runZoned(
        () => service.sendEmailOtpForProfile('owner_a@example.invalid'),
        createHttpClient: (context) => client,
      );
  Matcher refusal(String code) =>
      isA<AuthException>().having((e) => e.code, 'code', code);
  setUpAll(() async {
    await Firebase.initializeApp();
    auth = _Auth();
    FirebaseAuthPlatform.instance = auth;
    service = AuthService();
  });
  setUp(() {
    auth.uid = 'owner_a';
    auth.closeOnListen = false;
    auth.events = StreamController<UserPlatform?>.broadcast();
    client = _Client();
    client.reply = (request) async => _Response(200, '{"success":true}');
  });
  tearDown(() async {
    await auth.events.close();
    await drain();
  });
  test(
      'current confirmed send keeps original payload and closes in-memory transport',
      () async {
    await send();
    expect(client.requests.length, 1);
    final request = client.requests.single;
    expect(request.method, 'POST');
    expect(jsonDecode(utf8.decode(request.bytes)),
        {'email': 'owner_a@example.invalid'});
    expect(request.headers.values['content-type'], ['application/json']);
    expect(client.closed, 1);
  });
  test('signed-out profile sender rejects before any transport dispatch',
      () async {
    auth.uid = null;
    await expectLater(send(), throwsA(refusal('UNAUTHORIZED')));
    expect(client.requests, isEmpty);
  });
  const messages = {
    400: ['Email is required', 'Invalid email format'],
    429: [
      'Please wait before requesting another code',
      'Too many code requests for this address today. Please try again later.',
      'Too many code requests from this network today. Please try again later.'
    ],
    502: ['Could not deliver the verification code. Please try again shortly.'],
  };
  for (final entry in messages.entries) {
    for (final message in entry.value) {
      test(
          'known ${entry.key} validation message remains safe and compatible: $message',
          () async {
        client.reply = (request) async => _Response(
            entry.key,
            jsonEncode(
                {'success': false, 'error': message, 'retryAfterMs': 30000}));
        if (entry.key == 429) {
          await expectLater(
              send(),
              throwsA(isA<PhoneOtpRateLimitException>()
                  .having((e) => e.message, 'message', message)
                  .having((e) => e.retryAfterMs, 'retry', 30000)));
        } else {
          await expectLater(
              send(),
              throwsA(isA<AuthException>()
                  .having((e) => e.message, 'message', message)));
        }
      });
    }
  }
  for (final status in [400, 429, 500, 502]) {
    for (final value in [
      'private fixture transport stack',
      {'message': 'private fixture object'}
    ]) {
      test(
          'unknown $status server text ${value.runtimeType} never becomes user copy',
          () async {
        client.reply = (request) async =>
            _Response(status, jsonEncode({'success': false, 'error': value}));
        await expectLater(
            send(),
            throwsA(isA<AuthException>().having(
                (e) => e.message,
                'message',
                status == 429
                    ? 'Too many verification requests. Please try again later.'
                    : 'Failed to send verification code. Please try again.')));
      });
    }
  }
  for (final body in [
    'not JSON',
    '[]',
    'null',
    '{}',
    '{"success":false}',
    '{"success":"true"}',
    '{"success":1}'
  ]) {
    test(
        'unconfirmed or malformed success body $body does not confirm delivery',
        () async {
      client.reply = (request) async => _Response(200, body);
      await expectLater(
          send(),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              'Failed to send verification code. Please try again.')));
    });
  }
  for (final value in [null, -1, '30000', {}, true]) {
    test(
        'invalid retry metadata $value is omitted while rate-limit type remains',
        () async {
      client.reply = (request) async =>
          _Response(429, jsonEncode({'success': false, 'retryAfterMs': value}));
      await expectLater(
          send(),
          throwsA(isA<PhoneOtpRateLimitException>()
              .having((e) => e.retryAfterMs, 'retry', isNull)));
    });
  }
  test(
      'finite decimal retry metadata remains compatible with integer countdown',
      () async {
    client.reply = (request) async => _Response(429, '{"retryAfterMs":1234.9}');
    await expectLater(
        send(),
        throwsA(isA<PhoneOtpRateLimitException>()
            .having((e) => e.retryAfterMs, 'retry', 1234)));
  });
  test('malformed rate-limit response remains typed and uses safe fallback',
      () async {
    client.reply =
        (request) async => _Response(429, 'fixture non-json rate-limit body');
    await expectLater(
        send(),
        throwsA(isA<PhoneOtpRateLimitException>().having(
            (e) => e.message,
            'message',
            'Too many verification requests. Please try again later.')));
  });
  for (final failure in [
    StateError('private fixture failure'),
    SocketException('private fixture address'),
    FormatException('private fixture format')
  ]) {
    test('${failure.runtimeType} transport failure never becomes user copy',
        () async {
      client.reply = (request) => Future.error(failure);
      await expectLater(
          send(),
          throwsA(isA<AuthException>().having((e) => e.message, 'message',
              'Failed to send verification code. Please try again.')));
      expect(client.closed, 1);
    });
  }
  test('timeout preserves safe slow-network message', () async {
    client.reply =
        (request) => Future.error(TimeoutException('private fixture timeout'));
    await expectLater(
        send(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message',
            'Network is too slow right now. Please try again.')));
  });
  for (final transition in [
    'switch',
    'before_event',
    'renewal',
    'error',
    'done'
  ]) {
    for (final failure in [false, true]) {
      test(
          'held ${failure ? 'failure' : 'success'} after $transition cannot confirm old-session send',
          () async {
        final entered = Completer<void>(), release = Completer<void>();
        client.reply = (request) async {
          entered.complete();
          await release.future;
          if (failure) {
            throw StateError('private late fixture failure');
          }
          return _Response(200, '{"success":true}');
        };
        final listenBefore = auth.listening, cancelBefore = auth.cancelled;
        final result = expectLater(send(), throwsA(refusal('session-changed')));
        await entered.future;
        await drain();
        switch (transition) {
          case 'switch':
            auth.emit('owner_b');
            break;
          case 'before_event':
            auth.uid = 'owner_b';
            break;
          case 'renewal':
            auth.emit('owner_a');
            break;
          case 'error':
            auth.events.addError(StateError('fixture auth stream failure'));
            break;
          case 'done':
            await auth.events.close();
            break;
        }
        await drain();
        release.complete();
        await result;
        expect(client.requests.length, 1);
        expect(client.closed, 1);
        await drain();
        expect(auth.listening - listenBefore, 1);
        expect(auth.cancelled - cancelBefore, 1);
      });
    }
  }
  for (final failure in [false, true]) {
    test(
        'current ${failure ? 'failure' : 'success'} releases one native SDK operation listener',
        () async {
      final before = auth.listening, cancelled = auth.cancelled;
      if (failure) {
        client.reply =
            (request) => Future.error(StateError('private fixture failure'));
        await expectLater(send(), throwsA(isA<AuthException>()));
      } else {
        await send();
      }
      await drain();
      expect(auth.listening - before, 1);
      expect(auth.cancelled - cancelled, 1);
    });
  }
  test('closed initial SDK stream cannot confirm sender and releases listener',
      () async {
    auth.closeOnListen = true;
    final before = auth.cancelled;
    await expectLater(send(), throwsA(refusal('session-changed')));
    await drain();
    expect(auth.cancelled - before, 1);
  });
  test('nonfinite retry metadata stays typed and omits invalid countdown',
      () async {
    client.reply = (request) async => _Response(429, '{"retryAfterMs":1e999}');
    await expectLater(
        send(),
        throwsA(isA<PhoneOtpRateLimitException>()
            .having((e) => e.retryAfterMs, 'retry', isNull)));
  });
  test('current typed server refusal releases its native operation listener',
      () async {
    final before = auth.listening, cancelled = auth.cancelled;
    client.reply = (request) async =>
        _Response(400, '{"success":false,"error":"Email is required"}');
    await expectLater(send(), throwsA(isA<AuthException>()));
    await drain();
    expect(auth.listening - before, 1);
    expect(auth.cancelled - cancelled, 1);
  });
}
