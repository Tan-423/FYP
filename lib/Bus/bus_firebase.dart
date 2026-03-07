import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// A named secondary Firebase App that points to the friend's Firebase project
/// (fyp-project-2cb4d), where all bus_routes and tickets collections live.
FirebaseApp? _busApp;

Future<FirebaseFirestore> getBusFirestore() async {
  if (_busApp == null) {
    const options = FirebaseOptions(
      apiKey: 'AIzaSyBKo855iJPJ08OAvB10lQvHAJVu24uXB4E',
      appId: '1:817958403899:android:b7502d7fd2f8a30fd5011e',
      messagingSenderId: '817958403899',
      projectId: 'fyp-project-2cb4d',
      storageBucket: 'fyp-project-2cb4d.firebasestorage.app',
    );
    try {
      _busApp = await Firebase.initializeApp(
        name: 'busApp',
        options: options,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _busApp = Firebase.app('busApp');
      } else {
        rethrow;
      }
    }
  }
  return FirebaseFirestore.instanceFor(app: _busApp!);
}
