// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';

/// Fake DocumentSnapshot for feeding controllable data into Firestore StreamBuilders.
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  final String _id;
  final bool _exists;

  FakeDocumentSnapshot(this._data, [this._id = 'test-doc-id', this._exists = true]);

  @override
  String get id => _id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  bool get exists => _exists;

  @override
  dynamic get(Object field) => _data?[field];

  @override
  dynamic operator [](Object field) => _data?[field];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake QuerySnapshot for feeding lists of documents into Firestore StreamBuilders.
class FakeQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs;

  FakeQuerySnapshot([this._docs = const []]);

  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => _docs;

  @override
  int get size => _docs.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
