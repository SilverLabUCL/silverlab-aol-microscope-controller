/*
 * Generated with the FPGA Interface C API Generator 14.0.0
 * for NI-RIO 14.0.0 or later.
 */

#ifndef __NiFpga_FPGADAQ_variable_length_matlab_v13_h__
#define __NiFpga_FPGADAQ_variable_length_matlab_v13_h__

#ifndef NiFpga_Version
   #define NiFpga_Version 1400
#endif

#include "NiFpga.h"

/**
 * The filename of the FPGA bitfile.
 *
 * This is a #define to allow for string literal concatenation. For example:
 *
 *    static const char* const Bitfile = "C:\\" NiFpga_FPGADAQ_variable_length_matlab_v13_Bitfile;
 */
#define NiFpga_FPGADAQ_variable_length_matlab_v13_Bitfile "NiFpga_FPGADAQ_variable_length_matlab_v13.lvbitx"

/**
 * The signature of the FPGA bitfile.
 */
static const char* const NiFpga_FPGADAQ_variable_length_matlab_v13_Signature = "2F89F0E5AF6D023C3F4D65EA377BA44C";

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_AcquireMCBG = 0x8000022A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_Configured = 0x22,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_PLLLocked = 0x1A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_TXready = 0x86,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_UserCommandIdle = 0xA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_UserError = 0x1E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_abort_MC = 0x800001EA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_background_mc = 0x80000212,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_capturezrefcentroid = 0x11E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_endoftrial = 0x8000021A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_flag1_read = 0x80000202,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_flag2_read = 0x800001FA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_last_pixel = 0x11A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_lastpixel = 0x186,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_lostx = 0x6A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_lostxory = 0x56,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_losty = 0x66,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_lostz = 0x7A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_notlost_xory = 0x5A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_rec_on_bg = 0x8000022E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_resetxyaccum = 0x176,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_resetzaccum = 0x172,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_skip_z = 0x182,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_start_backref_pulse = 0x80000236,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_startpulseout = 0x8000020A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool_writerefframe = 0xFE,
} NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorBool;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU8_UserCommandStatus = 0xE,
} NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU8;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_x_cent_new_x10 = 0x132,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_x_cent_ref_x10 = 0x136,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_x_correction_X10 = 0x152,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_x_diff_X100 = 0x13A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_y_cent_new_x10 = 0x12A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_y_cent_ref_x10 = 0x126,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_y_correction_X10 = 0x14E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_y_diff_X100 = 0x12E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_z_cent_new_x10 = 0x142,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_z_cent_ref_x10 = 0x13E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_z_correction_X100 = 0x14A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16_z_diff_X100 = 0x146,
} NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorI16;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_AODfillin = 0x8000021E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_Enum = 0x800001F6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_aqstate = 0x80000232,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_bgsm_state = 0x80000216,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_nemrefypix = 0x80000222,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_num_xyref_pixels = 0xBE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_numxyzpixels = 0xC2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_pixel_count = 0xBA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_xpixelscurrent = 0x800001E2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16_ycount = 0x800001E6,
} NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU16;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU64_DataOut = 0x38,
   NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU64_X_Y_Z = 0xD8,
} NiFpga_FPGADAQ_variable_length_matlab_v13_IndicatorU64;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_ABORTTrigloop = 0x1D6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_CPHA = 0x2E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_CPOL = 0x32,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_EnableTrigger1 = 0x1CE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_EnableTrigger2 = 0x1CA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_EnableTrigger3 = 0x1C6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_EnableTrigger4 = 0x1C2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Enable_ZMC = 0xD6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Enablestimulusfunct = 0x1A6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Enablestimuluslive = 0x1B2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Experimentstart = 0x1DA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_MISO = 0x26,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Newlinetriggerenabled = 0x8000025A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_RESET = 0x2A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_Refcountresetenabled = 0x8000025E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_UserCommandCommit = 0x2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_enable_mc_recovery = 0x52,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_flag1_write = 0x80000206,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_flag2_write = 0x800001FE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_live_scan = 0x80000266,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_live_scantriggersmodule = 0x1D2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_select_ref_red = 0x80000262,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_set_reference = 0x8E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_start = 0x8000026A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_stop_background = 0x8000020E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_swapz = 0xD2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_use_host_offset_z = 0xDE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_use_varailble_length = 0x800001F2,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_use_vel_estimate = 0x46,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_usehostoffset = 0x8A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_useperiodicfunctional = 0x4E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_useslidingaverage = 0xF6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool_write_first_centroid_z = 0xEA,
} NiFpga_FPGADAQ_variable_length_matlab_v13_ControlBool;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8_HCP1 = 0x36,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8_UserCommand = 0x6,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8_UserData1 = 0x16,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8_ref_diff_x_y = 0x6E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8_ref_diff_z = 0x7E,
} NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU8;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_AODfill = 0x80000272,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Average = 0x9A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_AverageZ = 0xEE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Averageoffsets = 0x76,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_ImagingProtocol = 0x80000256,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Integral_scale = 0x166,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Integral_scale_z = 0x156,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Mode = 0x800001DE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Ref_z_lines = 0x8000023E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_RefsampsperpixPr = 0x8000024A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Refsampsperpix_z = 0x80000246,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_RefxpixelsperlineNpxr = 0x80000286,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_RefypixelsperlineNpyr = 0x80000282,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Trigger1function = 0x19E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_Trigger1selector = 0x80000252,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_UserData0 = 0x12,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_diff_thresh_x10 = 0x16E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_diff_thresh_x10_z = 0x16A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_ignore_z_lines = 0x17E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_mc_delayprog = 0x8000023A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_proportianal_x10 = 0x162,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_proportianal_x10_z = 0x15E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_ref_framedilute = 0xFA,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_ref_z_pixels_per_line = 0x80000242,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_sampleswaitafterpulse = 0x80000226,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_sampleswaitaftertrigger = 0x80000292,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_sampsperpixP = 0x8000024E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_scan_int_x1000 = 0x15A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_suppres_mc = 0x800001EE,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_threshold_xy = 0x82,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_threshold_z = 0x17A,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_xpixelsperlineNpx = 0x8000028E,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16_ypixelsperlineNpy = 0x8000028A,
} NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU16;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlI32_StartUpDelay = 0x80000278,
} NiFpga_FPGADAQ_variable_length_matlab_v13_ControlI32;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_NumberpixelspointingNp = 0x8000027C,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulseWidthfunct80MhzCycles2 = 0x1A8,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulseWidthlive80MhzCycles = 0x1B4,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulsewidthticksFrameCycleTrig = 0x194,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulsewidthticksLineTrig = 0x198,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulsewidthticksStartofExptrig = 0x18C,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_PulsewidthticksTrialtrig = 0x190,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_RefScanCycles = 0x80000274,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_RepeatNumberofCycles = 0x8000026C,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_TriggerDelay80MhzCycles = 0x1AC,
   NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32_TriggerPeriod80MhzCycles = 0x1B8,
} NiFpga_FPGADAQ_variable_length_matlab_v13_ControlU32;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_TargetToHostFifoU16_FIFOREFHOSTFRAME = 1,
} NiFpga_FPGADAQ_variable_length_matlab_v13_TargetToHostFifoU16;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_TargetToHostFifoU32_Channel0 = 3,
   NiFpga_FPGADAQ_variable_length_matlab_v13_TargetToHostFifoU32_Channel1 = 2,
} NiFpga_FPGADAQ_variable_length_matlab_v13_TargetToHostFifoU32;

typedef enum
{
   NiFpga_FPGADAQ_variable_length_matlab_v13_HostToTargetFifoU16_VARIABLELENGTHFIFO = 0,
} NiFpga_FPGADAQ_variable_length_matlab_v13_HostToTargetFifoU16;

#endif
