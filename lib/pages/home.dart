import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dino_vpn/pages/Qrcode.dart';
import 'package:dino_vpn/snackbar.dart';
import 'package:dino_vpn/vpn_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:dino_vpn/services/utils.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import '../vpn_status_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';

const kBgColor = Color.fromARGB(255, 15, 40, 71);
const kColorBg = Color(0xffE6E7F0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isConnected = false;
  bool _getServers = true;

  List myList = [];
  List donatedSV = [];

  Duration _duration = const Duration();
  Timer? _timer;

  startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      const addSeconds = 1;
      setState(() {
        final seconds = _duration.inSeconds + addSeconds;
        _duration = Duration(seconds: seconds);
      });
    });
  }

  stopTimer() {
    setState(() {
      _timer?.cancel();
      _duration = const Duration();
    });
  }

  Future<void> ping() async {
    VpnManager().getServerPing();
    await handleServerPing();
  }

  final ping_num = '0'.obs;
  bool _isPing = false;
  String svping = '';
  int? _selectedItem;
  int? _selectedItemDonated;

  String? _selectedServerType = "donated";

  late File jsonFile;
  late Directory dir;
  String fileName = "conf.json";
  bool fileExists = false;
  late List fileContent;
  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    getApplicationDocumentsDirectory().then((Directory directory) {
      dir = directory;
      jsonFile = new File(dir.path + "/" + fileName);
      fileExists = jsonFile.existsSync();
      if (fileExists)
        this.setState(
            () => myList = List.from(jsonDecode(jsonFile.readAsStringSync())));
    });
    getDonatedServers();
    setindex();
  }

  void createFile(List content, Directory dir, String fileName) {
    File file = new File(dir.path + "/" + fileName);
    file.createSync();
    fileExists = true;
    file.writeAsStringSync(json.encode(content));
  }

  void writeToFile(List value) {
    if (fileExists) {
      List jsonFileContent = value;
      jsonFile.writeAsStringSync(json.encode(jsonFileContent));
    } else {
      createFile(value, dir, fileName);
    }
    this.setState(() => print(json.decode(jsonFile.readAsStringSync())));
    //print(myList);
  }

  Future<void> handleServerPing() async {
    final String server_ping = "com.v2ray.ang/ping_event_channel";
    final EventChannel stream = EventChannel(server_ping);
    stream.receiveBroadcastStream().listen(
      (data) async {
        svping = data!;
        print(data);
        setState(() {
          _isPing = false;
        });
      },
    );
  }

  Future<void> setindex() async {
    var index_key = await storage.read(key: 'index_key');

    _selectedItem = int.parse(index_key!);
  }

  Future<String> deviceHWID() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Running on ${androidInfo.hardware}'); // e.g. "Moto G (4)"
    return androidInfo.display;
  }

  String hashString(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<void> getDonatedServers() async {
    try {
      var getHWID = await deviceHWID();
      var option = {'hwid': getHWID};
      var response = await dio.post('', data: option);
      var status = response.data['status'];
      print(response.data['servers']);

      if (status == "1") {
        List donatedServers = response.data['servers'];
        donatedSV = donatedServers as List;
        print(response.data['servers']);
      }
      setState(() {
        _getServers = false;
      });
    } on DioException catch (e) {
      setState(() {
        _getServers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: ExpandableFab(
          // duration: const Duration(milliseconds: 500),
          // distance: 200.0,
          type: ExpandableFabType.side,
          // pos: ExpandableFabPos.left,
          // childrenOffset: const Offset(0, 20),
          // fanAngle: 40,
          openButtonBuilder: RotateFloatingActionButtonBuilder(
            child: const Icon(Icons.menu),
            fabSize: ExpandableFabSize.regular,
            foregroundColor: Colors.white,
            backgroundColor: kBgColor,
            shape: const CircleBorder(),
            angle: 2 * 2,
          ),
          closeButtonBuilder: RotateFloatingActionButtonBuilder(
            child: const Icon(Icons.close),
            fabSize: ExpandableFabSize.regular,
            foregroundColor: Colors.white,
            backgroundColor: kBgColor,
            shape: const CircleBorder(),
            angle: 2 * 2,
          ),

          children: [
            FloatingActionButton(
              foregroundColor: Colors.white,
              backgroundColor: kBgColor,
              heroTag: null,
              child: const Icon(Icons.add),
              onPressed: () {
                Clipboard.getData(Clipboard.kTextPlain).then((value) async {
                  RegExp exp =
                      RegExp('vless\:\/\/(.*?)\@(.*?)\:(.*?)\\?(.*?)\#(.*?)\$');
                  RegExpMatch? match = exp.firstMatch(value!.text.toString());

                  if (match != null) {
                    print(value.text.toString());
                    var ConfigMap = {
                      'remark': match![5],
                      'link': value.text,
                      'port': match[3],
                      'domain': match[2],
                    };
                    print(myList.toString());

                    setState(() {
                      myList.add(ConfigMap);
                      writeToFile(myList);
                      print(myList.toList());
                    });
                  } else {
                    showSncackBar(
                      titleText: 'خطای پردازش',
                      captionText: 'متن کپی شده قابل پردازش نمیباشد',
                      textColor: Colors.white,
                      bgColor: Color.fromARGB(255, 17, 24, 40),
                      icon: Icon(
                        Icons.error,
                        color: Colors.white,
                      ),
                    );
                  }
                });
              },
            ),
            FloatingActionButton(
              // shape: const CircleBorder(),
              foregroundColor: Colors.white,
              backgroundColor: kBgColor,
              heroTag: null,
              child: const Icon(Icons.rocket),
              onPressed: () {
                setState(() {
                  ping();
                });
              },
            ),
          ],
        ),
        key: _scaffoldKey,
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'ChiselBox',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: kBgColor,
                      ),
                    ),
                  ],
                ),
              ),
              const ListTile(
                leading: Icon(
                  Icons.info,
                  size: 18,
                ),
                title: Text(
                  'App Version:' + ' 1.5.0 beta',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const ListTile(
                leading: Icon(
                  Icons.phone,
                  size: 18,
                ),
                title: Text(
                  'Twitter ' + ': @PsrkGermz',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        appBar: PreferredSize(
          preferredSize: Size.zero,
          child: AppBar(
            elevation: 0,
            backgroundColor: kBgColor,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: kBgColor,
              statusBarBrightness: Brightness.dark, // For iOS: (dark icons)
              statusBarIconBrightness:
                  Brightness.light, // For Android: (dark icons)
            ),
          ),
        ),
        backgroundColor: kBgColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: size.height * 0.4,
                  child: Column(
                    children: [
                      /// header action icons
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: InkWell(
                                onTap: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                                child: const Icon(
                                  Icons.segment,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: kBgColor,
                          child: Column(
                            children: [
                              SizedBox(
                                height: size.height * 0.02,
                              ),
                              Center(
                                child: Consumer<VpnStatusProvider>(
                                  builder: (context, vpnStatusProvider, child) {
                                    return InkWell(
                                      onTap: (vpnStatusProvider.vpnStatus !=
                                              VpnStatus.connecting)
                                          ? () async {
                                              if (vpnStatusProvider.vpnStatus ==
                                                  VpnStatus.connect) {
                                                await VpnManager().disconnect();

                                                stopTimer();
                                                setState(
                                                    () => _isConnected = false);
                                              } else {
                                                var index_key = await storage
                                                    .read(key: 'index_key');
                                                print(index_key.toString());
                                                //await VpnManager().connect('vless://4b5ef421-d116-4e4c-9066-a7be7b728d0e@fki.ktkdata20.click:443?encryption=none&security=none&type=tcp&headerType=http&host=kaspersky.com#%5B%F0%9F%87%A9%F0%9F%87%AAGermany%5D%20%5B%F0%9F%9F%A2%5D%20%5B%20%D8%A7%DB%8C%D8%B1%D8%A7%D9%86%D8%B3%D9%84%20%5D%20-%20%D8%AA%D8%B3%D8%AA%20%D8%B3%D8%A7%D8%A8%D8%B3%DA%A9%D8%B1%DB%8C%D9%BE%D8%B4%D9%86');

                                                RegExp exp = RegExp(
                                                    'vless\:\/\/(.*?)\@(.*?)\:(.*?)\\?(.*?)\#(.*?)\$');

                                                if (_selectedServerType ==
                                                    "donated") {
                                                  RegExpMatch? match = exp
                                                      .firstMatch(Uri.decodeFull(
                                                          donatedSV[int.parse(
                                                                      index_key!)]
                                                                  ['link']!
                                                              .toString()));

                                                  await VpnManager().connect(
                                                      "vless://" +
                                                          match![1]! +
                                                          "@127.0.0.1:3035?" +
                                                          match[4]! +
                                                          "#" +
                                                          match[5]!,
                                                      match[5]!,
                                                      match[3]!,
                                                      match[2]!);

                                                  print("donated");
                                                } else if (_selectedServerType ==
                                                    "custom") {
                                                  RegExpMatch? match =
                                                      exp.firstMatch(myList[
                                                                  int.parse(
                                                                      index_key!)]
                                                              ['link']!
                                                          .toString());

                                                  await VpnManager().connect(
                                                      "vless://" +
                                                          match![1]! +
                                                          "@127.0.0.1:3035?" +
                                                          match[4]! +
                                                          "#" +
                                                          match[5]!,
                                                      match[5]!,
                                                      match[3]!,
                                                      match[2]!);
                                                  print("custom");
                                                }

                                                _isConnected == false
                                                    ? startTimer()
                                                    : null;
                                                setState(
                                                    () => _isConnected = true);
                                              }
                                            }
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(size.height),
                                      child: Container(
                                        padding: const EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(
                                                  255, 166, 139, 139)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Container(
                                            width: size.height * 0.12,
                                            height: size.height * 0.12,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 5),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.power_settings_new,
                                                    size: size.height * 0.035,
                                                    color: kBgColor,
                                                  ),
                                                  Text(
                                                    _isConnected == true
                                                        ? 'قطع اتصال'
                                                        : 'اتصال',
                                                    style: TextStyle(
                                                      fontSize:
                                                          size.height * 0.013,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: kBgColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(
                                height: size.height * 0.01,
                              ),
                              Column(
                                children: [
                                  Container(
                                    alignment: Alignment.center,
                                    width:
                                        _isConnected ? 90 : size.height * 0.14,
                                    height: size.height * 0.030,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      _isConnected == true
                                          ? 'متصل'
                                          : 'اتصال برقرار نیست',
                                      style: TextStyle(
                                        fontSize: size.height * 0.015,
                                        color: kBgColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: size.height * 0.012,
                                  ),
                                  _countDownWidget(size),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height:
                      Platform.isIOS ? size.height * 0.51 : size.height * 0.565,
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 17, 24, 40),
                  ),
                  child: ListView(children: [
                    Column(
                      children: [
                        SizedBox(width: 20, height: 20),
                        Center(
                          child: InkWell(
                            onTap: () => {},
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.dynamic_form,
                                    size: size.height * 0.035,
                                    color: Color.fromARGB(255, 241, 241, 241),
                                    shadows: <Shadow>[
                                      Shadow(
                                        offset: Offset(0.0, 0.0),
                                        blurRadius: 40.0,
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Donated Servers",
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(255, 231, 231, 231),
                                        fontSize: 18,
                                        fontFamily: "Vazir"),
                                  )
                                ]),
                          ),
                        ),
                        SizedBox(width: 20, height: 10),
                        donatedSV.isEmpty
                            ? Container(
                                margin: const EdgeInsets.only(
                                    bottom: 1, left: 3, right: 3),
                                child: Material(
                                  color: Color.fromARGB(255, 17, 24, 40),
                                  borderRadius: BorderRadius.circular(7),
                                  child: Card(
                                    color: Colors.white,
                                    child: InkWell(
                                      onTap: () async {},
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        width: double.infinity,
                                        height: 66,
                                        child: Row(
                                          children: [
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 10,
                                                ),
                                                Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            "",
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                        ],
                                                      ),
                                                    ]),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            _getServers == true
                                                ? SizedBox(
                                                    child: Center(
                                                        child:
                                                            LinearProgressIndicator(
                                                      color: kBgColor,
                                                    )),
                                                    height: 4.0,
                                                    width: 30.0,
                                                  )
                                                : Row(
                                                    children: [
                                                      Icon(
                                                        Icons.warning,
                                                        color: Colors.red,
                                                      ),
                                                      Text(
                                                        "خطای دسترسی به سرور های اهدایی",
                                                        style: TextStyle(
                                                            color: Colors.red,
                                                            fontFamily: "Vazir",
                                                            fontSize: 15),
                                                      ),
                                                    ],
                                                  ),
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              child: InkWell(
                                                child: Text(
                                                  svping,
                                                  style: TextStyle(
                                                      color: Colors.green),
                                                ),
                                              ),
                                            ),
                                            Spacer(),
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: null),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                textDirection: TextDirection.ltr,
                                children:
                                    List.generate(donatedSV.length, (index) {
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 1, left: 3, right: 3),
                                    child: Material(
                                      color: Color.fromARGB(255, 17, 24, 40),
                                      borderRadius: BorderRadius.circular(7),
                                      child: Card(
                                        color: Colors.white,
                                        child: InkWell(
                                          onTap: () async {
                                            await storage.write(
                                                key: 'index_key',
                                                value: index.toString());

                                            setState(() {
                                              _selectedItemDonated = index;
                                              _selectedServerType = "donated";
                                              _selectedItem = index - 100;
                                            });

                                            print(donatedSV.toString());
                                            print(myList.toString());
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                            ),
                                            width: double.infinity,
                                            height: 66,
                                            child: Row(
                                              children: [
                                                Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 30,
                                                      height: 30,
                                                      child: Icon(
                                                        Icons
                                                            .volunteer_activism,
                                                        color:
                                                            _selectedItemDonated ==
                                                                    index
                                                                ? kBgColor
                                                                : Colors
                                                                    .black45,
                                                        shadows: <Shadow>[
                                                          _selectedItemDonated ==
                                                                  index
                                                              ? Shadow(
                                                                  offset:
                                                                      Offset(
                                                                          0.0,
                                                                          0.0),
                                                                  blurRadius:
                                                                      50.0,
                                                                  color: Color
                                                                      .fromARGB(
                                                                          255,
                                                                          55,
                                                                          46,
                                                                          138),
                                                                )
                                                              : Shadow(
                                                                  offset:
                                                                      Offset(
                                                                          0.0,
                                                                          0.0),
                                                                  blurRadius:
                                                                      50.0,
                                                                  color: Color
                                                                      .fromARGB(
                                                                          255,
                                                                          255,
                                                                          255,
                                                                          255),
                                                                )
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(children: [
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                donatedSV[index]
                                                                        [
                                                                        'remark']
                                                                    .toString(),
                                                                style:
                                                                    const TextStyle(
                                                                  fontFamily:
                                                                      "Vazir",
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              Text(
                                                                donatedSV[index]
                                                                            [
                                                                            'domain']
                                                                        .toString() +
                                                                    " : " +
                                                                    donatedSV[index]
                                                                            [
                                                                            'port']
                                                                        .toString(),
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                            ],
                                                          ),
                                                        ]),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                (_isPing == true)
                                                    ? SizedBox(
                                                        child: Center(
                                                            child:
                                                                LinearProgressIndicator(
                                                          color: kBgColor,
                                                        )),
                                                        height: 4.0,
                                                        width: 30.0,
                                                      )
                                                    : svping != ''
                                                        ? _selectedItemDonated ==
                                                                index
                                                            ? Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                  color: kColorBg
                                                                      .withOpacity(
                                                                          0.7),
                                                                  shape: BoxShape
                                                                      .rectangle,
                                                                ),
                                                                child: InkWell(
                                                                  child: Text(
                                                                    svping,
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .green),
                                                                  ),
                                                                ),
                                                              )
                                                            : Text('')
                                                        : Text(''),
                                                const Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                        SizedBox(width: 20, height: 20),
                        Center(
                          child: InkWell(
                            onTap: () => {},
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    size: size.height * 0.035,
                                    color: Color.fromARGB(255, 241, 241, 241),
                                    shadows: <Shadow>[
                                      Shadow(
                                        offset: Offset(0.0, 0.0),
                                        blurRadius: 40.0,
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "Custom Configs",
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(255, 231, 231, 231),
                                        fontSize: 18,
                                        fontFamily: "Vazir"),
                                  )
                                ]),
                          ),
                        ),
                        SizedBox(width: 20, height: 10),
                        Center(
                          child: myList.isEmpty
                              ? const Text(
                                  "please add a config",
                                  style: TextStyle(color: Colors.white),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  textDirection: TextDirection.ltr,
                                  children:
                                      List.generate(myList.length, (index) {
                                    return Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 1, left: 3, right: 3),
                                      child: Material(
                                        color: Color.fromARGB(255, 17, 24, 40),
                                        borderRadius: BorderRadius.circular(7),
                                        child: Card(
                                          color: Colors.white,
                                          child: InkWell(
                                            onTap: () async {
                                              await storage.write(
                                                  key: 'index_key',
                                                  value: index.toString());

                                              setState(() {
                                                _selectedItem = index;
                                                _selectedServerType = "custom";
                                                _selectedItemDonated =
                                                    index - 100;
                                              });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 20,
                                              ),
                                              width: double.infinity,
                                              height: 66,
                                              child: Row(
                                                children: [
                                                  Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 30,
                                                        height: 30,
                                                        child: Icon(
                                                          Icons.dns,
                                                          color:
                                                              _selectedItem ==
                                                                      index
                                                                  ? kBgColor
                                                                  : Colors
                                                                      .black45,
                                                          shadows: <Shadow>[
                                                            _selectedItem ==
                                                                    index
                                                                ? Shadow(
                                                                    offset:
                                                                        Offset(
                                                                            0.0,
                                                                            0.0),
                                                                    blurRadius:
                                                                        50.0,
                                                                    color: Color
                                                                        .fromARGB(
                                                                            255,
                                                                            55,
                                                                            46,
                                                                            138),
                                                                  )
                                                                : Shadow(
                                                                    offset:
                                                                        Offset(
                                                                            0.0,
                                                                            0.0),
                                                                    blurRadius:
                                                                        50.0,
                                                                    color: Color
                                                                        .fromARGB(
                                                                            255,
                                                                            255,
                                                                            255,
                                                                            255),
                                                                  )
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        width: 10,
                                                      ),
                                                      Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(children: [
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  myList[index][
                                                                          'remark']
                                                                      .toString(),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  myList[index][
                                                                              'domain']
                                                                          .toString() +
                                                                      " : " +
                                                                      myList[index]
                                                                              [
                                                                              'port']
                                                                          .toString(),
                                                                  style:
                                                                      const TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 5,
                                                                ),
                                                              ],
                                                            ),
                                                          ]),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  const Spacer(),
                                                  (_isPing == true)
                                                      ? SizedBox(
                                                          child: Center(
                                                              child:
                                                                  LinearProgressIndicator(
                                                            color: kBgColor,
                                                          )),
                                                          height: 4.0,
                                                          width: 30.0,
                                                        )
                                                      : svping != ''
                                                          ? _selectedItem ==
                                                                  index
                                                              ? Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          4),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                    color: kColorBg
                                                                        .withOpacity(
                                                                            0.7),
                                                                    shape: BoxShape
                                                                        .rectangle,
                                                                  ),
                                                                  child:
                                                                      InkWell(
                                                                    child: Text(
                                                                      svping,
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.green),
                                                                    ),
                                                                    onTap:
                                                                        () async {
                                                                      if (_selectedItem ==
                                                                          index) {
                                                                      } else {
                                                                        setState(
                                                                            () {
                                                                          if (_selectedItem! >
                                                                              myList.length) {
                                                                            _selectedItem =
                                                                                _selectedItem! - 1;
                                                                          }
                                                                          myList
                                                                              .removeAt(index);
                                                                          writeToFile(
                                                                              myList);
                                                                        });
                                                                      }
                                                                    },
                                                                  ),
                                                                )
                                                              : Text('')
                                                          : Text(''),
                                                  const Spacer(),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: kColorBg
                                                          .withOpacity(0.7),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: InkWell(
                                                      child: Icon(
                                                        Icons.delete,
                                                        size: 21,
                                                        color: kBgColor,
                                                      ),
                                                      onTap: () async {
                                                        await VpnManager().disconnect();
                                                        setState(() {
                                                          stopTimer();
                                                        _isConnected = false;
                                                          myList
                                                              .removeAt(index);
                                                          writeToFile(myList);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                        ),
                        SizedBox(width: 20, height: 30),
                      ],
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _countDownWidget(Size size) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(_duration.inMinutes.remainder(60));
    final seconds = twoDigits(_duration.inSeconds.remainder(60));
    final hours = twoDigits(_duration.inHours.remainder(60));

    return Text(
      '$hours :  $minutes : $seconds ',
      style: TextStyle(color: Colors.white, fontSize: size.height * 0.03),
    );
  }
}
