import 'package:dino_vpn/vpn_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class VpnStatusProvider extends ChangeNotifier {
  VpnStatus _vpnStatus = VpnStatus.disconnect;

  VpnStatus get vpnStatus => _vpnStatus;

  String statusEventChannel = "com.v2ray.ang/status_event_channel";

  VpnStatusProvider() {
    handleVpnStatusChanges();
  }

  void handleVpnStatusChanges() {
    final EventChannel stream = EventChannel(statusEventChannel);
    stream.receiveBroadcastStream().listen(
      (data) {
        _vpnStatus = VpnStatus.values.firstWhere((e) => e.code == (data ?? 2));
        notifyListeners();
      },
    );
  }
}
