/* Copyright (c) 2015 Nordic Semiconductor. All Rights Reserved.
 *
 * The information contained herein is property of Nordic Semiconductor ASA.
 * Terms and conditions of usage are described in detail in NORDIC
 * SEMICONDUCTOR STANDARD SOFTWARE LICENSE AGREEMENT.
 *
 * Licensees are granted free, non-transferable use of the information. NO
 * WARRANTY of ANY KIND is provided. This heading must NOT be removed from
 * the file.
 *
 */

#include "nrf_ic_info.h"
#include "nrf.h"

void nrf_ic_info_get(nrf_ic_info_t * p_ic_info)
{
    uint32_t ic_data;

    ic_data = (((*((uint32_t volatile *)0xF0000FE8)) & 0x000000F0) >> 4);

    p_ic_info->ram_size = (uint16_t) NRF_FICR->NUMRAMBLOCK * (NRF_FICR->SIZERAMBLOCKS / 1024);
    p_ic_info->flash_size = (uint16_t) NRF_FICR->CODESIZE;
    switch (ic_data)
    {
        /** IC revision 1 */
        case 1:
            p_ic_info->ic_revision = IC_REVISION_NRF51_REV1;
            break;

        /** IC revision 2 */
        case 4:
            p_ic_info->ic_revision = IC_REVISION_NRF51_REV2;
            break;

        /** IC revision 3 */
        case 7:
            /* fall through */
        case 8:
            /* fall through */
        case 9:
            p_ic_info->ic_revision = IC_REVISION_NRF51_REV3;
            break;

        default:
            p_ic_info->ic_revision = IC_REVISION_NRF51_UNKNOWN;
            break;
    }
}
