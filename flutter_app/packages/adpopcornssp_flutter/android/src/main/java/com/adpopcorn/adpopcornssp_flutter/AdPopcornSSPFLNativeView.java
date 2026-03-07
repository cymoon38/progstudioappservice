package com.adpopcorn.adpopcornssp_flutter;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.igaworks.ssp.SSPErrorCode;
import com.igaworks.ssp.part.custom.AdPopcornSSPReactNativeAd;
import com.igaworks.ssp.part.custom.listener.IReactNativeAdEventCallbackListener;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

import java.util.HashMap;
import java.util.Map;

/** 네이티브 광고: 현재 SDK는 AdPopcornSSPReactNativeAd(플랫폼 뷰)만 제공. 로드 성공 시 SDK가 뷰에 직접 그리며, 회색이면 뷰 배경·크기 또는 미디에이션 소재 확인. */
public class AdPopcornSSPFLNativeView implements PlatformView, IReactNativeAdEventCallbackListener {
    private FrameLayout container;
    private AdPopcornSSPReactNativeAd nativeView;
    private MethodChannel channel;
    private String placementId;
    private int width = 0;
    private int height = 0;
    private boolean hideCta = false;

    AdPopcornSSPFLNativeView(Activity activity, @NonNull Context context, int id, @Nullable Map<String, Object> creationParams, BinaryMessenger binaryMessenger) {
        if(creationParams != null)
        {
            placementId = (String)creationParams.get("placementId");
            if(creationParams.containsKey("width"))
                width = DpToPxInt(context, ((Number)creationParams.get("width")).intValue());
            if(creationParams.containsKey("height"))
                height = DpToPxInt(context, ((Number)creationParams.get("height")).intValue());
            if(creationParams.containsKey("hideCta"))
                hideCta = Boolean.TRUE.equals(creationParams.get("hideCta"));
        }
        if(placementId == null)
            return;

        channel = new MethodChannel(binaryMessenger, "adpopcornssp/" + placementId);
        nativeView = new AdPopcornSSPReactNativeAd(activity);
        if(width > 0)
            nativeView.setReactNativeWidth(width);
        if(height > 0)
            nativeView.setReactNativeHeight(height);
        nativeView.setReactNativeAdEventCallbackListener(this);
        nativeView.setPlacementId(placementId);
        nativeView.loadAd();

        container = new FrameLayout(context);
        container.setLayoutParams(new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        container.setBackgroundColor(0xFFFFFFFF);
        nativeView.setLayoutParams(new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        nativeView.setBackgroundColor(0xFFFFFFFF);
        container.addView(nativeView);
    }

    @NonNull
    @Override
    public View getView() {
        return container != null ? container : nativeView;
    }

    @Override
    public void dispose() {
        if(channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onReactNativeAdLoadSuccess(int adNetworkNo, int width, int height) {
        if (nativeView != null) {
            final AdPopcornSSPReactNativeAd view = nativeView;
            nativeView.post(new Runnable() {
                @Override
                public void run() {
                    if (hideCta) hideCtaViews(view);
                    view.setVisibility(View.VISIBLE);
                    view.requestLayout();
                    view.invalidate();
                    if (container != null) {
                        container.requestLayout();
                        container.invalidate();
                    }
                    forceLayoutRecursive(view);
                    // SDK가 비동기로 이미지/뷰를 채우는 경우를 위해 짧은 지연 후 한 번 더 레이아웃
                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            if (view != null) {
                                forceLayoutRecursive(view);
                                if (container != null) container.requestLayout();
                            }
                        }
                    }, 200);
                }
            });
        }
        if(channel != null){
            channel.invokeMethod("APSSPNativeAdLoadSuccess", argumentsMap("placementId", placementId));
        }
    }

    /** 자식 뷰까지 레이아웃 요청해 SDK 내부 이미지/텍스트가 그려지도록 함 */
    private void forceLayoutRecursive(View view) {
        if (view == null) return;
        view.requestLayout();
        view.invalidate();
        if (view instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) view;
            for (int i = 0; i < g.getChildCount(); i++) {
                forceLayoutRecursive(g.getChildAt(i));
            }
        }
    }

    /** CTA 버튼(상담받기, 구매하기 등)을 송출 시 숨김. SSP 컴포넌트에서 CTA 해제해도 일부 광고는 버튼을 포함하므로 앱에서 추가로 숨김. */
    private void hideCtaViews(View view) {
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) {
                hideCtaViews(group.getChildAt(i));
            }
        }
        if (view instanceof Button) {
            view.setVisibility(View.GONE);
            return;
        }
        if (view instanceof TextView) {
            CharSequence t = ((TextView) view).getText();
            if (t != null) {
                String s = t.toString().trim();
                if (s.equals("상담받기") || s.equals("구매하기") || s.equals("참여하기") || s.equals("바로가기")
                    || (s.contains("당첨") && s.contains("참여"))) {
                    View toHide = view.getParent() instanceof View ? (View) view.getParent() : view;
                    toHide.setVisibility(View.GONE);
                }
            }
        }
    }

    @Override
    public void onReactNativeAdLoadFailed(SSPErrorCode sspErrorCode) {
        if(channel != null) {
            channel.invokeMethod("APSSPNativeAdLoadFail", argumentsMap("placementId", placementId, "errorCode", sspErrorCode.getErrorCode()));
        }
    }

    @Override
    public void onImpression() {
        if(channel != null){
            channel.invokeMethod("APSSPNativeAdImpression", argumentsMap("placementId", placementId));
        }
    }

    @Override
    public void onClicked() {
        if(channel != null){
            channel.invokeMethod("APSSPNativeAdClicked", argumentsMap("placementId", placementId));
        }
    }

    private Map<String, Object> argumentsMap(Object... args) {
        Map<String, Object> arguments = new HashMap<>();
        try{
            for (int i = 0; i < args.length; i += 2) arguments.put(args[i].toString(), args[i + 1]);
        }catch (Exception e){}
        return arguments;
    }

    private int DpToPxInt(Context context, int dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, context.getResources().getDisplayMetrics());
    }
}
