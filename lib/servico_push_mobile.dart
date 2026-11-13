import 'package:onesignal_flutter/onesignal_flutter.dart';

class ServicoPushApp {
  static Future<void> inicializar() async {
    try {
      OneSignal.initialize("04552b74-f865-437f-94b6-4b07dc65d901");
      await OneSignal.Notifications.requestPermission(true);
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.notification.display();
      });
    } catch (_) {}
  }

  static Future<void> login(String user, String nome, String cargo) async {
    try {
      await OneSignal.login(user);
      OneSignal.User.addTagWithKey("usuario", user);
      OneSignal.User.addTagWithKey("nome", nome);
      OneSignal.User.addTagWithKey("cargo", cargo);
    } catch (_) {}
  }
}