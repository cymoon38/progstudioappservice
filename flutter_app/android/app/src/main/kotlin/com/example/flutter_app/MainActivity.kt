package com.example.flutter_app

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.igaworks.adpopcorn.AdpopcornExtension
import com.igaworks.adpopcorn.interfaces.IAPRewardInfoCallbackListener

class MainActivity : FlutterActivity() {

    private val channelName = "com.example.flutter_app/offerwall_reward"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getOfferwallTotalRewardInfo" -> {
                    runOnUiThread {
                        try {
                            AdpopcornExtension.getOfferwallTotalRewardInfo(this, object : IAPRewardInfoCallbackListener {
                                override fun OnEarnableTotalRewardInfo(queryResult: Boolean, totalCount: Int, totalReward: String?) {
                                    Handler(Looper.getMainLooper()).post {
                                        result.success(mapOf(
                                            "queryResult" to queryResult,
                                            "totalCount" to totalCount,
                                            "totalReward" to (totalReward ?: "0")
                                        ))
                                    }
                                }
                            })
                        } catch (e: Exception) {
                            result.error("OFFERWALL_REWARD_INFO", e.message, null)
                        }
                    }
                }
                "setAgreePrivacy" -> {
                    runOnUiThread {
                        try {
                            val agreed = call.argument<Boolean>("agreed") ?: true
                            // 가이드: 오퍼월 진입 시 동의 팝업을 띄우지 않으려면 setUserAgreement(Activity, true) 호출
                            AdpopcornExtension.setUserAgreement(this, agreed)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SET_AGREE_PRIVACY", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
