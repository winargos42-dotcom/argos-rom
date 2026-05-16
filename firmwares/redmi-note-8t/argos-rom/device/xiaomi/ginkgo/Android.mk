# ARGOS Multi-Tool ROM Device Overlay for ginkgo
# Includes ARGOS prebuilts and system modifications

LOCAL_PATH := $(call my-dir)

# Prebuilt Termux
include $(CLEAR_VARS)
LOCAL_MODULE := Termux
LOCAL_SRC_FILES := prebuilts/Termux.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_PRIVILEGED_MODULE := true
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_OVERRIDES_PACKAGES := TerminalEmulator
include $(BUILD_PREBUILT)

# Prebuilt Magisk (if needed as system app)
include $(CLEAR_VARS)
LOCAL_MODULE := Magisk
LOCAL_SRC_FILES := prebuilts/Magisk.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_CERTIFICATE := PRESIGNED
include $(BUILD_PREBUILT)

# Prebuilt WiFi Analyzer
include $(CLEAR_VARS)
LOCAL_MODULE := WiFiAnalyzer
LOCAL_SRC_FILES := prebuilts/WiFiAnalyzer.apk
LOCAL_MODULE_CLASS := APPS
LOCAL_CERTIFICATE := PRESIGNED
include $(BUILD_PREBUILT)

# ARGOS init script
include $(CLEAR_VARS)
LOCAL_MODULE := 99argos
LOCAL_SRC_FILES := init/99argos
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT)/etc/init.d
include $(BUILD_PREBUILT)
