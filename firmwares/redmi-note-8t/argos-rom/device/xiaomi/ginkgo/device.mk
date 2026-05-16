# ARGOS Multi-Tool ROM overlay for ginkgo
# Add to existing device/xiaomi/ginkgo/device.mk

# Include ARGOS prebuilts
PRODUCT_PACKAGES += \
    Termux \
    WiFiAnalyzer \
    Magisk

# ARGOS system properties
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.locale=ru-RU \
    persist.sys.language=ru \
    persist.sys.country=RU \
    ro.product.locale=ru-RU \
    ro.com.android.dateformat=dd-MM-yyyy

# ARGOS permissions for USB/Serial/CAN
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init/99argos:$(TARGET_COPY_OUT_SYSTEM)/etc/init.d/99argos \
    $(LOCAL_PATH)/init/argos-usb.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/argos-usb.rc \
    $(LOCAL_PATH)/permissions/com.argos.hardware.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/com.argos.hardware.xml

# ARGOS xbin tools
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/system/xbin/argos-status:$(TARGET_COPY_OUT_SYSTEM)/xbin/argos-status \
    $(LOCAL_PATH)/system/xbin/argos-usb-setup:$(TARGET_COPY_OUT_SYSTEM)/xbin/argos-usb-setup \
    $(LOCAL_PATH)/system/xbin/argos-can-up:$(TARGET_COPY_OUT_SYSTEM)/xbin/argos-can-up \
    $(LOCAL_PATH)/system/xbin/argos-colibri:$(TARGET_COPY_OUT_SYSTEM)/xbin/argos-colibri \
    $(LOCAL_PATH)/system/xbin/argos-bridge:$(TARGET_COPY_OUT_SYSTEM)/xbin/argos-bridge

# Kernel configs for ARGOS hardware support
TARGET_KERNEL_CONFIG := argos_ginkgo_defconfig
