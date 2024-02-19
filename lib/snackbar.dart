import 'package:get/get.dart';
import 'package:flutter/material.dart';

void showSncackBar({required titleText, required captionText, required textColor, required bgColor, required icon}) {
  Get.snackbar(
    '',
    '',
    padding: EdgeInsets.all(16),
    margin: EdgeInsets.all(16),
    titleText: Text(titleText, style: TextStyle(color: textColor, fontFamily: 'vazir'), textDirection: TextDirection.rtl),
    messageText: Text(captionText, style: TextStyle(color: textColor, fontFamily: 'vazir'), textDirection: TextDirection.rtl),
    colorText: textColor,
    icon: icon,
    snackPosition: SnackPosition.TOP,
    duration: Duration(seconds: 3),
    backgroundColor: bgColor,
  );
}
