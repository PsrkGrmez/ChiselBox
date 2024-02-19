


import 'dart:async';

import 'package:dino_vpn/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';



class SplashScreen extends StatelessWidget {
    const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Timer(Duration(seconds: 3), () {

      Get.offAll(() => HomeScreen());
      
    });

    return GetMaterialApp(
      home: Scaffold(
        body: Container(
          child: Image.asset(
                        'assets/images/background.png',
                        fit: BoxFit.cover,
    height: double.infinity,
    width: double.infinity,
    alignment: Alignment.center,
    ),
                        
        ),
      ),
    );
  }
}