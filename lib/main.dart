import 'dart:async';

import 'package:dino_vpn/pages/Splash.dart';
import 'package:dino_vpn/pages/home.dart';
import 'package:dino_vpn/vpn_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';



void main(){

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<VpnStatusProvider>(
          create: (_) => VpnStatusProvider(),
        ),
      ],
      child: SplashScreen(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final defaultFontFamily = TextStyle(fontFamily: 'vazir');
    return GetMaterialApp(
      title: 'ChiselBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: TextTheme(
            bodyText2: defaultFontFamily,
            bodyText1: defaultFontFamily,
            caption: defaultFontFamily),
        colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 28, 100, 184)),
        useMaterial3: true,
      ),
      home: HomeScreen() ,
    );
  }
}

