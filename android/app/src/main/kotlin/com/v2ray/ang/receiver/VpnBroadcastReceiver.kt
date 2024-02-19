package com.v2ray.ang.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class VpnBroadcastReceiver : BroadcastReceiver() {
    private lateinit var callback: VpnListener

    fun setListener(callback: VpnListener) {
        this.callback = callback;
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent != null) {
            if (intent.action == "action.VPN_STATUS") {
                val info = intent.getIntExtra("vpn_status", 2)
                callback.onVpnStatusChange(info)
            } else if (intent.action == "action.VPN_PING") {
                val info = intent.getStringExtra("vpn_ping")
                if (info != null)
                    callback.onVpnPingRequest(info)
            } else if (intent.action == "action.VPN_ALL_REAL_PING") {
                val info = intent.getSerializableExtra("vpn_all_real_ping") as Pair<String, Long>
                if (info != null)
                    callback.onVpnAllRealPingRequest(info)
            }
        }
    }
}

abstract class VpnListener {
    open fun onVpnStatusChange(status: Int) {}
    open fun onVpnPingRequest(ping: String) {}
    open fun onVpnAllRealPingRequest(ping: Pair<String, Long>) {}
}