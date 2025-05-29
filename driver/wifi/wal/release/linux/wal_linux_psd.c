/*
 * Copyright (c) CompanyNameMagicTag 2022-2022. All rights reserved.
 * Description: wal_linux_psd
 * Create: 2022-08-15
 */
#ifdef _PRE_WLAN_FEATURE_PSD
#include "wal_linux_psd.h"

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif
#endif

#undef  THIS_FILE_ID
#define THIS_FILE_ID OAM_FILE_ID_WAL_LINUX_PSD_C
#undef THIS_MOD_ID
#define THIS_MOD_ID DIAG_MOD_ID_WIFI_HOST

osal_s32 wal_psd_data_report(hmac_vap_stru *hmac_vap, frw_msg *msg)
{
    unref_param(hmac_vap);
    unref_param(msg);

    return 0;
}

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif
#endif
