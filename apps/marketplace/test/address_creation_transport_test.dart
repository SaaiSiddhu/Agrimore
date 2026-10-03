import 'package:agrimore_services/agrimore_services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
// ignore: depend_on_referenced_packages
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart'
    as fs;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class RequestCodec extends StandardMessageCodec {
  const RequestCodec();
  @override
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case 130:
        return fs.DocumentReferenceRequest.decode(readValue(buffer)!);
      case 131:
        return fs.FirestorePigeonFirebaseApp.decode(readValue(buffer)!);
      case 135:
        return fs.PigeonFirebaseSettings.decode(readValue(buffer)!);
      case 187:
        return 'server-timestamp-fixture';
      default:
        return super.readValueOfType(type, buffer);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
      RequestCodec());
  final writes = <fs.DocumentReferenceRequest>[];
  setUpAll(() async {
    await Firebase.initializeApp();
  });
  setUp(() {
    writes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, (message) async {
      writes.add((message! as List)[1] as fs.DocumentReferenceRequest);
      return [null];
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, null));
  AddressModel row(String id) => AddressModel(
      id: id,
      userId: 'fixture',
      name: 'Fixture',
      phone: '9000000000',
      addressLine1: 'Fixture',
      addressLine2: '',
      city: 'City',
      state: 'State',
      zipcode: '600001');
  test('blank creation ID is generated and stored consistently', () async {
    final id = await DatabaseService().addAddress(row(''));
    expect(id, isNotEmpty);
    expect(writes.single.path, 'addresses/$id');
    expect(writes.single.data!['id'], id);
    expect(writes.single.data!['userId'], 'fixture');
  });
  test('explicit creation ID remains stable', () async {
    final id = await DatabaseService().addAddress(row('explicit'));
    expect(id, 'explicit');
    expect(writes.single.path, 'addresses/explicit');
    expect(writes.single.data!['id'], 'explicit');
  });
}
