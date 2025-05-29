CUR_MK := $(abspath $(lastword $(MAKEFILE_LIST)))
TOP_DIR := $(shell dirname $(CUR_MK))

LIBNL := $(TOP_DIR)/libnl
LIBNL_DIR := $(TOP_DIR)/libnl/libnl-3.5.0
OPENSSL := $(TOP_DIR)/openssl
OPENSSL_DIR := $(TOP_DIR)/openssl/openssl-1.1.1n
WPA_SUPPLICANT := $(TOP_DIR)/wpa_supplicant
WPA_SUPPLICANT_DIR := $(TOP_DIR)/wpa_supplicant/wpa_supplicant-2.10
HOSTAPD := $(TOP_DIR)/hostapd
HOSTAPD_DIR := $(TOP_DIR)/hostapd/hostapd-2.10
IPERF := $(TOP_DIR)/iperf
IPERF_DIR := $(TOP_DIR)/iperf/iperf
OUTPUT_BUILD_DIR := $(SDK_OUTPUT_BUILD_DIR)/open_source
OUTPUT_BIN_DIR := $(SDK_OUTPUT_BIN_DIR)/open_source

# openssl and libnl temp build dir
OUTPUT_BUILD_OPENSSL_DIR := $(OUTPUT_BUILD_DIR)/openssl
OUTPUT_BUILD_LIBNL_DIR := $(OUTPUT_BUILD_DIR)/libnl

NO_COLOR=\033[0m
OK_COLOR=\033[32;01m

# wpa_supplicant and hostapd depends header
WPA_SUPPLICANT_HOSTAPD_DEP_HEADERS := -I$(OUTPUT_BUILD_OPENSSL_DIR)/include
WPA_SUPPLICANT_HOSTAPD_DEP_HEADERS += -I$(OUTPUT_BUILD_LIBNL_DIR)/include/libnl3
WPA_SUPPLICANT_HOSTAPD_DEP_HEADERS += -I$(LIBNL_DIR)/include/linux-private

# wpa_supplicant and hostapd depends libs
WPA_SUPPLICANT_HOSTAPD_DEP_LIBS := -L$(OUTPUT_BUILD_OPENSSL_DIR)/lib
WPA_SUPPLICANT_HOSTAPD_DEP_LIBS += -L$(OUTPUT_BUILD_LIBNL_DIR)/lib

# wpa_supplicant and hostapd depends pkg
WPA_SUPPLICANT_HOSTAPD_DEP_PKG := $(OUTPUT_BUILD_LIBNL_DIR)/lib/pkgconfig

CPU_NUM := $(shell cat /proc/stat | grep cpu[0-16] -c)

# build targets
BUILD_TARGETS :=
CLEAN_TARGETS := 
ifneq ($(wildcard $(LIBNL)),)
BUILD_TARGETS += libnl
CLEAN_TARGETS += libnl_clean
endif

ifneq ($(wildcard $(OPENSSL)),)
BUILD_TARGETS += openssl
CLEAN_TARGETS += openssl_clean
endif

ifneq ($(wildcard $(WPA_SUPPLICANT)),)
BUILD_TARGETS += wpa_supplicant
CLEAN_TARGETS += wpa_supplicant_clean
endif

ifneq ($(wildcard $(HOSTAPD)),)
BUILD_TARGETS += hostapd
CLEAN_TARGETS += hostapd_clean
endif

ifneq ($(wildcard $(IPERF)),)
BUILD_TARGETS += iperf
CLEAN_TARGETS += iperf_clean
endif


include $(WSCFG_KCONFIG_CONFIG)


.PHONY: libnl openssl wpa_supplicant hostapd iperf libnl_clean openssl_clean wpa_supplicant_clean hostapd_clean iperf_clean install

all: prepare $(BUILD_TARGETS)

clean: $(CLEAN_TARGETS)
	#rm -rf $(OUTPUT_BIN_DIR)
	rm -rf $(OUTPUT_BUILD_DIR)

prepare:
	@mkdir -p $(OUTPUT_BIN_DIR)
	@mkdir -p $(OUTPUT_BUILD_DIR)

libnl:
	cd $(LIBNL) && tar -xzf libnl-3.5.0.tar.gz
	cd $(LIBNL_DIR) && CC=${WSCFG_CROSS_COMPILE}gcc ./configure --host=${WSCFG_ARCH_NAME}-linux --prefix=$(OUTPUT_BUILD_LIBNL_DIR)
	cd $(LIBNL_DIR) && make -j${CPU_NUM} && make install -j${CPU_NUM}
	@printf "${OK_COLOR}========== libnl build OK! ==========${NO_COLOR}\n"

openssl:
	cd ${OPENSSL} && tar -xzf openssl-1.1.1n.tar.gz
	cd ${OPENSSL_DIR} && setarch i386 ./config no-asm shared no-async --prefix=$(OUTPUT_BUILD_OPENSSL_DIR) --cross-compile-prefix=${WSCFG_CROSS_COMPILE}
	sed -i "s/ -m32//g" ${OPENSSL_DIR}/Makefile
	cd ${OPENSSL_DIR} && make CC=${WSCFG_CROSS_COMPILE}gcc -j${CPU_NUM}
	cd ${OPENSSL_DIR} && make install -j${CPU_NUM}
	@printf "${OK_COLOR}========== openssl build OK! ==========${NO_COLOR}\n"

wpa_supplicant: openssl libnl
	cd ${WPA_SUPPLICANT} && tar -xzf wpa_supplicant-2.10.tar.gz
	cd ${WPA_SUPPLICANT_DIR} && patch -p1 < ../wpa_supplicant_2_10_linux.patch
	@cd $(WPA_SUPPLICANT_DIR)/wpa_supplicant && cp defconfig .config
	@sed -i "s/CONFIG_CTRL_IFACE_DBUS_NEW=y/#CONFIG_CTRL_IFACE_DBUS_NEW=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/CONFIG_CTRL_IFACE_DBUS_INTRO=y/#CONFIG_CTRL_IFACE_DBUS_INTRO=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONFIG_IEEE80211AX=y/CONFIG_IEEE80211AX=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONNECTIVITY_SET_P2P_IE_PATCH=y/CONNECTIVITY_SET_P2P_IE_PATCH=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONNECTIVITY_SINGLE_VAP_PATCH=y/CONNECTIVITY_SINGLE_VAP_PATCH=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONNECTIVITY_LOG_PATCH=y/CONNECTIVITY_LOG_PATCH=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONFIG_WEP=y/CONFIG_WEP=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	@sed -i "s/#CONFIG_OWE=y/CONFIG_OWE=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config

	@sed -i "s/#CONFIG_ROAM_EXTRA_SUPPORT=y/CONFIG_ROAM_EXTRA_SUPPORT=y/g" ${WPA_SUPPLICANT_DIR}/wpa_supplicant/.config
	cd ${WPA_SUPPLICANT_DIR}/wpa_supplicant &&\
    EXTRA_CFLAGS="$(WPA_SUPPLICANT_HOSTAPD_DEP_HEADERS)"  LIBS="$(WPA_SUPPLICANT_HOSTAPD_DEP_LIBS)"\
    PKG_CONFIG_PATH="$(WPA_SUPPLICANT_HOSTAPD_DEP_PKG)" make CC=${WSCFG_CROSS_COMPILE}gcc -j${CPU_NUM}
	@printf "${OK_COLOR}========== wpa_supplicant build OK! ==========${NO_COLOR}\n"

hostapd: openssl libnl
	cd ${HOSTAPD} && tar -xzf hostapd-2.10.tar.gz
	@cd $(HOSTAPD_DIR)/hostapd && cp defconfig .config
	@sed -i "s/#CONFIG_IEEE80211AX=y/CONFIG_IEEE80211AX=y/g" ${HOSTAPD_DIR}/hostapd/.config
	@sed -i "s/#CONFIG_WEP=y/CONFIG_WEP=y/g" ${HOSTAPD_DIR}/hostapd/.config
	@sed -i "s/#CONFIG_WPS=y/CONFIG_WPS=y/g" ${HOSTAPD_DIR}/hostapd/.config
	@sed -i "s/#CONFIG_ACS=y/CONFIG_ACS=y/g" ${HOSTAPD_DIR}/hostapd/.config
	@sed -i "s/#CONFIG_OWE=y/CONFIG_OWE=y/g" ${HOSTAPD_DIR}/hostapd/.config
	@cd $(HOSTAPD_DIR)/hostapd && echo "CONFIG_SAE=y" >> .config
	@cd $(HOSTAPD_DIR) && echo "DRV_OBJS += ../src/drivers/driver_nl80211_android.o" >> src/drivers/drivers.mak

	@cd $(HOSTAPD_DIR)/hostapd && EXTRA_CFLAGS="${WPA_SUPPLICANT_HOSTAPD_DEP_HEADERS}"\
    LIBS="${WPA_SUPPLICANT_HOSTAPD_DEP_LIBS}" PKG_CONFIG_PATH="${WPA_SUPPLICANT_HOSTAPD_DEP_PKG}"\
    make CC=${WSCFG_CROSS_COMPILE}gcc -j${CPU_NUM}
	@printf "${OK_COLOR}========== hostapd build OK! ==========${NO_COLOR}\n"

iperf:
	@cd $(IPERF_DIR) &&\
    CC=${WSCFG_CROSS_COMPILE}gcc ./configure --host=${WSCFG_ARCH_NAME}-linux CFLAGS=-static\
    --enable-static LDFLAGS=-static --disable-shared --with-openssl=no
	cd $(IPERF_DIR) && make -j${CPU_NUM}
	@printf "${OK_COLOR}========== iperf build OK! ==========${NO_COLOR}\n"

install:
ifneq ($(wildcard $(LIBNL_DIR)),)
	@cp ${OUTPUT_BUILD_LIBNL_DIR}/lib/libnl-3.so.200.26.0 ${OUTPUT_BIN_DIR}/
	@cp ${OUTPUT_BUILD_LIBNL_DIR}/lib/libnl-genl-3.so.200.26.0 ${OUTPUT_BIN_DIR}/
	@cp ${OUTPUT_BUILD_LIBNL_DIR}/lib/libnl-route-3.so.200 ${OUTPUT_BIN_DIR}/
	@${WSCFG_CROSS_COMPILE}strip --strip-unneeded ${OUTPUT_BIN_DIR}/libnl-3.so.200.26.0
	@${WSCFG_CROSS_COMPILE}strip --strip-unneeded ${OUTPUT_BIN_DIR}/libnl-genl-3.so.200.26.0
	@${WSCFG_CROSS_COMPILE}strip --strip-unneeded ${OUTPUT_BIN_DIR}/libnl-route-3.so.200
	@printf "${OK_COLOR}========== libnl install OK! ==========${NO_COLOR}\n"
endif

ifneq ($(wildcard $(OPENSSL_DIR)),)
	@cp ${OUTPUT_BUILD_OPENSSL_DIR}/lib/libcrypto.so.1.1 ${OUTPUT_BIN_DIR}/
	@cp ${OUTPUT_BUILD_OPENSSL_DIR}/lib/libssl.so.1.1 ${OUTPUT_BIN_DIR}/
	@${WSCFG_CROSS_COMPILE}strip --strip-unneeded ${OUTPUT_BIN_DIR}/libcrypto.so.1.1
	@${WSCFG_CROSS_COMPILE}strip --strip-unneeded ${OUTPUT_BIN_DIR}/libssl.so.1.1
	@printf "${OK_COLOR}========== openssl install OK! ==========${NO_COLOR}\n"
endif

ifneq ($(wildcard $(WPA_SUPPLICANT_DIR)),)
	@cp ${WPA_SUPPLICANT_DIR}/wpa_supplicant/wpa_cli ${OUTPUT_BIN_DIR}/
	@cp ${WPA_SUPPLICANT_DIR}/wpa_supplicant/wpa_supplicant ${OUTPUT_BIN_DIR}/
	@cp ${WPA_SUPPLICANT_DIR}/wpa_supplicant/wpa_supplicant.conf ${OUTPUT_BIN_DIR}/
	@${WSCFG_CROSS_COMPILE}strip ${OUTPUT_BIN_DIR}/wpa_supplicant --strip-unneeded
	@${WSCFG_CROSS_COMPILE}strip ${OUTPUT_BIN_DIR}/wpa_cli --strip-unneeded
	@printf "${OK_COLOR}========== wpa_supplicant install OK! ==========${NO_COLOR}\n"
endif

ifneq ($(wildcard $(HOSTAPD_DIR)),)
	@cp ${HOSTAPD_DIR}/hostapd/hostapd ${OUTPUT_BIN_DIR}/
	@cp ${HOSTAPD_DIR}/hostapd/hostapd_cli ${OUTPUT_BIN_DIR}/
	@cp ${HOSTAPD_DIR}/hostapd/hostapd.conf ${OUTPUT_BIN_DIR}/
	@${WSCFG_CROSS_COMPILE}strip ${OUTPUT_BIN_DIR}/hostapd --strip-unneeded
	@${WSCFG_CROSS_COMPILE}strip ${OUTPUT_BIN_DIR}/hostapd_cli --strip-unneeded
	@printf "${OK_COLOR}========== hostapd install OK! ==========${NO_COLOR}\n"
endif

ifneq ($(wildcard $(IPERF_DIR)),)
	@cp ${IPERF_DIR}/src/iperf3 ${OUTPUT_BIN_DIR}/
	@${WSCFG_CROSS_COMPILE}strip ${OUTPUT_BIN_DIR}/iperf3 --strip-unneeded
	@printf "${OK_COLOR}========== iperf install OK! ==========${NO_COLOR}\n"
endif


libnl_clean:
	@cd ${LIBNL}/ && rm -rf ${LIBNL_DIR}/
	# @cd ${LIBNL_DIR}/ && make CC=${WSCFG_CROSS_COMPILE}gcc clean

openssl_clean:
	@cd ${OPENSSL}/ && rm -rf ${OPENSSL_DIR}/
	# @cd ${OPENSSL_DIR}/ && make CC=${WSCFG_CROSS_COMPILE}gcc clean

wpa_supplicant_clean:
	@cd ${WPA_SUPPLICANT}/ && rm -rf ${WPA_SUPPLICANT_DIR}/
	# @cd ${WPA_SUPPLICANT_DIR}/wpa_supplicant && make CC=${WSCFG_CROSS_COMPILE}gcc clean

hostapd_clean:
	@cd ${HOSTAPD}/ && rm -rf ${HOSTAPD_DIR}/
	# @cd ${HOSTAPD_DIR}/hostapd && make CC=${WSCFG_CROSS_COMPILE}gcc clean
	# @sed -i "s/DRV_OBJS += \.\.\/src\/drivers\/driver_nl80211_android\.o//g" ${HOSTAPD_DIR}/hostapd/../src/drivers/drivers.mak


iperf_clean:
	@cd ${IPERF_DIR} && make CC=${WSCFG_CROSS_COMPILE}gcc clean
