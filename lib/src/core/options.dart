part of firebase_dart.core;

/// The options used to configure a Firebase app.
///
/// ```dart
/// await Firebase.initializeApp(
///   name: 'SecondaryApp',
///   options: const FirebaseOptions(
///     apiKey: '...',
///     appId: '...',
///     messagingSenderId: '...',
///     projectId: '...',
///   )
/// );
/// ```
class FirebaseOptions {
  /// An API key used for authenticating requests from your app, for example
  /// "AIzaSyDdVgKwhZl0sTTTLZ7iTmt1r3N2cJLnaDk", used to identify your app to
  /// Google servers.
  final String apiKey;

  /// The Google App ID that is used to uniquely identify an instance of an app.
  ///
  /// This property is required cannot be `null`.
  final String appId;

  /// The unique sender ID value used in messaging to identify your app.
  ///
  /// This property is required cannot be `null`.
  final String messagingSenderId;

  /// The Project ID from the Firebase console, for example "my-awesome-app".
  final String projectId;

  /// The auth domain used to handle redirects from OAuth provides on web
  /// platforms, for example "my-awesome-app.firebaseapp.com".
  final String authDomain;

  /// The database root URL, for example "https://my-awesome-app.firebaseio.com."
  ///
  /// This property should be set for apps that use Firebase Database.
  final String databaseURL;

  /// The Google Cloud Storage bucket name, for example
  /// "my-awesome-app.appspot.com".
  final String storageBucket;

  /// The project measurement ID value used on web platforms with analytics.
  final String measurementId;

  /// The tracking ID for Google Analytics, for example "UA-12345678-1", used to
  /// configure Google Analytics.
  ///
  /// This property is used on iOS only.
  final String trackingId;

  /// The URL scheme used by iOS secondary apps for Dynamic Links.
  final String deepLinkURLScheme;

  /// The Android client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by iOS only.
  final String androidClientId;

  /// The iOS client ID from the Firebase Console, for example
  /// "12345.apps.googleusercontent.com."
  ///
  /// This value is used by iOS only.
  final String iosClientId;

  /// The iOS bundle ID for the application. Defaults to `[[NSBundle mainBundle] bundleID]`
  /// when not set manually or in a plist.
  ///
  /// This property is used on iOS only.
  final String iosBundleId;

  /// The iOS App Group identifier to share data between the application and the
  /// application extensions.
  ///
  /// Note that if using this then the App Group must be configured in the
  /// application and on the Apple Developer Portal.
  ///
  /// This property is used on iOS only.
  final String appGroupId;

  /// The options used to configure a Firebase app.
  ///
  /// ```dart
  /// await Firebase.initializeApp(
  ///   name: 'SecondaryApp',
  ///   options: const FirebaseOptions(
  ///     apiKey: '...',
  ///     appId: '...',
  ///     messagingSenderId: '...',
  ///     projectId: '...',
  ///   )
  /// );
  /// ```
  const FirebaseOptions({
    @required this.apiKey,
    @required this.appId,
    this.messagingSenderId,
    @required this.projectId,
    this.authDomain,
    this.databaseURL,
    this.storageBucket,
    this.measurementId,
    // ios specific
    this.trackingId,
    this.deepLinkURLScheme,
    this.androidClientId,
    this.iosClientId,
    this.iosBundleId,
    this.appGroupId,
  })  : assert(apiKey != null, "'apiKey' cannot be null"),
        assert(appId != null, "'appId' cannot be null."),
        assert(projectId != null, "'projectId' cannot be null.");

  /// Named constructor to create [FirebaseOptions] from a Map.
  ///
  /// This constructor is used when platforms cannot directly return a
  /// [FirebaseOptions] instance, for example when data is sent back from a
  /// [MethodChannel].
  FirebaseOptions.fromMap(Map<dynamic, dynamic> map)
      : assert(map['apiKey'] != null, "'apiKey' cannot be null."),
        assert(map['appId'] != null || map['googleAppID'],
            "'appId' and 'googleAppID' cannot be null."),
        assert(map['messagingSenderId'] != null || map['gcmSenderID'],
            "'messagingSenderId' and 'gcmSenderID' cannot be null."),
        assert(map['projectId'] != null || map['projectID'],
            "'projectId' and 'projectID' cannot be null."),
        apiKey = map['apiKey'],
        appId = map['appId'] ?? map['googleAppID'],
        messagingSenderId = map['messagingSenderId'] ?? map['gcmSenderID'],
        projectId = map['projectId'] ?? map['projectID'],
        authDomain = map['authDomain'],
        databaseURL = map['databaseURL'],
        storageBucket = map['storageBucket'],
        measurementId = map['measurementId'],
        trackingId = map['trackingId'],
        deepLinkURLScheme = map['deepLinkURLScheme'],
        androidClientId = map['androidClientId'],
        iosClientId = map['iosClientId'],
        iosBundleId = map['iosBundleId'],
        appGroupId = map['appGroupId'];

  /// The current instance as a [Map].
  Map<String, String> get asMap {
    return <String, String>{
      'apiKey': apiKey,
      'appId': appId,
      'messagingSenderId': messagingSenderId,
      'projectId': projectId,
      'authDomain': authDomain,
      'databaseURL': databaseURL,
      'storageBucket': storageBucket,
      'measurementId': measurementId,
      'trackingId': trackingId,
      'deepLinkURLScheme': deepLinkURLScheme,
      'androidClientId': androidClientId,
      'iosClientId': iosClientId,
      'iosBundleId': iosBundleId,
      'appGroupId': appGroupId,
    };
  }

  // Required from `fromMap` comparison
  @override
  bool operator ==(dynamic other) {
    if (identical(this, other)) return true;
    if (other is! FirebaseOptions) return false;
    return other.asMap.toString() == asMap.toString();
  }

  @override
  int get hashCode {
    return hash2(hashObjects(asMap.keys), hashObjects(asMap.values));
  }

  @override
  String toString() => asMap.toString();
}
