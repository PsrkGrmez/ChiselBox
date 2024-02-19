package com.v2ray.ang.ui

import android.app.ActivityManager
import android.Manifest
import android.content.*
import android.content.res.ColorStateList
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.text.TextUtils
import android.util.Log
import android.view.KeyEvent
import android.view.Menu
import android.view.MenuItem
import android.widget.Toast
import androidx.appcompat.app.ActionBarDrawerToggle
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import android.content.Context
import androidx.core.view.GravityCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.navigation.NavigationView
import com.google.gson.Gson
import com.tbruyelle.rxpermissions.RxPermissions
import com.tencent.mmkv.MMKV
import com.v2ray.ang.AppConfig
import com.v2ray.ang.AppConfig.ANG_PACKAGE
import com.v2ray.ang.BuildConfig
import com.v2ray.ang.R
import com.v2ray.ang.databinding.ActivityMainBinding
import com.v2ray.ang.dto.EConfigType
import com.v2ray.ang.dto.ServerConfig
import com.v2ray.ang.extension.toast
import com.v2ray.ang.helper.SimpleItemTouchHelperCallback
import com.v2ray.ang.receiver.*
import com.v2ray.ang.service.V2RayServiceManager
import com.v2ray.ang.util.*
import com.v2ray.ang.viewmodel.MainViewModel
import com.v2ray.ang.viewmodel.VpnStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import me.drakeet.support.toast.ToastCompat
import rx.Observable
import rx.android.schedulers.AndroidSchedulers
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit
import androidx.core.app.NotificationCompat
import com.v2ray.ang.util.Utility
import com.v2ray.ang.service.V2RayVpnService

import libv2ray.*
import libv2ray.Libv2ray.*


class MainActivity : FlutterActivity(), NavigationView.OnNavigationItemSelectedListener {
    private lateinit var binding: ActivityMainBinding
    private val method_channel = "com.v2ray.ang/method_channel"
    private val status_event_channel = "com.v2ray.ang/status_event_channel"
    private val ping_event_channel = "com.v2ray.ang/ping_event_channel"
    private val all_real_ping_event_channel = "com.v2ray.ang/all_real_ping_event_channel"

    private val job = Job()
    private val coroutineScope = CoroutineScope(Dispatchers.Default + job)

    private val VPN_REQUEST_CODE = 456
    private val adapter by lazy { MainRecyclerAdapter(this) }
    private val mainStorage by lazy {
        MMKV.mmkvWithID(
            MmkvManager.ID_MAIN,
            MMKV.MULTI_PROCESS_MODE
        )
    }
    private val settingsStorage by lazy {
        MMKV.mmkvWithID(
            MmkvManager.ID_SETTING,
            MMKV.MULTI_PROCESS_MODE
        )
    }
//  closing chisel using back proccess
    private var mItemTouchHelper: ItemTouchHelper? = null
    lateinit var mainViewModel: MainViewModel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            status_event_channel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    val receiver = VpnBroadcastReceiver()
                    receiver.setListener(object : VpnListener() {
                        override fun onVpnStatusChange(status: Int) {
                            eventSink.success(status)
                        }
                    })

                    val filter = IntentFilter("action.VPN_STATUS")
                    this@MainActivity.registerReceiver(receiver, filter)

                    Intent().also { intent ->
                        intent.action = "action.VPN_STATUS"
                        intent.putExtra("vpn_status", mainViewModel.vpnStatus.value?.code)
                        sendBroadcast(intent)
                    }
                }

                override fun onCancel(p0: Any?) {
                }
            }
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ping_event_channel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    val receiver = VpnBroadcastReceiver()
                    receiver.setListener(object : VpnListener() {
                        override fun onVpnPingRequest(ping: String) {
                            eventSink.success(ping)
                        }
                    })

                    val filter = IntentFilter("action.VPN_PING")
                    this@MainActivity.registerReceiver(receiver, filter)
                }

                override fun onCancel(p0: Any?) {
                }
            }
        )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            all_real_ping_event_channel
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                    val receiver = VpnBroadcastReceiver()
                    receiver.setListener(object : VpnListener() {
                        override fun onVpnAllRealPingRequest(ping: Pair<String, Long>) {
                            eventSink.success(
                                Gson().toJson(ping)
                            )
                        }
                    })
                    val filter = IntentFilter("action.VPN_ALL_REAL_PING")
                    this@MainActivity.registerReceiver(receiver, filter)
                }

                override fun onCancel(p0: Any?) {
                }
            }
        )



        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            method_channel
        ).setMethodCallHandler { call, result ->
            // This method is invoked on the main thread.
            when (call.method) {
                "connect" -> {

                    val config = call.argument<String>("config")
                    val remark = call.argument<String>("remark")
                    

                     if (mainViewModel.isRunning.value == true) {
                        Utils.stopVService(this)


                    } else if (settingsStorage?.decodeString(AppConfig.PREF_MODE) ?: "VPN" == "VPN") {
                        importBatchConfig(config!!)
                        val vpnIntent = VpnService.prepare(this)
                        if (vpnIntent != null) {
                            var file = File("data/user/0/com.chisel.box/files/isActive.txt")
                            val isNewFileCreated :Boolean = file.createNewFile()
                         
                            if(isNewFileCreated){
                                println("Connection File Created")
                            } else{
                                println("Connection File already exists.")
                            }

                                execChiselClient("client", call.argument<String>("domain"), "127.0.0.1:3035:127.0.0.1:"+call.argument<String>("port"))
                                startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
                        } else {
                            // Handling case where VPN is already prepared or not supported
                            // Proceed with VPN setup
 
                            var file = File("data/user/0/com.chisel.box/files/isActive.txt")
                            val isNewFileCreated :Boolean = file.createNewFile()
                         
                            if(isNewFileCreated){
                                println("Connection File Created")
                            } else{
                                println("Connection File already exists.")
                            }

                                execChiselClient("client", call.argument<String>("domain"), "127.0.0.1:3035:127.0.0.1:"+call.argument<String>("port"))
                            startV2Ray()

                        }
                    } else {
                        
                        val config = call.argument<String>("config")
                        importBatchConfig(config!!)
                        var file = File("data/user/0/com.chisel.box/files/isActive.txt")
                        val isNewFileCreated :Boolean = file.createNewFile()
                     
                        if(isNewFileCreated){
                            println("Connection File Created")
                        } else{
                            println("Connection File already exists.")
                        }

                        execChiselClient("client", call.argument<String>("domain"), "127.0.0.1:3035:127.0.0.1:"+call.argument<String>("port"))
                        startV2Ray()

                    }


                    result.success(true)
                }

                "testCurrentServerRealPing" -> {
                    if (mainViewModel.isRunning.value == true) {
                        setTestState(getString(R.string.connection_test_testing))
                        mainViewModel.testCurrentServerRealPing()
                    } else {
                        toast("شما به سروری متصل نیستید")
                    }
                }

                "testAllRealPing" -> {
                    val res = call.argument<String>("configs")
                    val configs = Gson().fromJson(res, List::class.java) as List<String>
                    mainViewModel.testAllRealPing(configs)
                }
                "disconnect" -> {
                    val file = File("data/user/0/com.chisel.box/files/isActive.txt")
                    file.delete()
                    Utils.stopVService(this)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    fun execChiselClient(type: String?, server: String? , point: String?) {
        coroutineScope.launch {
            try {
                var chisel = newTunnel(type, server, point)
                chisel.start()
            } catch (e: CancellationException) {
                println(e)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode == -1) {
            if (requestCode == VPN_REQUEST_CODE) {
                startV2Ray()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mainViewModel = MainViewModel(application)
        binding = ActivityMainBinding.inflate(layoutInflater)
        val view = binding.root
//        setContentView(view)
        title = getString(R.string.title_server)
//        setSupportActionBar(binding.toolbar)

        binding.fab.setOnClickListener {
            if (mainViewModel.isRunning.value == true) {
                Utils.stopVService(this)
            } else if (settingsStorage?.decodeString(AppConfig.PREF_MODE) ?: "VPN" == "VPN") {
                val intent = VpnService.prepare(this)
                if (intent == null) {
                    startV2Ray()
                } else {
//                    requestVpnPermission.launch(intent)
                }
            } else {
                startV2Ray()
            }
        }
        binding.layoutTest.setOnClickListener {
            if (mainViewModel.isRunning.value == true) {
                setTestState(getString(R.string.connection_test_testing))
                mainViewModel.testCurrentServerRealPing()
            } else {
//                tv_test_state.text = getString(R.string.connection_test_fail)
            }
        }

        binding.recyclerView.setHasFixedSize(true)
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter

        val callback = SimpleItemTouchHelperCallback(adapter)
        mItemTouchHelper = ItemTouchHelper(callback)
        mItemTouchHelper?.attachToRecyclerView(binding.recyclerView)


        val toggle = ActionBarDrawerToggle(
            this,
            binding.drawerLayout,
            binding.toolbar,
            R.string.navigation_drawer_open,
            R.string.navigation_drawer_close
        )
        binding.drawerLayout.addDrawerListener(toggle)
        toggle.syncState()
        binding.navView.setNavigationItemSelectedListener(this)
        binding.version.text = "v${BuildConfig.VERSION_NAME} (${SpeedtestUtil.getLibVersion()})"

        setupViewModel()
        copyAssets()
        migrateLegacy()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            RxPermissions(this)
                .request(Manifest.permission.POST_NOTIFICATIONS)
                .subscribe {
                    if (!it)
                        toast(R.string.toast_permission_denied)
                }
        }
    }



        
    /*fun killPidFile(f: String) {
        val file = File(f)
        if (!file.exists()) {
            return
            println("error: killing Chisel pid")
        }
        try {
            val pid = file.readText()
                .trim()
                .replace("\n", "")
                .toInt()
            Runtime.getRuntime().exec("kill $pid").waitFor()
            println(pid)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }*/

    private fun setupViewModel() {
        mainViewModel.serversPing.observe(this) {
            Intent().also { intent ->
                intent.action = "action.VPN_ALL_REAL_PING"
                intent.putExtra("vpn_all_real_ping", it)
                sendBroadcast(intent)
            }
        }
        mainViewModel.vpnStatus.observe(this) {
            Intent().also { intent ->
                intent.action = "action.VPN_STATUS"
                intent.putExtra("vpn_status", it.code)
                sendBroadcast(intent)
            }
        }
        mainViewModel.updateListAction.observe(this) { index ->
            if (index >= 0) {
                adapter.notifyItemChanged(index)
            } else {
                adapter.notifyDataSetChanged()
            }
        }
        mainViewModel.updateTestResultAction.observe(this) {
            Intent().also { intent ->
                intent.action = "action.VPN_PING"
                intent.putExtra("vpn_ping", it)
                sendBroadcast(intent)
            }
            setTestState(it)
        }
        mainViewModel.isRunning.observe(this) { isRunning ->
            adapter.isRunning = isRunning
            if (isRunning) {
                binding.fab.backgroundTintList =
                    ColorStateList.valueOf(ContextCompat.getColor(this, R.color.colorSelected))
                setTestState(getString(R.string.connection_connected))
                binding.layoutTest.isFocusable = true
            } else {
                binding.fab.backgroundTintList =
                    ColorStateList.valueOf(ContextCompat.getColor(this, R.color.colorUnselected))
                setTestState(getString(R.string.connection_not_connected))
                binding.layoutTest.isFocusable = false
            }
            hideCircle()
        }
        mainViewModel.startListenBroadcast()
    }

    private fun copyAssets() {
        val extFolder = Utils.userAssetPath(this)
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val geo = arrayOf("geosite.dat", "geoip.dat")
                assets.list("")
                    ?.filter { geo.contains(it) }
                    ?.filter { !File(extFolder, it).exists() }
                    ?.forEach {
                        val target = File(extFolder, it)
                        assets.open(it).use { input ->
                            FileOutputStream(target).use { output ->
                                input.copyTo(output)
                            }
                        }
                        Log.i(
                            ANG_PACKAGE,
                            "Copied from apk assets folder to ${target.absolutePath}"
                        )
                    }
            } catch (e: Exception) {
                Log.e(ANG_PACKAGE, "asset copy failed", e)
            }
        }
    }

    private fun migrateLegacy() {
        lifecycleScope.launch(Dispatchers.IO) {
            val result = AngConfigManager.migrateLegacyConfig(this@MainActivity)
            if (result != null) {
                launch(Dispatchers.Main) {
                    if (result) {
                        toast(getString(R.string.migration_success))
                        mainViewModel.reloadServerList()
                    } else {
                        toast(getString(R.string.migration_fail))
                    }
                }
            }
        }
    }

    fun startV2Ray() {
        mainViewModel.vpnStatus.value = VpnStatus.CONNECTING
        if (mainStorage?.decodeString(MmkvManager.KEY_SELECTED_SERVER).isNullOrEmpty()) {
            return
        }
        showCircle()
//        toast(R.string.toast_services_start)
        V2RayServiceManager.startV2Ray(this)
        hideCircle()
    }

    fun restartV2Ray() {
        if (mainViewModel.isRunning.value == true) {
            Utils.stopVService(this)
        }
        Observable.timer(500, TimeUnit.MILLISECONDS)
            .observeOn(AndroidSchedulers.mainThread())
            .subscribe {
                startV2Ray()
            }
    }

    public override fun onResume() {
        super.onResume()
        mainViewModel.reloadServerList()
    }

    public override fun onPause() {
        super.onPause()
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.menu_main, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem) = when (item.itemId) {
        R.id.import_qrcode -> {
            importQRcode(true)
            true
        }

        R.id.import_clipboard -> {
            importClipboard()
            true
        }

        R.id.import_manually_vmess -> {
            importManually(EConfigType.VMESS.value)
            true
        }

        R.id.import_manually_vless -> {
            importManually(EConfigType.VLESS.value)
            true
        }

        R.id.import_manually_ss -> {
            importManually(EConfigType.SHADOWSOCKS.value)
            true
        }

        R.id.import_manually_socks -> {
            importManually(EConfigType.SOCKS.value)
            true
        }

        R.id.import_manually_trojan -> {
            importManually(EConfigType.TROJAN.value)
            true
        }

        R.id.import_config_custom_clipboard -> {
            importConfigCustomClipboard()
            true
        }

        R.id.import_config_custom_local -> {
            importConfigCustomLocal()
            true
        }

        R.id.import_config_custom_url -> {
            importConfigCustomUrlClipboard()
            true
        }

        R.id.import_config_custom_url_scan -> {
            importQRcode(false)
            true
        }

//        R.id.sub_setting -> {
//            startActivity<SubSettingActivity>()
//            true
//        }

        R.id.sub_update -> {
            importConfigViaSub()
            true
        }

        R.id.export_all -> {
            if (AngConfigManager.shareNonCustomConfigsToClipboard(
                    this,
                    mainViewModel.serverList
                ) == 0
            ) {
            } else {
            }
            true
        }

        R.id.ping_all -> {
            mainViewModel.testAllTcping()
            true
        }

        R.id.real_ping_all -> {
            val configs: List<String> = listOf(
                "vless://9b3c4945-63b8-47a8-84a2-050431ce2035@cdn1.toshibars.sbs:2096?path=%2FfHv5aZUcc0BlAV8LUZtmV9vd6mnGN&fragment=&security=tls&encryption=none&alpn=http/1.1&host=cdn1.toshibars.sbs&fp=chrome&type=ws&sni=cdn1.toshibars.sbs#Rvan_tls_WS_CDN_vless",
                "vless://9b3c4945-63b8-47a8-84a2-050431ce2035@cdn1.toshibars.sbs:2096?path=%2FfHv5aZUcc0BlAV8LUZtmV9vd6mnGN&fragment=&security=tls&encryption=none&alpn=http/1.1&host=cdn1.toshibars.sbs&fp=chrome&type=ws&sni=cdn1.toshibars.sbs#Rvan_tls_WS_CDN_vless"
            )
            mainViewModel.testAllRealPing(configs)
            true
        }

        R.id.service_restart -> {
            restartV2Ray()
            true
        }

        R.id.del_all_config -> {
            AlertDialog.Builder(this).setMessage(R.string.del_config_comfirm)
                .setPositiveButton(android.R.string.ok) { _, _ ->
                    MmkvManager.removeAllServer()
                    mainViewModel.reloadServerList()
                }
                .show()
            true
        }

        R.id.del_duplicate_config -> {
            AlertDialog.Builder(this).setMessage(R.string.del_config_comfirm)
                .setPositiveButton(android.R.string.ok) { _, _ ->
                    mainViewModel.removeDuplicateServer()
                }
                .show()
            true
        }

        R.id.del_invalid_config -> {
            AlertDialog.Builder(this).setMessage(R.string.del_config_comfirm)
                .setPositiveButton(android.R.string.ok) { _, _ ->
                    MmkvManager.removeInvalidServer()
                    mainViewModel.reloadServerList()
                }
                .show()
            true
        }

        R.id.sort_by_test_results -> {
            MmkvManager.sortByTestResults()
            mainViewModel.reloadServerList()
            true
        }

        R.id.filter_config -> {
            mainViewModel.filterConfig(this)
            true
        }

        else -> super.onOptionsItemSelected(item)
    }

    private fun importManually(createConfigType: Int) {
        startActivity(
            Intent()
                .putExtra("createConfigType", createConfigType)
                .putExtra("subscriptionId", mainViewModel.subscriptionId)
                .setClass(this, ServerActivity::class.java)
        )
    }

    /**
     * import config from qrcode
     */
    fun importQRcode(forConfig: Boolean): Boolean {
//        try {
//            startActivityForResult(Intent("com.google.zxing.client.android.SCAN")
//                    .addCategory(Intent.CATEGORY_DEFAULT)
//                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP), requestCode)
//        } catch (e: Exception) {
        RxPermissions(this)
            .request(Manifest.permission.CAMERA)
            .subscribe {

            }
//        }
        return true
    }


    /**
     * import config from clipboard
     */
    fun importClipboard()
            : Boolean {
        try {
            val clipboard = Utils.getClipboard(this)
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
        return true
    }

    fun importBatchConfig(
        server: String,
        subid: String = ""
    ) {
        if (mainViewModel.serverList.size > 0) {
            mainViewModel.removeServer(mainViewModel.serverList[0])
        }
        val subid2 = if (subid.isEmpty()) {
            mainViewModel.subscriptionId
        } else {
            subid
        }
        val append = subid.isEmpty()

        var count = AngConfigManager.importBatchConfig(server, subid2, append)
        if (count <= 0) {
            count = AngConfigManager.importBatchConfig(Utils.decode(server), subid2, append)
        }
        if (count > 0) {
            mainViewModel.reloadServerList()
        } else {
        }
    }

    fun importConfigCustomClipboard()
            : Boolean {
        try {
            val configText = Utils.getClipboard(this)
            if (TextUtils.isEmpty(configText)) {
                toast(R.string.toast_none_data_clipboard)
                return false
            }
            importCustomizeConfig(configText)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    /**
     * import config from local config file
     */
    fun importConfigCustomLocal(): Boolean {
        try {
            showFileChooser()
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
        return true
    }

    fun importConfigCustomUrlClipboard()
            : Boolean {
        try {
            val url = Utils.getClipboard(this)
            if (TextUtils.isEmpty(url)) {
                toast(R.string.toast_none_data_clipboard)
                return false
            }
            return importConfigCustomUrl(url)
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    /**
     * import config from url
     */
    fun importConfigCustomUrl(url: String?): Boolean {
        try {
            if (!Utils.isValidUrl(url)) {
                toast(R.string.toast_invalid_url)
                return false
            }
            lifecycleScope.launch(Dispatchers.IO) {
                val configText = try {
                    Utils.getUrlContentWithCustomUserAgent(url)
                } catch (e: Exception) {
                    e.printStackTrace()
                    ""
                }
                launch(Dispatchers.Main) {
                    importCustomizeConfig(configText)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
        return true
    }

    /**
     * import config from sub
     */
    fun importConfigViaSub()
            : Boolean {
        try {
            toast(R.string.title_sub_update)
            MmkvManager.decodeSubscriptions().forEach {
                if (TextUtils.isEmpty(it.first)
                    || TextUtils.isEmpty(it.second.remarks)
                    || TextUtils.isEmpty(it.second.url)
                ) {
                    return@forEach
                }
                if (!it.second.enabled) {
                    return@forEach
                }
                val url = Utils.idnToASCII(it.second.url)
                if (!Utils.isValidUrl(url)) {
                    return@forEach
                }
                Log.d(ANG_PACKAGE, url)
                lifecycleScope.launch(Dispatchers.IO) {
                    val configText = try {
                        Utils.getUrlContentWithCustomUserAgent(url)
                    } catch (e: Exception) {
                        e.printStackTrace()
                        launch(Dispatchers.Main) {
                        }
                        return@launch
                    }
                    launch(Dispatchers.Main) {
                        importBatchConfig(configText, it.first)
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
        return true
    }

    /**
     * show file chooser
     */
    private fun showFileChooser() {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.type = "*/*"
        intent.addCategory(Intent.CATEGORY_OPENABLE)

        try {

        } catch (ex: ActivityNotFoundException) {
            toast(R.string.toast_require_file_manager)
        }
    }


    /**
     * read content from uri
     */
    private fun readContentFromUri(uri: Uri) {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        RxPermissions(this)
            .request(permission)
            .subscribe {
                if (it) {
                    try {
                        contentResolver.openInputStream(uri).use { input ->
                            importCustomizeConfig(input?.bufferedReader()?.readText())
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                } else
                    toast(R.string.toast_permission_denied)
            }
    }

    /**
     * import customize config
     */
    fun importCustomizeConfig(server: String?) {
        try {
            if (server == null || TextUtils.isEmpty(server)) {
                toast(R.string.toast_none_data)
                return
            }
            mainViewModel.appendCustomConfigServer(server)
            mainViewModel.reloadServerList()
            //adapter.notifyItemInserted(mainViewModel.serverList.lastIndex)
        } catch (e: Exception) {
            ToastCompat.makeText(
                this,
                "${getString(R.string.toast_malformed_josn)} ${e.cause?.message}",
                Toast.LENGTH_LONG
            ).show()
            e.printStackTrace()
            return
        }
    }

    fun setTestState(content: String?) {
        binding.tvTestState.text = content
    }

//    val mConnection = object : ServiceConnection {
//        override fun onServiceDisconnected(name: ComponentName?) {
//        }
//
//        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
//            sendMsg(AppConfig.MSG_REGISTER_CLIENT, "")
//        }
//    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK || keyCode == KeyEvent.KEYCODE_BUTTON_B) {
            moveTaskToBack(false)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }


    fun showCircle() {
//        binding.fabProgressCircle.show()
    }

    fun hideCircle() {
        try {
            Observable.timer(300, TimeUnit.MILLISECONDS)
                .observeOn(AndroidSchedulers.mainThread())
                .subscribe {
                    try {
//                        if (binding.fabProgressCircle.isShown) {
//                            binding.fabProgressCircle.hide()
//                        }
                    } catch (e: Exception) {
                        Log.w(ANG_PACKAGE, e)
                    }
                }
        } catch (e: Exception) {
            Log.d(ANG_PACKAGE, e.toString())
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (binding.drawerLayout.isDrawerOpen(GravityCompat.START)) {
            binding.drawerLayout.closeDrawer(GravityCompat.START)
        } else {
            //super.onBackPressed()
        }
    }

    override fun onNavigationItemSelected(item: MenuItem): Boolean {
        // Handle navigation view item clicks here.
        when (item.itemId) {
            //R.id.server_profile -> activityClass = MainActivity::class.java
            R.id.sub_setting -> {
                startActivity(Intent(this, SubSettingActivity::class.java))
            }

            R.id.settings -> {
                startActivity(
                    Intent(this, SettingsActivity::class.java)
                        .putExtra("isRunning", mainViewModel.isRunning.value == true)
                )
            }

            R.id.user_asset_setting -> {
                startActivity(Intent(this, UserAssetActivity::class.java))
            }

            R.id.feedback -> {
                Utils.openUri(this, AppConfig.v2rayNGIssues)
            }

            R.id.promotion -> {
                Utils.openUri(
                    this,
                    "${Utils.decode(AppConfig.promotionUrl)}?t=${System.currentTimeMillis()}"
                )
            }

            R.id.logcat -> {
                startActivity(Intent(this, LogcatActivity::class.java))
            }
        }
        binding.drawerLayout.closeDrawer(GravityCompat.START)
        return true
    }
}
