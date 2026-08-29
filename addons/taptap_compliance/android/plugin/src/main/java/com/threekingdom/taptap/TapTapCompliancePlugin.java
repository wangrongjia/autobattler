package com.threekingdom.taptap;

import android.app.Activity;

import com.taptap.sdk.compliance.TapTapCompliance;
import com.taptap.sdk.compliance.TapTapComplianceCallback;
import com.taptap.sdk.compliance.option.TapTapComplianceOptions;
import com.taptap.sdk.core.TapTapRegion;
import com.taptap.sdk.core.TapTapSdk;
import com.taptap.sdk.core.TapTapSdkOptions;
import com.taptap.sdk.initializer.api.model.ScreenOrientation;
import com.taptap.sdk.kit.internal.callback.TapTapCallback;
import com.taptap.sdk.kit.internal.exception.TapTapException;
import com.taptap.sdk.login.Scopes;
import com.taptap.sdk.login.TapTapAccount;
import com.taptap.sdk.login.TapTapLogin;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class TapTapCompliancePlugin extends GodotPlugin {
    private static final String PLUGIN_NAME = "TapTapCompliance";
    private static final SignalInfo INITIALIZED =
            new SignalInfo("initialized", Boolean.class, String.class);
    private static final SignalInfo LOGIN_RESULT =
            new SignalInfo("login_result", Boolean.class, String.class, String.class);
    private static final SignalInfo COMPLIANCE_RESULT =
            new SignalInfo("compliance_result", Integer.class, String.class);

    private volatile boolean initialized;
    private volatile boolean callbackRegistered;

    public TapTapCompliancePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(INITIALIZED);
        signals.add(LOGIN_RESULT);
        signals.add(COMPLIANCE_RESULT);
        return signals;
    }

    @UsedByGodot
    public void initialize(
            String clientId,
            String clientToken,
            boolean enableLog,
            boolean privacyConsentGranted) {
        runOnUiThread(() -> {
            try {
                Activity activity = requireActivity();
                if (!privacyConsentGranted) {
                    emitInitialized(false, "用户尚未同意隐私政策，拒绝初始化 TapTap SDK");
                    return;
                }
                if (clientId == null || clientId.trim().isEmpty()
                        || clientToken == null || clientToken.trim().isEmpty()) {
                    emitInitialized(false, "Client ID 或 Client Token 为空");
                    return;
                }

                TapTapSdkOptions sdkOptions = new TapTapSdkOptions(
                        clientId.trim(), clientToken.trim(), TapTapRegion.CN);
                sdkOptions.setScreenOrientation(ScreenOrientation.LANDSCAPE);
                sdkOptions.setEnableLog(enableLog);

                TapTapComplianceOptions complianceOptions =
                        new TapTapComplianceOptions(true, false);
                TapTapSdk.init(activity.getApplicationContext(), sdkOptions, complianceOptions);
                registerComplianceCallback();
                initialized = true;
                emitInitialized(true, "");
            } catch (Exception exception) {
                initialized = false;
                emitInitialized(false, messageOf(exception));
            }
        });
    }

    @UsedByGodot
    public void loginAndStartCompliance() {
        runOnUiThread(() -> {
            if (!initialized) {
                emitLogin(false, "", "TapTap SDK 尚未初始化");
                return;
            }
            try {
                TapTapAccount current = TapTapLogin.getCurrentTapAccount();
                if (current != null && current.getOpenId() != null
                        && !current.getOpenId().isEmpty()) {
                    emitLogin(true, current.getOpenId(), "");
                    startComplianceFor(current.getOpenId());
                    return;
                }

                String[] scopes = new String[]{Scopes.SCOPE_BASIC_INFO};
                TapTapLogin.loginWithScopes(requireActivity(), scopes,
                        new TapTapCallback<TapTapAccount>() {
                            @Override
                            public void onSuccess(TapTapAccount account) {
                                String openId = account == null ? "" : account.getOpenId();
                                if (openId == null || openId.isEmpty()) {
                                    emitLogin(false, "", "登录结果缺少 openId");
                                    return;
                                }
                                emitLogin(true, openId, "");
                                startComplianceFor(openId);
                            }

                            @Override
                            public void onFail(TapTapException exception) {
                                emitLogin(false, "", messageOf(exception));
                            }

                            @Override
                            public void onCancel() {
                                emitLogin(false, "", "用户取消登录");
                            }
                        });
            } catch (Exception exception) {
                emitLogin(false, "", messageOf(exception));
            }
        });
    }

    @UsedByGodot
    public void startCompliance() {
        runOnUiThread(() -> {
            try {
                TapTapAccount account = TapTapLogin.getCurrentTapAccount();
                if (account == null || account.getOpenId() == null
                        || account.getOpenId().isEmpty()) {
                    emitLogin(false, "", "TapTap 登录状态已失效");
                    return;
                }
                startComplianceFor(account.getOpenId());
            } catch (Exception exception) {
                emitCompliance(1200, messageOf(exception));
            }
        });
    }

    @UsedByGodot
    public void logout() {
        runOnUiThread(() -> {
            try {
                TapTapLogin.logout();
            } catch (Exception ignored) {
                // The GDScript gate remains closed even if cache cleanup fails.
            }
        });
    }

    @UsedByGodot
    public void exitCompliance() {
        runOnUiThread(TapTapCompliance::exit);
    }

    private void startComplianceFor(String openId) {
        try {
            TapTapCompliance.startup(requireActivity(), openId);
        } catch (Exception exception) {
            emitCompliance(1200, messageOf(exception));
        }
    }

    private void registerComplianceCallback() {
        if (callbackRegistered) {
            return;
        }
        TapTapCompliance.registerComplianceCallback(new TapTapComplianceCallback() {
            @Override
            public void onComplianceResult(int code, Map<String, ?> extra) {
                emitCompliance(code, extra == null ? "" : extra.toString());
            }
        });
        callbackRegistered = true;
    }

    private Activity requireActivity() {
        Activity activity = getActivity();
        if (activity == null) {
            throw new IllegalStateException("Godot Activity 尚未就绪");
        }
        return activity;
    }

    private void emitInitialized(boolean success, String message) {
        runOnHostThread(() -> emitSignal(INITIALIZED, success, message));
    }

    private void emitLogin(boolean success, String openId, String message) {
        runOnHostThread(() -> emitSignal(LOGIN_RESULT, success, openId, message));
    }

    private void emitCompliance(int code, String message) {
        runOnHostThread(() -> emitSignal(COMPLIANCE_RESULT, code, message));
    }

    private static String messageOf(Throwable throwable) {
        String message = throwable.getMessage();
        return message == null || message.trim().isEmpty()
                ? throwable.getClass().getSimpleName()
                : message;
    }
}
