package com.v2ray.ang.util

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream

object Utility {
    private val TAG = Utility::class.java.simpleName

    fun exec(cmd: String) = try {
        Runtime.getRuntime().exec(cmd).waitFor()
    } catch (e: Exception) {
        -1
    }

    fun killPidFile(f: String) {
        val file = File(f)
        if (!file.exists()) {
            println("Killing pid file error")
        }
        try {
            val pid = file.readText()
                .trim()
                .replace("\n", "")
                .toInt()
            Runtime.getRuntime().exec("kill $pid").waitFor()
            if (!file.delete())
                Log.w(TAG, "failed to delete pidfile")
        } catch (e: Exception) {
            println("error")
        }
    }

}