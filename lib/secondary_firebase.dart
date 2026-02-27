import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// A secondary Firebase App used exclusively for owner/organizer
/// authentication, so that signing in as owner/organizer never replaces
/// the main traveler user's Firebase Auth session.
FirebaseApp? _secondaryApp;

Future<FirebaseAuth> getSecondaryAuth() async {
  if (_secondaryApp == null) {
    const options = FirebaseOptions(
      apiKey: 'AIzaSyCABEXStQhq9MdnxwEZHjJma7xEZvrKIxY',
      appId: '1:1083832487834:android:97118f73e739d15f123423',
      messagingSenderId: '1083832487834',
      projectId: 'fyp-project-7199d',
      storageBucket: 'fyp-project-7199d.firebasestorage.app',
      databaseURL:
          'https://fyp-project-7199d-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
    try {
      _secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: options,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _secondaryApp = Firebase.app('secondary');
      } else {
        rethrow;
      }
    }
  }
  return FirebaseAuth.instanceFor(app: _secondaryApp!);
}
