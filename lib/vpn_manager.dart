import 'dart:convert';
import 'package:flutter/services.dart';

enum VpnStatus {
  connecting(code: 0),
  connect(code: 1),
  disconnect(code: 2);

  const VpnStatus({required this.code});

  final int code;
}

class VpnManager {
  String methodChannel = "com.v2ray.ang/method_channel";

  Future<bool> connect(String config, String remark ,String port, String domain) async {
    // Native channel
    final platform = MethodChannel(methodChannel);
    bool result = false;
    try {
      result = await platform.invokeMethod("connect", {'config': config, 'remark': remark , 'port': port, 'domain': domain});
    } on PlatformException catch (e) {
      print(e.toString());
      rethrow;
    }
    return result;
  }

  Future<bool> disconnect() async {
    // Native channel
    final platform = MethodChannel(methodChannel);
    try {
      await platform.invokeMethod("disconnect");
    } on PlatformException catch (e) {
      print(e.toString());
      rethrow;
    }
    return true;
  }
  Future<bool> getServerPing() async {
    // Native channel
    final platform = MethodChannel(methodChannel);
    bool result = false;
    try {
      result = await platform.invokeMethod("testCurrentServerRealPing");
    } on PlatformException catch (e) {
      print(e.toString());
      rethrow;
    }
    return result;
  }

  Future<bool> testAllRealPing(List<String> configs) async {
    // Native channel
    final platform = MethodChannel(methodChannel);
    bool result = false;
    try {
      final res = jsonEncode(configs);
      result = await platform.invokeMethod("testAllRealPing", {'configs': res});
    } on PlatformException catch (e) {
      print(e.toString());
      rethrow;
    }
    return result;
  }
}
