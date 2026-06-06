/*
HolyC Atari 2600 emulator proof slice for TempleOS.

Source lineage:
  z26 4.07, Copyright 1997-2019 John Saeger and contributors.
  z26 is GPLv2.  Original source: https://www.whimsey.com/z26/

This is a small HolyC port of the z26-style architecture, not the full z26
emulator.  It implements enough 6507, flat/F8 cartridge mapping, RIOT RAM/timer,
TIA write/display behavior, collisions, and simple joystick/paddle/driving
controls for early 2K/4K and banked 2600 carts inside TempleOS.  If CART.BIN
or SPECT1.BIN is on the transfer disk, it loads flat, Atari F8/F6/F4,
  SC/SARA, Parker E0, 0840/EconoBanking, 0FA0/Fotomania, 03E0,
UA Limited/UASW, WD/WDSW, WF8,
Tigervision 3F/3E, M-Network E7, CBS FA, Activision FE, DPC/Pitfall II,
Starpath/Supercharger, FA2/Harmony flash, EF/EFSC, DF/DFSC, BF/BFSC, or
MDM cart images;
otherwise it falls back to the embedded proof ROM.
*/

#exe {Option(OPTf_WARN_UNUSED_VAR,OFF);};

#define A2600_ROM_SIZE   524288
#define A2600_F0_SIZE      65536
#define A2600_BANK_SIZE    4096
#define A2600_FA2_SIZE    28672
#define A2600_CART_PATH_MAX  256
#define A2600_RAM_SIZE      128
#define A2600_SARA_SIZE     128
#define A2600_CART_RAM_SIZE 65536
#define A2600_FB_W         160
#define A2600_FB_H         384
#define A2600_VIEW_Y0      8
#define A2600_VIEW_H       228
#define A2600_TIA_COLOR_COUNT       128
#define A2600_PROG_SIZE     61
#define A2600_STARPATH_LOAD_SIZE 8448
#define A2600_FA2_READ_DELAY_CYCLES 596
#define A2600_FA2_WRITE_DELAY_CYCLES 120477
#define A2600_CM_CAS_MIN_SIZE        1540
#define A2600_CM_CAS_MAX_SIZE        2052
#define A2600_CM_CAS_SYNC_BYTES       943
#define A2600_CM_CAS_FRAME_BITS        13
#define A2600_CM_SAVE_MIN_FSK_GAP     150
#define A2600_CM_SAVE_MAX_CALIB_GAP   800
#define A2600_CM_SAVE_TIMEOUT_CYCLES 60000
#define A2600_SCORE_SPLIT_X 80
#define A2600_PADDLE_MIN_CYCLES     (1*76)
#define A2600_PADDLE_CHARGE_CYCLES (379*76)
#define A2600_PADDLE_STEP           8
#define A2600_LIGHTGUN_WINDOW       15
#define A2600_FM_WAIT_VSYNC_START     0
#define A2600_FM_WAIT_VSYNC_END       1
#define A2600_FM_WAIT_FRAME_START     2
#define A2600_FM_FRAME                3
#define A2600_FM_NTSC_LINES         262
#define A2600_FM_PAL_LINES          312
#define A2600_FM_NTSC_YSTART         23
#define A2600_FM_PAL_YSTART          32
#define A2600_FM_NTSC_HEIGHT        228
#define A2600_FM_PAL_HEIGHT         274
#define A2600_FM_MAX_VSYNC_LINES     50
#define A2600_Z26_CRC32_REV   0xA0000001
#define A2600_TV_NTSC                 0
#define A2600_TV_PAL                  1
#define A2600_TV_SECAM                2
#define A2600_TV_NTSC50               3
#define A2600_TV_PAL60                4
#define A2600_TV_SECAM60              5
#define A2600_TV_UNKNOWN             -1

#define A2600_CTRL_JS                 0
#define A2600_CTRL_PADDLE             1
#define A2600_CTRL_DRIVING            3
#define A2600_CTRL_LIGHTGUN           4
#define A2600_CTRL_COMPUMATE          5
#define A2600_CTRL_KIDVID             6
#define A2600_CTRL_MINDLINK           7
#define A2600_CTRL_ST_MOUSE           8
#define A2600_CTRL_TRAKBALL           9
#define A2600_CTRL_AMIGA_MOUSE       10
#define A2600_CTRL_BOOSTER           12
#define A2600_CTRL_GENESIS           13
#define A2600_CTRL_JOY2B             14
#define A2600_CTRL_QUADTARI          15
#define A2600_CTRL_SAVEKEY           16
#define A2600_CTRL_ATARIVOX          17
#define A2600_QUADTARI_STABLE_CYCLES 76

#define A2600_KIDVID_SMURFS       0x44
#define A2600_KIDVID_BBEARS       0x48
#define A2600_KIDVID_BLOCK_BYTES     6
#define A2600_KIDVID_BLOCK_BITS     48
#define A2600_KIDVID_DATA00_BITS    96
#define A2600_KIDVID_PAUSE_BITS    288
#define A2600_KIDVID_END_BITS      336
#define A2600_KIDVID_NO_WAV_DELAY   32
#define A2600_SAVEKEY_SIZE        32768
#define A2600_SAVEKEY_PAGE           64
#define A2600_SAVEKEY_PACKET_MAX    128
#define A2600_SAVEKEY_WRITE_CYCLES 5966
#define A2600_SAVEKEY_IDLE            0
#define A2600_SAVEKEY_BYTE_IN         1
#define A2600_SAVEKEY_ACK             2
#define A2600_SAVEKEY_BYTE_OUT        3
#define A2600_SAVEKEY_WAIT_ACK        4
#define A2600_ATARIVOX_BIT_CYCLES    62
#define A2600_ATARIVOX_GAP_CYCLES  1000
#define A2600_HALT_NONE              0
#define A2600_HALT_UNSUPPORTED       1
#define A2600_HALT_JAM               2
#define A2600_HALT_GUARD             3

#define A2600_CART_STD 0
#define A2600_CART_E0  1
#define A2600_CART_3F  2
#define A2600_CART_3E  3
#define A2600_CART_E7  4
#define A2600_CART_FA  5
#define A2600_CART_FE  6
#define A2600_CART_DPC 7
#define A2600_CART_AR  8
#define A2600_CART_F0  9
#define A2600_CART_EF  10
#define A2600_CART_DF  11
#define A2600_CART_BF  12
#define A2600_CART_FC  13
#define A2600_CART_CV  14
#define A2600_CART_0840 15
#define A2600_CART_0FA0 16
#define A2600_CART_03E0 17
#define A2600_CART_UA  18
#define A2600_CART_UASW 19
#define A2600_CART_WD  20
#define A2600_CART_WDSW 21
#define A2600_CART_WF8 22
#define A2600_CART_3EP 23
#define A2600_CART_3EX 24
#define A2600_CART_JANE 25
#define A2600_CART_SB  26
#define A2600_CART_X07 27
#define A2600_CART_GL  28
#define A2600_CART_4A50 29
#define A2600_CART_MDM 30
#define A2600_CART_TVBOY 31
#define A2600_CART_FA2 32
#define A2600_CART_CM  33

#define A2600_F_C 0x01
#define A2600_F_Z 0x02
#define A2600_F_I 0x04
#define A2600_F_D 0x08
#define A2600_F_B 0x10
#define A2600_F_V 0x40
#define A2600_F_N 0x80

// TIA write registers used by the proof ROM and common simple carts.
#define A2600_VSYNC  0x00
#define A2600_VBLANK 0x01
#define A2600_WSYNC  0x02
#define A2600_RSYNC  0x03
#define A2600_NUSIZ0 0x04
#define A2600_NUSIZ1 0x05
#define A2600_COLUP0 0x06
#define A2600_COLUP1 0x07
#define A2600_COLUPF 0x08
#define A2600_COLUBK 0x09
#define A2600_CTRLPF 0x0A
#define A2600_REFP0  0x0B
#define A2600_REFP1  0x0C
#define A2600_PF0    0x0D
#define A2600_PF1    0x0E
#define A2600_PF2    0x0F
#define A2600_RESP0  0x10
#define A2600_RESP1  0x11
#define A2600_RESM0  0x12
#define A2600_RESM1  0x13
#define A2600_RESBL  0x14
#define A2600_AUDC0  0x15
#define A2600_AUDC1  0x16
#define A2600_AUDF0  0x17
#define A2600_AUDF1  0x18
#define A2600_AUDV0  0x19
#define A2600_AUDV1  0x1A
#define A2600_GRP0   0x1B
#define A2600_GRP1   0x1C
#define A2600_ENAM0  0x1D
#define A2600_ENAM1  0x1E
#define A2600_ENABL  0x1F
#define A2600_HMP0   0x20
#define A2600_HMP1   0x21
#define A2600_HMM0   0x22
#define A2600_HMM1   0x23
#define A2600_HMBL   0x24
#define A2600_VDELP0 0x25
#define A2600_VDELP1 0x26
#define A2600_VDELBL 0x27
#define A2600_RESMP0 0x28
#define A2600_RESMP1 0x29
#define A2600_HMOVE  0x2A
#define A2600_HMCLR  0x2B
#define A2600_CXCLR  0x2C

#define A2600_SWCHA  0x0280
#define A2600_SWACNT 0x0281
#define A2600_SWCHB  0x0282
#define A2600_SWBCNT 0x0283
#define A2600_INTIM  0x0284
#define A2600_INSTAT 0x0285
#define A2600_TIM1T  0x0294
#define A2600_TIM8T  0x0295
#define A2600_TIM64T 0x0296
#define A2600_TIM1024T 0x0297

#define A2600_SC_SPACE 0x39
#define A2600_SC_ENTER 0x1C
#define A2600_INPUT_HOLD_DECAY 24

U8 a2600_rom[A2600_ROM_SIZE],a2600_ram[A2600_RAM_SIZE],
   a2600_sara[A2600_SARA_SIZE],a2600_cart_ram[A2600_CART_RAM_SIZE],
   a2600_gl_init_ram[2048],a2600_fa2_flash[256],
   a2600_savekey_eeprom[A2600_SAVEKEY_SIZE],
   a2600_savekey_path[A2600_CART_PATH_MAX],
   a2600_savekey_packet[A2600_SAVEKEY_PACKET_MAX],
   a2600_compumate_cas[A2600_CM_CAS_MAX_SIZE],
   a2600_compumate_cas_path[A2600_CART_PATH_MAX],
   a2600_tia[64],a2600_coll[8],
   a2600_fb[A2600_FB_W*A2600_FB_H],a2600_prev_fb[A2600_FB_W*A2600_FB_H];

U8 a2600_prog[A2600_PROG_SIZE]={
  0x78,0xD8,0xA2,0xFF,0x9A,0xE6,0x80,0xA5,
  0x80,0x29,0x0E,0x09,0x40,0x85,0x08,0xA9,
  0x00,0x85,0x01,0xA9,0x22,0x85,0x09,0xA9,
  0x03,0x85,0x0A,0xA9,0xF0,0x85,0x0D,0xA2,
  0xC0,0x8A,0x45,0x80,0x85,0x0E,0x49,0xFF,
  0x85,0x0F,0x85,0x02,0xCA,0xD0,0xF2,0xA9,
  0x02,0x85,0x01,0xA2,0x28,0x85,0x02,0xCA,
  0xD0,0xFB,0x4C,0x05,0xF0
};

I64 a2600_weird_resp[26]={
  0,0,0,0,0,0,1,2,2,3,4,5,5,6,7,8,8,9,10,11,11,12,13,14,14,15
};

I64 a2600_max_motion[21]={
  7,7,7,7,6,7,7,4,3,2,2,1,0,-1,-1,-2,-3,-4,-4,-5,-6
};

I64 a2600_hi_motion[20]={
  14,13,12,12,11,10,9,9,8,7,6,6,5,4,3,3,2,1,0,0
};

I64 a2600_deep_hmove_end[16]={
  15,16,18,19,20,22,23,24,-1,6,7,8,10,11,12,14
};

I64 a2600_driving_table[4]={0x0F,0x0D,0x0C,0x0E};
I64 a2600_kidvid_blocks[6]={42,23,37,102,120,102};
U8 a2600_kidvid_data[48]={
  0x7B,0x1E,0xC6,0x31,0xEC,0x60,
  0x7B,0x1E,0xC6,0x3D,0x8C,0x60,
  0xF6,0x31,0x8C,0x63,0x18,0xC0,
  0xF6,0x31,0x8C,0x63,0x18,0xF0,
  0xF6,0x31,0x8C,0x63,0x1E,0xC0,
  0xF6,0x31,0x8C,0x63,0x1E,0xF0,
  0x3F,0xF0,0x00,0x00,0x00,0x00,
  0xF7,0xB1,0x8C,0x63,0x18,0xC0
};
I64 a2600_stella_phosphor_crc[156]={
  0x00BA2D68,0x00E44527,0x02969F95,0x05A357E7,0x06E5D652,0x0A0C9D67,
  0x0E80B949,0x12C652B2,0x1448E3D2,0x15D8E02B,0x16B1A362,0x16D29A52,
  0x1CB28465,0x1D12E8C1,0x1ED37EBD,0x1EE7036E,0x218F7846,0x220F406F,
  0x23184B03,0x231E70A6,0x24C35820,0x27E43843,0x2843D776,0x286422CE,
  0x2990C903,0x29C93A2C,0x2A2B87E8,0x2AACE942,0x2BC25098,0x3097E0EB,
  0x3207FED6,0x3216C1BB,0x34132E52,0x350C63BA,0x393372E5,0x39A5F247,
  0x3A9544B2,0x3D77201B,0x405464EE,0x41CBA411,0x421D090E,0x4323A078,
  0x45322C96,0x46DFCDC1,0x49176010,0x4D01AEEA,0x4F40A18E,0x525EE7E9,
  0x5474D585,0x55DA122D,0x57B51249,0x57F730EE,0x596160D3,0x5B171752,
  0x5C161FE4,0x5F2F97CB,0x60CA5D54,0x62171047,0x63D00489,0x646D7ECB,
  0x666B38F0,0x67B79CD2,0x688E9322,0x6A20DAFE,0x6B07D014,0x6DD6CDA9,
  0x6F79FAB8,0x70882147,0x7117E8A9,0x714A692B,0x71E94FE7,0x73D8C9D0,
  0x75A39600,0x75BD9195,0x76692470,0x781CACB5,0x7B4EB49C,0x7DF7D546,
  0x7FAA11DF,0x80F09601,0x80F5E00E,0x821F0B17,0x82C6F7D1,0x841FFA1D,
  0x85BC70DE,0x86BC321D,0x8973F4AF,0x8B232FBB,0x8C2F6264,0x8CF6D327,
  0x8FA212F4,0x98EFB758,0x99014258,0x99066A16,0x9A46F393,0x9A650E9C,
  0x9B4F27DF,0x9CDC81B6,0x9D63D054,0x9FA932C2,0xA0794137,0xA69350ED,
  0xA7890826,0xAC684ABF,0xACDB6441,0xAEBFD482,0xAEDB3C29,0xB2DC8F20,
  0xB43C3E99,0xB7E38E1E,0xB87A10B7,0xBAA38059,0xBC5527E7,0xBEF9ACEF,
  0xBF933DE2,0xC09801FB,0xC2ECB3E5,0xC39C7A29,0xC4BE9818,0xC78C97BD,
  0xC820EA0D,0xCC1416D8,0xCC902AA0,0xCD3B3A14,0xCE09FCD4,0xD36C9159,
  0xD3B1A2D4,0xD6BAA6CF,0xD7036918,0xD865A8DD,0xD9088807,0xD9C47532,
  0xDC25B7EA,0xDC2B8A0A,0xDCC86139,0xDE6D008E,0xE03A1D85,0xE28451F7,
  0xE77F6742,0xE8B1225F,0xEA815972,0xEBE1D63C,0xEFFD25DB,0xF1A0A2BD,
  0xF4036713,0xF438F25D,0xF48B6B4C,0xF50DD9F4,0xF58DDF00,0xF5F8FFFF,
  0xF723B8A6,0xF78C1EF6,0xFA07AA39,0xFD624556,0xFEC87E0D,-1
};

I64 a2600_stella_tv_ntsc_crc[3]={
  0x28B02D7F,0xAFC7460F,-1
};
I64 a2600_stella_tv_pal_crc[2]={
  0x08CBD58E,-1
};
I64 a2600_stella_tv_ntsc50_crc[3]={
  0x4F40A18E,0x04F40A18,-1
};
I64 a2600_stella_tv_pal60_crc[3]={
  0xFA07AA39,0x5685C6AB,-1
};
I64 a2600_z26_genesis_both[2]={
  0x135C8DC2,-1
};
I64 a2600_z26_joy2b_both[2]={
  0x79461BAB,-1
};
I64 a2600_stella_atarivox_right[2]={
  0xE9D5ADA0,-1
};
I64 a2600_dpc_mix_audv[8]={0,6,5,11,4,10,9,15};
U8 a2600_tia_ntsc_pal[A2600_TIA_COLOR_COUNT]={
  0,8,8,7,7,7,15,15,
  0,6,6,6,6,14,14,14,
  0,6,6,6,6,14,14,14,
  0,6,6,6,6,6,14,14,
  4,4,4,12,12,12,13,13,
  8,5,5,5,13,13,13,13,
  8,1,5,5,13,13,9,9,
  1,1,1,9,9,9,9,9,
  1,1,1,9,9,9,9,9,
  1,1,3,3,9,9,11,11,
  0,3,3,3,11,11,11,11,
  0,2,3,3,10,10,11,11,
  0,2,2,10,10,10,10,14,
  0,2,2,10,10,14,14,14,
  0,6,6,6,14,14,14,14,
  0,6,6,6,14,14,14,14
};
U8 a2600_tia_ntsc_r[A2600_TIA_COLOR_COUNT]={
   20, 38, 66,102,132,165,193,214,
   27, 45, 73,109,139,173,201,221,
   57, 75,103,138,169,202,230,251,
   71, 89,117,153,184,217,245,255,
   86,103,132,167,198,231,255,255,
   87,105,133,169,200,233,255,255,
   65, 83,111,146,177,210,238,255,
   34, 52, 80,115,146,179,207,228,
    5, 23, 51, 87,118,151,179,199,
    0,  0, 25, 61, 92,125,153,173,
    0,  0, 12, 47, 78,111,139,160,
    0,  0,  0, 34, 64, 98,126,146,
    0,  0,  0, 33, 64, 97,125,145,
    0,  0,  5, 41, 72,105,133,153,
    7, 25, 53, 89,119,152,180,201,
   35, 53, 81,117,148,181,209,229
};
U8 a2600_tia_ntsc_g[A2600_TIA_COLOR_COUNT]={
   20, 38, 66,102,132,165,193,214,
   37, 55, 83,119,149,182,211,231,
   18, 36, 64,100,131,164,192,212,
    7, 25, 53, 89,119,152,180,201,
    0, 10, 38, 74,104,137,165,186,
    0,  0, 26, 61, 92,125,153,173,
    0,  0, 26, 62, 92,126,154,174,
    0, 10, 38, 73,104,137,165,186,
    7, 25, 53, 88,119,152,180,201,
   24, 42, 70,106,136,169,197,218,
   35, 53, 81,117,147,181,209,229,
   51, 69, 97,133,163,196,224,245,
   59, 77,105,141,171,204,232,253,
   62, 80,108,144,174,207,235,255,
   47, 65, 93,129,160,193,221,241,
   32, 50, 78,114,145,178,206,226
};
U8 a2600_tia_ntsc_b[A2600_TIA_COLOR_COUNT]={
   20, 38, 66,102,132,165,193,214,
    0,  0,  0,  0,  0,  0,  0,  0,
    0,  0,  0, 13, 43, 76,104,125,
    0,  0,  0, 33, 64, 97,125,145,
    0,  9, 37, 73,103,136,164,185,
   50, 68, 96,132,162,196,224,244,
  107,125,153,188,219,252,255,255,
  128,146,174,209,240,255,255,255,
  125,143,171,207,237,255,255,255,
  105,123,151,187,217,250,255,255,
   83,101,129,165,195,229,255,255,
   38, 55, 83,119,150,183,211,231,
    0, 16, 44, 79,110,143,171,192,
    0,  0,  7, 43, 73,106,134,155,
    0,  0,  0,  0, 24, 57, 85,106,
    0,  0,  0,  0, 27, 60, 88,109
};
U8 a2600_tia_pal_pal[A2600_TIA_COLOR_COUNT]={
  0,0,8,8,7,7,7,15,
  0,0,8,8,7,7,7,15,
  0,4,6,6,6,12,14,14,
  0,2,2,2,2,10,10,10,
  4,4,6,6,6,12,14,14,
  0,2,2,2,10,10,10,10,
  4,4,4,6,12,12,7,7,
  0,0,2,3,3,7,11,11,
  8,8,5,5,7,13,13,13,
  1,1,3,3,3,11,11,11,
  8,5,5,5,13,13,13,13,
  1,1,1,9,9,9,11,11,
  1,1,5,9,9,13,13,15,
  1,1,8,9,9,7,7,15,
  0,0,8,8,7,7,7,15,
  0,0,8,8,7,7,7,15
};
U8 a2600_tia_pal_r[A2600_TIA_COLOR_COUNT]={
   0, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214,
  81, 99,127,163,193,227,255,255,
   0,  0,  0, 32, 62, 95,123,144,
  96,114,142,178,208,241,255,255,
   0,  0,  0, 22, 52, 86,114,134,
 100,118,146,182,213,246,255,255,
   0,  0,  0, 23, 54, 87,115,135,
  93,111,139,175,206,239,255,255,
   0,  0,  0, 35, 66, 99,127,148,
  76, 94,122,158,188,222,250,255,
   0,  0, 21, 57, 88,121,149,169,
  51, 69, 97,133,163,197,225,245,
   3, 21, 49, 85,115,148,176,197,
  20, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214
};
U8 a2600_tia_pal_g[A2600_TIA_COLOR_COUNT]={
   0, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214,
   7, 25, 53, 89,120,153,181,201,
  75, 93,121,157,187,221,249,255,
   0, 17, 45, 81,111,144,173,193,
  74, 92,120,156,186,220,248,255,
   0,  4, 33, 68, 99,132,160,180,
  60, 78,106,142,172,206,234,254,
   0,  0, 22, 57, 88,121,149,170,
  40, 58, 86,122,153,186,214,234,
   0,  0, 20, 55, 86,119,147,167,
  23, 41, 69,105,135,168,196,217,
   0,  3, 31, 67, 97,130,158,179,
  13, 31, 59, 94,125,158,186,207,
  20, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214
};
U8 a2600_tia_pal_b[A2600_TIA_COLOR_COUNT]={
   0, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214,
   0,  0,  0,  5, 36, 69, 97,118,
   0,  0,  0,  0, 31, 64, 92,112,
   0,  0,  0,  9, 39, 73,101,121,
   0,  0,  0, 30, 61, 94,122,143,
   0,  0, 26, 62, 93,126,154,174,
  17, 35, 63, 99,130,163,191,211,
  55, 73,101,136,167,200,228,249,
  87,105,133,169,200,233,255,255,
 110,128,156,192,223,255,255,255,
 121,139,167,203,233,255,255,255,
 117,135,163,199,230,255,255,255,
 100,118,146,182,213,246,255,255,
  20, 38, 66,102,132,165,193,214,
  20, 38, 66,102,132,165,193,214
};
U8 a2600_tia_secam_pal[8]={
  0,9,12,13,10,11,14,15
};
U8 a2600_tia_secam_r[8]={
  0,33,240,255,127,127,255,255
};
U8 a2600_tia_secam_g[8]={
  0,33,60,60,255,255,255,255
};
U8 a2600_tia_secam_b[8]={
  0,255,121,255,0,255,63,255
};
U8 a2600_tos_r[16]={
  0,0,0,0,170,170,170,170,85,85,85,85,255,255,255,255
};
U8 a2600_tos_g[16]={
  0,0,170,170,0,0,85,170,85,85,255,255,85,85,255,255
};
U8 a2600_tos_b[16]={
  0,170,0,170,0,170,0,170,85,255,85,255,85,255,85,255
};
U8 a2600_phosphor_color[A2600_TIA_COLOR_COUNT*A2600_TIA_COLOR_COUNT];
I64 a2600_phosphor_ready=0;
I64 a2600_wd_seg0_tab[8]={0,0,4,7,0,0,2,6};
I64 a2600_wd_seg1_tab[8]={0,1,5,4,0,1,3,0};
I64 a2600_wd_seg2_tab[8]={1,2,6,2,6,7,4,5};
I64 a2600_wd_seg3_tab[8]={3,3,7,3,7,6,5,1};

I64 a2600_a,a2600_x,a2600_y,a2600_sp,a2600_pc,a2600_p;
I64 a2600_cycles,a2600_frames,a2600_visible_y,a2600_visible_active,
    a2600_scanline;
I64 a2600_frame_scanline,a2600_last_frame_scanlines;
I64 a2600_frame_state,a2600_frame_line_state,a2600_frame_vsync_lines;
I64 a2600_wsync_pending,a2600_wsync_target;
I64 a2600_cpu_bus_active,a2600_cpu_bus_cycle;
I64 a2600_access_cycle_active,a2600_access_cycle;
I64 a2600_last_pc,a2600_last_op,a2600_steps,a2600_vblank,a2600_halt_reason;
I64 a2600_bus;
I64 a2600_timer_expire,a2600_timer_div,a2600_timer_irq,a2600_timer_next_irq;
I64 a2600_pa7_edge_positive,a2600_pa7_irq,a2600_pa7_sync1,a2600_pa7_last;
I64 a2600_swach_dir,a2600_swbch_dir,a2600_cart_size,a2600_bank,a2600_cart_type;
I64 a2600_cart_crc,a2600_display_phosphor,a2600_tv_format;
I64 a2600_power_rng,a2600_power_reset_count;
I64 a2600_cart_seg0,a2600_cart_seg1,a2600_cart_seg2,a2600_cart_seg3;
I64 a2600_cart_ram_bank,a2600_cart_ram_mode;
I64 a2600_gl_has_init_ram,a2600_gl_prom;
I64 a2600_mdm_disabled,a2600_tvboy_disabled;
I64 a2600_fa2_flash_busy,a2600_fa2_flash_done_cycle;
I64 a2600_wd_pending,a2600_wd_pending_cycle;
I64 a2600_fe_last;
I64 a2600_4a50_slice_low,a2600_4a50_slice_mid,a2600_4a50_slice_high;
I64 a2600_4a50_rom_low,a2600_4a50_rom_mid,a2600_4a50_rom_high;
I64 a2600_4a50_last_data,a2600_4a50_last_addr;
I64 a2600_dpc_flags[8],a2600_dpc_counters[8],a2600_dpc_top[8],
    a2600_dpc_bottom[8],a2600_dpc_enable[8],a2600_dpc_music_top[8],
    a2600_dpc_music_bottom[8],a2600_dpc_music_count[8],
    a2600_dpc_audio_cycle;
F64 a2600_dpc_fractional_clocks;
I64 a2600_dpc_sreg,a2600_dpc_audv;
I64 a2600_audio_ona,a2600_audio_chan;
F64 a2600_audio_freq;
I64 a2600_audio_d6[2],a2600_audio_p4[2],a2600_audio_p5[2],
    a2600_audio_p9[2],a2600_audio_out[2],a2600_audio_div_cnt[2],
    a2600_audio_div_max[2],a2600_audio_sample,a2600_audio_next_cycle;
I64 a2600_audio_counter,a2600_audio_clock_enable[2],
    a2600_audio_noise_feedback[2],a2600_audio_noise_bit4[2],
    a2600_audio_pulse_hold[2],a2600_audio_div_counter[2],
    a2600_audio_pulse_counter[2],a2600_audio_noise_counter[2],
    a2600_audio_sum0,a2600_audio_sum1,a2600_audio_sum_ct;
I64 a2600_sc_slice0,a2600_sc_slice1,a2600_sc_control,a2600_sc_start;
I64 a2600_sc_prev_addr,a2600_sc_ram_byte,a2600_sc_addr_count,a2600_sc_write_enable;
I64 a2600_line_x,a2600_tia_cycle,a2600_hmove_blank_x,a2600_hmove_blank_next,
      a2600_hmove_cycle;
I64 a2600_p0_x,a2600_p1_x,a2600_m0_x,a2600_m1_x,a2600_bl_x;
I64 a2600_p0_motion,a2600_p1_motion,a2600_m0_motion,a2600_m1_motion,a2600_bl_motion;
I64 a2600_p_dyn_render[2],a2600_p_dyn_counter[2],a2600_p_dyn_trip[2],
    a2600_p_dyn_sample[2],a2600_p_dyn_divider[2],a2600_p_dyn_pending[2],
    a2600_p_dyn_change[2];
I64 a2600_m_dyn_mask[2],a2600_m_dyn_ended[2],
    a2600_m_hmove_active[2];
I64 a2600_bl_hmove_active;
I64 a2600_bl_dyn_alive;
I64 a2600_m0_confused,a2600_cosmic_scanline,a2600_m0_cosmic_graphics;
I64 a2600_grp0_old,a2600_grp1_old,a2600_enabl_old;
I64 a2600_pf0_pending,a2600_pf1_pending,a2600_pf2_pending;
I64 a2600_pf0_pending_x,a2600_pf1_pending_x,a2600_pf2_pending_x;
I64 a2600_pf0_pending_val,a2600_pf1_pending_val,a2600_pf2_pending_val;
I64 a2600_pf_reflect_latch,a2600_pf_reflect_mid_latched;
I64 a2600_swcha,a2600_swchb,a2600_swchb_base,a2600_swcha_out,a2600_swchb_out;
I64 a2600_fire0,a2600_fire1,a2600_auto_reset;
I64 a2600_inpt_latch_mode,a2600_inpt4_latch,a2600_inpt5_latch;
I64 a2600_analog_dump,a2600_analog_charge_start,a2600_quadtari_dump_cycle;
I64 a2600_paddle_pos[4],a2600_paddle_charge[4],a2600_paddle_mode;
I64 a2600_drive0_count,a2600_drive1_count;
I64 a2600_trakball_st_v[4]={0x00,0x10,0x30,0x20};
I64 a2600_trakball_st_h[4]={0x00,0x80,0xC0,0x40};
I64 a2600_trakball_am_v[4]={0x00,0x80,0xA0,0x20};
I64 a2600_trakball_am_h[4]={0x00,0x10,0x50,0x40};
I64 a2600_trakball_tb_v[4]={0x00,0x10,0x20,0x30};
I64 a2600_trakball_tb_h[4]={0x40,0x00,0xC0,0x80};
I64 a2600_trakball_mode,a2600_trakball_port,a2600_trakball_both;
I64 a2600_trakball_count_h,a2600_trakball_count_v;
I64 a2600_trakball_pending_h,a2600_trakball_pending_v;
I64 a2600_trakball_lines_h,a2600_trakball_lines_v;
I64 a2600_trakball_scan_h,a2600_trakball_scan_v;
I64 a2600_trakball_left,a2600_trakball_down;
I64 a2600_lightgun_mode,a2600_lightgun_port,a2600_lightgun_x,a2600_lightgun_y;
I64 a2600_lightgun_cycle,a2600_lightgun_line,a2600_lightgun_wrap;
I64 a2600_lightgun_adjust,a2600_lightgun_vadjust;
I64 a2600_left_controller,a2600_right_controller;
I64 a2600_controller_lightgun_adjust,a2600_controller_lightgun_vadjust;
I64 a2600_controller_lightgun_wrap;
I64 a2600_mindlink_pos[2],a2600_mindlink_shift[2],a2600_mindlink_pins;
I64 a2600_kidvid_id,a2600_kidvid_tape,a2600_kidvid_idx;
I64 a2600_kidvid_block,a2600_kidvid_block_idx,a2600_kidvid_pins;
I64 a2600_kidvid_delay;
I64 a2600_compumate_swcha,a2600_compumate_column;
I64 a2600_compumate_key_decay[40],a2600_compumate_func_decay,a2600_compumate_shift_decay;
I64 a2600_compumate_cas_size,a2600_compumate_cas_loaded;
I64 a2600_compumate_cas_playing,a2600_compumate_cas_start_cycle;
I64 a2600_compumate_save_active,a2600_compumate_save_t0;
I64 a2600_compumate_save_last_toggle,a2600_compumate_save_expected_size;
I64 a2600_compumate_save_byte_pos,a2600_compumate_save_in_header;
I64 a2600_compumate_save_ok_count,a2600_compumate_save_fail_count;
I64 a2600_compumate_save_calibrated,a2600_compumate_save_seen_signal;
I64 a2600_compumate_save_bit_trans[A2600_CM_CAS_FRAME_BITS];
F64 a2600_compumate_save_cycles_per_bit;
I64 a2600_joy0_mask,a2600_joy0_decay,a2600_joy1_mask,a2600_joy1_decay;
I64 a2600_joy0_up_decay,a2600_joy0_down_decay,a2600_joy0_left_decay,a2600_joy0_right_decay;
I64 a2600_joy1_up_decay,a2600_joy1_down_decay,a2600_joy1_left_decay,a2600_joy1_right_decay;
I64 a2600_fire0_decay,a2600_fire1_decay;
I64 a2600_trigger0_decay,a2600_booster0_decay;
I64 a2600_trigger1_decay,a2600_booster1_decay;
I64 a2600_reset_decay,a2600_select_decay;
I64 a2600_quit_requested;
I64 a2600_savekey_active,a2600_savekey_loaded,a2600_savekey_dirty;
I64 a2600_savekey_state,a2600_savekey_mdat,a2600_savekey_sdat;
I64 a2600_savekey_mclk,a2600_savekey_addr_known,a2600_savekey_pptr;
I64 a2600_savekey_nb,a2600_savekey_addr,a2600_savekey_timer_until;
I64 a2600_atarivox_shift_count,a2600_atarivox_shift_reg;
I64 a2600_atarivox_last_write_cycle,a2600_atarivox_last_byte;
I64 a2600_atarivox_byte_count,a2600_atarivox_bad_start;
I64 a2600_atarivox_bad_stop;
Bool a2600_halted=FALSE,a2600_ready=FALSE,a2600_frame_done=FALSE;
Bool a2600_vsync_frame_mode=FALSE;
Bool a2600_ext_cart=FALSE,a2600_cart_super=FALSE;
I64 a2600_last_run_jiffy=-1;

I64 A2600AccessCycle()
{
  if (a2600_access_cycle_active)
    return a2600_access_cycle;
  return a2600_cycles;
}

U0 A2600ClearFB()
{
  I64 i;
  for (i=0;i<A2600_FB_W*A2600_FB_H;i++) {
    a2600_fb[i]=0;
    a2600_prev_fb[i]=0;
  }
}

U0 A2600SetZN(I64 v)
{
  I64 vv;
  vv=v & 0xFF;
  if (vv) {
    a2600_p=a2600_p & (0xFF - A2600_F_Z);
  } else {
    a2600_p=a2600_p | A2600_F_Z;
  }
  if (vv & 0x80) {
    a2600_p=a2600_p | A2600_F_N;
  } else {
    a2600_p=a2600_p & (0xFF - A2600_F_N);
  }
}

U0 A2600Cmp(I64 lhs,I64 rhs)
{
  I64 d;
  d=(lhs&0xFF)-(rhs&0xFF);
  if (d>=0)
    a2600_p=a2600_p | A2600_F_C;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_C);
  A2600SetZN(d&0xFF);
}

U0 A2600ADC(I64 v)
{
  I64 old,sum,carry,lo,hi,res;

  old=a2600_a&0xFF;
  v=v&0xFF;
  carry=a2600_p&A2600_F_C;
  sum=old+v+carry;

  if (a2600_p&A2600_F_D) {
    lo=(old&0x0F)+(v&0x0F)+carry;
    hi=(old>>4)+(v>>4);
    if (lo>9)
      lo=lo+6;
    if (lo>0x0F)
      hi++;
    res=(hi<<4)|(lo&0x0F);
    if (((res^old)&(v^res)&0x80))
      a2600_p=a2600_p | A2600_F_V;
    else
      a2600_p=a2600_p & (0xFF - A2600_F_V);
    if (hi>9)
      hi=hi+6;
    if (hi>0x0F)
      a2600_p=a2600_p | A2600_F_C;
    else
      a2600_p=a2600_p & (0xFF - A2600_F_C);
    a2600_a=((hi<<4)|(lo&0x0F))&0xFF;
    A2600SetZN(sum&0xFF);
    return;
  }

  if (sum>0xFF)
    a2600_p=a2600_p | A2600_F_C;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_C);

  if (((old^sum)&(v^sum)&0x80))
    a2600_p=a2600_p | A2600_F_V;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_V);

  a2600_a=sum&0xFF;
  A2600SetZN(a2600_a);
}

U0 A2600SBC(I64 v)
{
  I64 old,sum,carry,lo,hi;

  old=a2600_a&0xFF;
  v=v&0xFF;
  carry=a2600_p&A2600_F_C;

  if (!(a2600_p&A2600_F_D)) {
    A2600ADC((v^0xFF)&0xFF);
    return;
  }

  sum=old+(v^0xFF)+carry;
  if (((sum^old)&((v^0xFF)^sum)&0x80))
    a2600_p=a2600_p | A2600_F_V;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_V);
  if (sum>0xFF)
    a2600_p=a2600_p | A2600_F_C;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_C);

  lo=(old&0x0F)-(v&0x0F)-(1-carry);
  hi=(old>>4)-(v>>4)-((lo&0x10)>>4);
  if (lo&0x10)
    lo=lo-6;
  if (hi&0x10)
    hi=hi-6;
  a2600_a=((hi<<4)|(lo&0x0F))&0xFF;
  A2600SetZN(sum&0xFF);
}

I64 A2600Bus(I64 v)
{
  a2600_bus=v&0xFF;
  return a2600_bus;
}

I64 A2600Cart2KBanks()
{
  I64 banks;
  banks=a2600_cart_size>>11;
  if (banks<1)
    banks=1;
  return banks;
}

U0 A2600DPCInit()
{
  I64 i;

  for (i=0;i<8;i++) {
    a2600_dpc_flags[i]=0;
    a2600_dpc_counters[i]=0;
    a2600_dpc_top[i]=0;
    a2600_dpc_bottom[i]=0;
    a2600_dpc_enable[i]=0;
    a2600_dpc_music_top[i]=0;
    a2600_dpc_music_bottom[i]=0;
    a2600_dpc_music_count[i]=0;
  }
  a2600_dpc_sreg=1;
  a2600_dpc_audv=0;
  a2600_dpc_audio_cycle=A2600AccessCycle();
  a2600_dpc_fractional_clocks=0.0;
}

I64 A2600DPCTune(I64 v)
{
  return (v&0xFF)*129/79;
}

U0 A2600DPCUpdateAUDV()
{
  I64 mix;

  mix=(a2600_dpc_flags[5]&1) | (a2600_dpc_flags[6]&2) |
        (a2600_dpc_flags[7]&4);
  a2600_dpc_audv=a2600_dpc_mix_audv[mix&7]&0x0F;
}

U0 A2600DPCClockMusic()
{
  I64 cycles,whole,ch,top,low;
  F64 clocks;

  cycles=A2600AccessCycle()-a2600_dpc_audio_cycle;
  if (cycles<0)
    cycles=0;
  a2600_dpc_audio_cycle=A2600AccessCycle();
  clocks=ToF64(cycles)*20000.0/1193191.66666667+
        a2600_dpc_fractional_clocks;
  whole=clocks;
  a2600_dpc_fractional_clocks=clocks-ToF64(whole);
  if (whole<=0)
    return;

  for (ch=5;ch<8;ch++) {
    if (a2600_dpc_enable[ch]&0x10) {
      top=(a2600_dpc_top[ch]&0xFF)+1;
      low=a2600_dpc_counters[ch]&0xFF;
      if (a2600_dpc_top[ch]&0xFF) {
        low-=whole%top;
        if (low<0)
          low+=top;
      } else
        low=0;

      if (low<=a2600_dpc_bottom[ch])
        a2600_dpc_flags[ch]=0;
      else if (low<=a2600_dpc_top[ch])
        a2600_dpc_flags[ch]=0xFF;
      a2600_dpc_counters[ch]=(a2600_dpc_counters[ch]&0x700)+(low&0xFF);
      a2600_dpc_music_count[ch]=low&0xFF;
    }
  }
}

U0 A2600DPCClockPitfall2()
{
  A2600DPCClockMusic;
  A2600DPCUpdateAUDV;
}

U0 A2600DPCClockRandom()
{
  a2600_dpc_sreg=((((((a2600_dpc_sreg&0x80)>>7)^
        ((a2600_dpc_sreg&0x20)>>5))^
        (((a2600_dpc_sreg&0x10)>>4)^
        ((a2600_dpc_sreg&0x08)>>3)))^1) |
        (a2600_dpc_sreg<<1))&0xFF;
}

I64 A2600DPCReadRandom()
{
  return A2600Bus(a2600_dpc_sreg);
}

I64 A2600DPCReadDF(I64 ch,Bool use_flag)
{
  I64 idx,v;

  ch=ch&7;
  if ((a2600_dpc_counters[ch]&0xFF)==a2600_dpc_top[ch])
    a2600_dpc_flags[ch]=0xFF;
  if ((a2600_dpc_counters[ch]&0xFF)==a2600_dpc_bottom[ch])
    a2600_dpc_flags[ch]=0;

  idx=0x27FF-(a2600_dpc_counters[ch]&0x7FF);
  if (idx>=0 && idx<a2600_cart_size)
    v=a2600_rom[idx];
  else
    v=0xFF;
  if (ch<5 || !(a2600_dpc_enable[ch]&0x10))
    a2600_dpc_counters[ch]=(a2600_dpc_counters[ch]-1)&0x7FF;
  if (use_flag)
    v=v&a2600_dpc_flags[ch];
  return A2600Bus(v);
}

I64 A2600DPCRead(I64 off)
{
  I64 r;

  A2600DPCClockRandom;
  r=off&0x3F;
  if (r<4)
    return A2600DPCReadRandom();
  if (r<8) {
    if (r>=4)
      A2600DPCClockPitfall2;
    return A2600Bus(a2600_dpc_audv);
  }
  if (r<0x10)
    return A2600DPCReadDF(r&7,FALSE);
  if (r<0x18)
    return A2600DPCReadDF(r&7,TRUE);
  if (r>=0x38)
    return A2600Bus(a2600_dpc_flags[r&7]);
  return A2600Bus(0);
}

U0 A2600DPCWrite(I64 off,I64 val)
{
  I64 r,ch;

  r=off&0x3F;
  ch=r&7;
  val=val&0xFF;
  A2600DPCClockRandom;
  if (r<8) {
    a2600_dpc_top[ch]=val;
    a2600_dpc_flags[ch]=0;
    if (ch>4)
      a2600_dpc_music_top[ch]=A2600DPCTune(val);
    return;
  }
  if (r<0x10) {
    a2600_dpc_bottom[ch]=val;
    if (ch>4)
      a2600_dpc_music_bottom[ch]=A2600DPCTune(val);
    return;
  }
  if (r<0x18) {
    if (ch>4 && (a2600_dpc_enable[ch]&0x10)) {
      a2600_dpc_counters[ch]=(a2600_dpc_counters[ch]&0x700)+
            a2600_dpc_top[ch];
      a2600_dpc_music_count[ch]=a2600_dpc_music_top[ch];
    } else {
      a2600_dpc_counters[ch]=(a2600_dpc_counters[ch]&0x700)+val;
      if (ch>4)
        a2600_dpc_music_count[ch]=A2600DPCTune(val);
    }
    return;
  }
  if (r<0x20) {
    a2600_dpc_counters[ch]=((a2600_dpc_counters[ch]&0xFF)+(val<<8))&0x7FF;
    a2600_dpc_enable[ch]=val;
    return;
  }
  if (r>=0x30 && r<0x38)
    a2600_dpc_sreg=1;
}

U0 A2600SCSetScheme()
{
  I64 s;

  a2600_sc_write_enable=a2600_sc_control&0x02;
  s=(a2600_sc_control&0x1C)>>2;
  switch (s) {
    case 0:
    case 4:
      a2600_sc_slice0=0x1000;
      a2600_sc_slice1=0x1800;
      break;
    case 1:
      a2600_sc_slice0=0x0000;
      a2600_sc_slice1=0x1800;
      break;
    case 2:
      a2600_sc_slice0=0x1000;
      a2600_sc_slice1=0x0000;
      break;
    case 3:
      a2600_sc_slice0=0x0000;
      a2600_sc_slice1=0x1000;
      break;
    case 5:
      a2600_sc_slice0=0x0800;
      a2600_sc_slice1=0x1800;
      break;
    case 6:
      a2600_sc_slice0=0x1000;
      a2600_sc_slice1=0x0800;
      break;
    case 7:
      a2600_sc_slice0=0x0800;
      a2600_sc_slice1=0x1000;
      break;
  }
}

Bool A2600SCLoadIndex(I64 load)
{
  I64 base,pagecount,i,j,pagebyte,pageadr;

  if (a2600_cart_size==6144) {
    for (i=0;i<0x1800;i++)
      a2600_cart_ram[i]=a2600_rom[i];
    a2600_sc_start=a2600_rom[0x17FC]+(a2600_rom[0x17FD]<<8);
    a2600_sc_control=0x0D;
    A2600SCSetScheme;
    return TRUE;
  }

  base=load*A2600_STARPATH_LOAD_SIZE;
  if (base+0x2100>a2600_cart_size)
    return FALSE;

  pagecount=a2600_rom[base+0x2003]&0xFF;
  if (pagecount>32)
    pagecount=32;
  for (i=0;i<pagecount;i++) {
    pagebyte=a2600_rom[base+0x2010+i]&0xFF;
    pageadr=((pagebyte&3)*0x800)+(((pagebyte&0x1F)>>2)*256);
    if (pageadr+256<=0x1800) {
      for (j=0;j<256;j++)
        a2600_cart_ram[pageadr+j]=a2600_rom[base+(i*256)+j];
    }
  }

  a2600_sc_start=a2600_rom[base+0x2000]+(a2600_rom[base+0x2001]<<8);
  a2600_sc_control=a2600_rom[base+0x2002];
  A2600SCSetScheme;
  return a2600_sc_start!=0;
}

Bool A2600SCLoadNumber(I64 num)
{
  I64 i,loads,found;

  if (a2600_cart_size==6144)
    return A2600SCLoadIndex(0);

  loads=a2600_cart_size/A2600_STARPATH_LOAD_SIZE;
  found=-1;
  for (i=1;i<loads;i++) {
    if (a2600_rom[(i*A2600_STARPATH_LOAD_SIZE)+0x2005]==(num&0xFF))
      found=i;
  }
  if (found<0)
    return FALSE;
  return A2600SCLoadIndex(found);
}

U0 A2600SCInit()
{
  I64 i;

  a2600_sc_slice0=0x1000;
  a2600_sc_slice1=0x1800;
  a2600_sc_control=0;
  a2600_sc_start=0;
  a2600_sc_prev_addr=0;
  a2600_sc_ram_byte=0;
  a2600_sc_addr_count=7;
  a2600_sc_write_enable=0;
  for (i=0;i<0x1800;i++)
    a2600_cart_ram[i]=0x52;
  A2600SCLoadIndex(0);
  a2600_ram[0]=a2600_sc_control|0x40;
}

U0 A2600SCObserveAddr(I64 a)
{
  I64 hot,slice,idx;

  if (a2600_cart_type!=A2600_CART_AR)
    return;

  hot=a&0x1FFF;
  if (a2600_sc_addr_count<=5) {
    if (hot!=a2600_sc_prev_addr) {
      a2600_sc_prev_addr=hot;
      a2600_sc_addr_count++;
    }
    if (hot==0x1FF8) {
      a2600_sc_control=a2600_sc_ram_byte;
      A2600SCSetScheme;
      a2600_sc_addr_count=7;
    } else if (a2600_sc_addr_count==5 && (hot&0x1000) && a2600_sc_write_enable) {
      if (hot&0x0800)
        slice=a2600_sc_slice1;
      else
        slice=a2600_sc_slice0;
      if (slice<0x1800) {
        idx=slice+(hot&0x07FF);
        a2600_cart_ram[idx]=a2600_sc_ram_byte&0xFF;
      }
      a2600_sc_addr_count=7;
    }
  } else if (hot&0x1000) {
    if (!(hot&0x0F00)) {
      a2600_sc_ram_byte=hot&0xFF;
      a2600_sc_addr_count=0;
      a2600_sc_prev_addr=hot;
    } else if (hot==0x1FF8) {
      a2600_sc_control=a2600_sc_ram_byte;
      A2600SCSetScheme;
      a2600_sc_addr_count=7;
    }
  }
}

Bool A2600SCJAM()
{
  I64 hot;

  if (a2600_cart_type!=A2600_CART_AR)
    return FALSE;

  hot=a2600_last_pc&0x1FFF;
  if (hot==0x1FF0) {
    a2600_sc_control=a2600_ram[0x7A];
    if (!A2600SCLoadNumber(a2600_sc_control))
      return FALSE;
    a2600_pc=a2600_sc_start;
    a2600_ram[0]=a2600_sc_control|0x40;
    a2600_sc_addr_count=7;
    a2600_cycles+=2;
    return TRUE;
  }
  if (hot==0x1FF1) {
    if (!A2600SCLoadIndex(0))
      return FALSE;
    a2600_pc=a2600_sc_start;
    a2600_ram[0]=a2600_sc_control|0x40;
    a2600_sc_addr_count=7;
    a2600_cycles+=2;
    return TRUE;
  }
  return FALSE;
}

U0 A2600WDSetBank(I64 bank)
{
  bank=bank&7;
  a2600_bank=bank;
  a2600_cart_seg0=a2600_wd_seg0_tab[bank];
  a2600_cart_seg1=a2600_wd_seg1_tab[bank];
  a2600_cart_seg2=a2600_wd_seg2_tab[bank];
  a2600_cart_seg3=a2600_wd_seg3_tab[bank];
}

I64 A2600Cart1KBanks()
{
  I64 banks;

  banks=a2600_cart_size>>10;
  if (banks<1)
    banks=1;
  return banks;
}

I64 A2600Cart3EPGetSeg(I64 seg)
{
  if (seg==0)
    return a2600_cart_seg0;
  if (seg==1)
    return a2600_cart_seg1;
  if (seg==2)
    return a2600_cart_seg2;
  return a2600_cart_seg3;
}

U0 A2600Cart3EPSetSeg(I64 seg,I64 val)
{
  if (seg==0)
    a2600_cart_seg0=val;
  else if (seg==1)
    a2600_cart_seg1=val;
  else if (seg==2)
    a2600_cart_seg2=val;
  else
    a2600_cart_seg3=val;
}

U0 A2600Cart3EPHot(I64 a,I64 val)
{
  I64 seg,banks1;

  if (a!=0x3E && a!=0x3F)
    return;

  seg=(val>>6)&3;
  if (a==0x3F) {
    banks1=A2600Cart1KBanks();
    A2600Cart3EPSetSeg(seg,(val&0x3F)%banks1);
  } else
    A2600Cart3EPSetSeg(seg,A2600Cart1KBanks()+(val&0x3F));
}

I64 A2600Cart3EXRamBanks()
{
  I64 banks,max;

  banks=(a2600_rom[a2600_cart_size-6]&0xFF)+1;
  if (banks<1)
    banks=1;
  max=A2600_CART_RAM_SIZE>>10;
  if (banks>max)
    banks=max;
  return banks;
}

U0 A2600CartResetBanks()
{
  I64 banks2,i;

  banks2=A2600Cart2KBanks;
  a2600_cart_seg0=0;
  a2600_cart_seg1=0;
  a2600_cart_seg2=0;
  a2600_cart_seg3=0;
  a2600_cart_ram_bank=0;
  a2600_cart_ram_mode=0;
  a2600_fe_last=0;
  a2600_4a50_slice_low=0;
  a2600_4a50_slice_mid=0;
  a2600_4a50_slice_high=0;
  a2600_4a50_rom_low=TRUE;
  a2600_4a50_rom_mid=TRUE;
  a2600_4a50_rom_high=TRUE;
  a2600_4a50_last_data=0xFF;
  a2600_4a50_last_addr=0xFFFF;
  a2600_mdm_disabled=FALSE;
  a2600_tvboy_disabled=FALSE;
  a2600_fa2_flash_busy=FALSE;
  a2600_fa2_flash_done_cycle=0;
  a2600_compumate_swcha=0xFF;
  a2600_compumate_column=0;
  for (i=0;i<40;i++)
    a2600_compumate_key_decay[i]=0;
  a2600_compumate_func_decay=0;
  a2600_compumate_shift_decay=0;
  a2600_compumate_cas_playing=FALSE;
  A2600DPCInit;
  if (a2600_cart_type==A2600_CART_AR) {
    A2600SCInit;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_CM) {
    a2600_bank=3;
    return;
  }

  if (a2600_cart_type==A2600_CART_E0 ||
        a2600_cart_type==A2600_CART_03E0) {
    a2600_cart_seg0=4;
    a2600_cart_seg1=5;
    a2600_cart_seg2=6;
    a2600_cart_seg3=7;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_3F ||
        a2600_cart_type==A2600_CART_3E ||
        a2600_cart_type==A2600_CART_3EX) {
    a2600_cart_seg0=0;
    a2600_cart_seg1=banks2-1;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_3EP) {
    a2600_cart_seg0=0;
    a2600_cart_seg1=0;
    a2600_cart_seg2=0;
    a2600_cart_seg3=0;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_E7) {
    a2600_cart_seg0=0;
    a2600_cart_seg1=banks2-1;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_FA) {
    a2600_bank=2;
    return;
  }

  if (a2600_cart_type==A2600_CART_FA2) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_FE) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_DPC) {
    a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_FC) {
    a2600_cart_seg0=0;
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_CV) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_0840) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_0FA0) {
    a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_SB) {
    a2600_bank=(a2600_cart_size/A2600_BANK_SIZE)-1;
    return;
  }

  if (a2600_cart_type==A2600_CART_JANE) {
    a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_X07) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_GL) {
    a2600_cart_seg0=0;
    a2600_cart_seg1=0;
    a2600_cart_seg2=0;
    a2600_cart_seg3=0;
    a2600_bank=0;
    a2600_gl_prom=FALSE;
    return;
  }

  if (a2600_cart_type==A2600_CART_4A50) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_MDM) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_TVBOY) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_UA ||
        a2600_cart_type==A2600_CART_UASW) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_WD ||
        a2600_cart_type==A2600_CART_WDSW) {
    a2600_wd_pending=0xF0;
    a2600_wd_pending_cycle=0;
    A2600WDSetBank(0);
    return;
  }

  if (a2600_cart_type==A2600_CART_WF8) {
    a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_EF) {
    if (a2600_cart_super)
      a2600_bank=15;
    else
      a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_F0) {
    a2600_bank=15;
    return;
  }

  if (a2600_cart_type==A2600_CART_DF) {
    a2600_bank=15;
    return;
  }

  if (a2600_cart_type==A2600_CART_BF) {
    if (a2600_cart_super)
      a2600_bank=15;
    else
      a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_STD && a2600_cart_size==8192)
    a2600_bank=1;
  else
    a2600_bank=0;
}

U0 A2600MZHot(I64 a)
{
  I64 hot;

  if (a2600_cart_type!=A2600_CART_0FA0)
    return;

  hot=(a&0x0FFF)&0x16E0;
  if (hot==0x06A0)
    a2600_bank=0;
  else if (hot==0x06C0)
    a2600_bank=1;
}

U0 A2600MZTEHot(I64 a)
{
  I64 off,b;

  if (a2600_cart_type!=A2600_CART_03E0)
    return;

  if (a&0x1000)
    return;

  off=a&0x0FFF;
  if (off<0x0380 || off>0x03FF)
    return;

  b=off&7;
  if (!(off&0x10))
    a2600_cart_seg0=b;
  if (!(off&0x20))
    a2600_cart_seg1=b;
  if (!(off&0x40))
    a2600_cart_seg2=b;
}

U0 A2600UAHot(I64 a)
{
  I64 hot;

  if (a2600_cart_type!=A2600_CART_UA && a2600_cart_type!=A2600_CART_UASW)
    return;

  hot=a&0x1260;
  if (hot==0x0220) {
    if (a2600_cart_type==A2600_CART_UASW)
      a2600_bank=1;
    else
      a2600_bank=0;
  } else if (hot==0x0240) {
    if (a2600_cart_type==A2600_CART_UASW)
      a2600_bank=0;
    else
      a2600_bank=1;
  }
}

U0 A2600CartHot(I64 a)
{
  I64 hot,off,banks2,b;
  hot=a&0x1FFF;
  off=hot&0x0FFF;

  if (a2600_cart_type==A2600_CART_E0) {
    if (hot>=0x1FE0 && hot<=0x1FE7)
      a2600_cart_seg0=hot&7;
    else if (hot>=0x1FE8 && hot<=0x1FEF)
      a2600_cart_seg1=hot&7;
    else if (hot>=0x1FF0 && hot<=0x1FF7)
      a2600_cart_seg2=hot&7;
    return;
  }

  if (a2600_cart_type==A2600_CART_E7) {
    banks2=A2600Cart2KBanks;
    if (banks2==4) {
      if (off>=0x0FE4 && off<=0x0FE7)
        a2600_cart_seg0=off&3;
    } else if (banks2==6) {
      if (off>=0x0FE0 && off<=0x0FE7) {
        b=off&7;
        if (b<2)
          a2600_cart_seg0=b;
        else if (b<4)
          a2600_cart_seg0=b-2;
        else
          a2600_cart_seg0=b-2;
      }
    } else if (banks2>=8) {
      if (off>=0x0FE0 && off<=0x0FE7)
        a2600_cart_seg0=off&7;
    }
    if (off>=0x0FE8 && off<=0x0FEB)
      a2600_cart_ram_bank=off&3;
    return;
  }

  if (a2600_cart_type==A2600_CART_FA) {
    if (hot>=0x1FF8 && hot<=0x1FFA)
      a2600_bank=hot-0x1FF8;
    return;
  }

  if (a2600_cart_type==A2600_CART_FA2) {
    if (hot>=0x1FF5 && hot<=0x1FFB)
      a2600_bank=hot-0x1FF5;
    return;
  }

  if (a2600_cart_type==A2600_CART_DPC) {
    if (hot==0x1FF8)
      a2600_bank=0;
    else if (hot==0x1FF9)
      a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_FC) {
    banks2=a2600_cart_size/A2600_BANK_SIZE;
    if (banks2<1)
      banks2=1;
    if (off==0x0FFC)
      a2600_bank=a2600_cart_seg0%banks2;
    return;
  }

  if (a2600_cart_type==A2600_CART_0FA0) {
    A2600MZHot(a);
    return;
  }

  if (a2600_cart_type==A2600_CART_03E0) {
    A2600MZTEHot(a);
    return;
  }

  if (a2600_cart_type==A2600_CART_UA ||
        a2600_cart_type==A2600_CART_UASW) {
    A2600UAHot(a);
    return;
  }

  if (a2600_cart_type==A2600_CART_WF8) {
    if (hot==0x1FF8)
      a2600_bank=0;
    return;
  }

  if (a2600_cart_type==A2600_CART_EF) {
    if (hot>=0x1FE0 && hot<=0x1FEF)
      a2600_bank=hot&0x0F;
    return;
  }

  if (a2600_cart_type==A2600_CART_DF) {
    if (hot>=0x1FC0 && hot<=0x1FDF)
      a2600_bank=hot&0x1F;
    return;
  }

  if (a2600_cart_type==A2600_CART_BF) {
    if (hot>=0x1F80 && hot<=0x1FBF)
      a2600_bank=hot&0x3F;
    return;
  }

  if (a2600_cart_type==A2600_CART_0840) {
    if ((hot&0x1840)==0x0800)
      a2600_bank=0;
    else if ((hot&0x1840)==0x0840)
      a2600_bank=1;
    return;
  }

  if (a2600_cart_type==A2600_CART_F0) {
    if (hot==0x1FF0)
      a2600_bank=(a2600_bank+1)&0x0F;
    return;
  }

  if (a2600_cart_type==A2600_CART_JANE) {
    if (hot==0x1FF0)
      a2600_bank=0;
    else if (hot==0x1FF1)
      a2600_bank=1;
    else if (hot==0x1FF8)
      a2600_bank=2;
    else if (hot==0x1FF9)
      a2600_bank=3;
    return;
  }

  if (a2600_cart_type!=A2600_CART_STD)
    return;

  if (a2600_cart_size==8192) {
    if (hot==0x1FF8)
      a2600_bank=0;
    else if (hot==0x1FF9)
      a2600_bank=1;
  }
  if (a2600_cart_size==16384) {
    if (hot>=0x1FF6 && hot<=0x1FF9)
      a2600_bank=hot-0x1FF6;
  }
  if (a2600_cart_size==32768) {
    if (hot>=0x1FF4 && hot<=0x1FFB)
      a2600_bank=hot-0x1FF4;
  }
}

U0 A2600SBHot(I64 a)
{
  I64 hot,banks;

  if (a2600_cart_type!=A2600_CART_SB)
    return;

  banks=a2600_cart_size/A2600_BANK_SIZE;
  if (banks<1)
    return;

  hot=a&0x1FFF;
  if ((hot&0x1800)==0x0800)
    a2600_bank=hot&(banks-1);
}

U0 A2600MDMHot(I64 a)
{
  I64 hot,banks,bank;

  if (a2600_cart_type!=A2600_CART_MDM || a2600_mdm_disabled)
    return;

  banks=a2600_cart_size/A2600_BANK_SIZE;
  if (banks<1)
    return;

  hot=a&0x1FFF;
  if ((hot&0x1C00)==0x0800) {
    bank=hot&0x00FF;
    a2600_bank=bank%banks;
    if (bank>127)
      a2600_mdm_disabled=TRUE;
  }
}

U0 A2600TVBoyHot(I64 a)
{
  I64 hot,banks,bank;

  if (a2600_cart_type!=A2600_CART_TVBOY || a2600_tvboy_disabled)
    return;

  banks=a2600_cart_size/A2600_BANK_SIZE;
  if (banks<1)
    return;

  hot=a&0x1FFF;
  if (hot>=0x1800 && hot<=0x187F) {
    bank=hot&(banks-1);
    if (a2600_bank!=bank) {
      a2600_bank=bank;
      if (bank)
        a2600_tvboy_disabled=TRUE;
    }
  }
}

U0 A2600X07Hot(I64 a)
{
  I64 hot;

  if (a2600_cart_type!=A2600_CART_X07)
    return;

  hot=a&0x1FFF;
  if ((hot&0x180F)==0x080D)
    a2600_bank=(hot&0x00F0)>>4;
  else if ((hot&0x1880)==0) {
    if ((a2600_bank&0x0E)==0x0E)
      a2600_bank=((hot&0x0040)>>6)|0x0E;
  }
}

I64 A2600GLGetSeg(I64 seg)
{
  if (seg==0)
    return a2600_cart_seg0;
  if (seg==1)
    return a2600_cart_seg1;
  if (seg==2)
    return a2600_cart_seg2;
  return a2600_cart_seg3;
}

U0 A2600GLSetSeg(I64 seg,I64 bank)
{
  bank=bank&0x0F;
  if (seg==0)
    a2600_cart_seg0=bank;
  else if (seg==1)
    a2600_cart_seg1=bank;
  else if (seg==2)
    a2600_cart_seg2=bank;
  else
    a2600_cart_seg3=bank;
}

I64 A2600GLPage(I64 a)
{
  return a&0x1F80;
}

Bool A2600GLIsLowPage(I64 a)
{
  I64 page;

  if (a2600_cart_type!=A2600_CART_GL)
    return FALSE;
  if (a>=0x1000)
    return FALSE;

  page=A2600GLPage(a);
  return page==0x0480 || page==0x0580 || page==0x0680 ||
        page==0x0880 || page==0x0980 || page==0x0C80 ||
        page==0x0D80;
}

U0 A2600GLHot(I64 a)
{
  I64 page;

  if (a2600_cart_type!=A2600_CART_GL)
    return;

  page=A2600GLPage(a);
  if (page==0x0480)
    A2600GLSetSeg(0,a);
  else if (page==0x0580)
    A2600GLSetSeg(1,a);
  else if (page==0x0880)
    A2600GLSetSeg(2,a);
  else if (page==0x0980)
    A2600GLSetSeg(3,a);
  else if (page==0x0C80)
    a2600_gl_prom=(a&0x30)==0x30;
}

I64 A2600GLReadLow(I64 a)
{
  A2600GLHot(a);
  return A2600Bus(a2600_bus);
}

U0 A26004A50BankROMLow(I64 value)
{
  a2600_4a50_rom_low=TRUE;
  a2600_4a50_slice_low=(value&0x1F)<<11;
}

U0 A26004A50BankRAMLow(I64 value)
{
  a2600_4a50_rom_low=FALSE;
  a2600_4a50_slice_low=(value&0x0F)<<11;
}

U0 A26004A50BankROMMid(I64 value)
{
  a2600_4a50_rom_mid=TRUE;
  a2600_4a50_slice_mid=(value&0x1F)<<11;
}

U0 A26004A50BankRAMMid(I64 value)
{
  a2600_4a50_rom_mid=FALSE;
  a2600_4a50_slice_mid=(value&0x0F)<<11;
}

U0 A26004A50BankROMHigh(I64 value)
{
  a2600_4a50_rom_high=TRUE;
  a2600_4a50_slice_high=(value&0xFF)<<8;
}

U0 A26004A50BankRAMHigh(I64 value)
{
  a2600_4a50_rom_high=FALSE;
  a2600_4a50_slice_high=(value&0x7F)<<8;
}

U0 A26004A50Access(I64 a,I64 value)
{
  I64 addr;

  if (a2600_cart_type!=A2600_CART_4A50)
    return;

  addr=a&0x1FFF;
  if ((addr&0x1F00)==0x1F00) {
    if ((a2600_4a50_last_data&0xE0)==0x60)
      if (a2600_4a50_last_addr>=0x1000 || a2600_4a50_last_addr<0x0200)
        a2600_4a50_slice_high=(a2600_4a50_slice_high&0xF0FF)|
              ((addr&0x0008)<<8)|((addr&0x0070)<<4);
  }

  if (addr<0x1000) {
    if ((a2600_4a50_last_data&0xE0)==0x60)
      if (a2600_4a50_last_addr>=0x1000 || a2600_4a50_last_addr<0x0200) {
        if ((addr&0x0F00)==0x0C00)
          A26004A50BankROMHigh(addr&0xFF);
        else if ((addr&0x0F00)==0x0D00)
          A26004A50BankRAMHigh(addr&0x7F);
        else if ((addr&0x0F40)==0x0E00)
          A26004A50BankROMLow(addr&0x1F);
        else if ((addr&0x0F40)==0x0E40)
          A26004A50BankRAMLow(addr&0x0F);
        else if ((addr&0x0F40)==0x0F00)
          A26004A50BankROMMid(addr&0x1F);
        else if ((addr&0x0F50)==0x0F40)
          A26004A50BankRAMMid(addr&0x0F);
        else if ((addr&0x0F00)==0x0400)
          a2600_4a50_slice_low=a2600_4a50_slice_low^0x0800;
        else if ((addr&0x0F00)==0x0500)
          a2600_4a50_slice_low=a2600_4a50_slice_low^0x1000;
        else if ((addr&0x0F00)==0x0800)
          a2600_4a50_slice_mid=a2600_4a50_slice_mid^0x0800;
        else if ((addr&0x0F00)==0x0900)
          a2600_4a50_slice_mid=a2600_4a50_slice_mid^0x1000;
      }

    if ((addr&0x0F75)==0x0074)
      A26004A50BankROMHigh(value);
    else if ((addr&0x0F75)==0x0075)
      A26004A50BankRAMHigh(value&0x7F);
    else if ((addr&0x0F7C)==0x0078) {
      if ((value&0xF0)==0x00)
        A26004A50BankROMLow(value&0x0F);
      else if ((value&0xF0)==0x40)
        A26004A50BankRAMLow(value&0x0F);
      else if ((value&0xF0)==0x90)
        A26004A50BankROMMid((value&0x0F)|0x10);
      else if ((value&0xF0)==0xC0)
        A26004A50BankRAMMid(value&0x0F);
    }
  }

  a2600_4a50_last_data=value&0xFF;
  a2600_4a50_last_addr=addr;
}

I64 A2600WDCycle()
{
  return A2600AccessCycle();
}

U0 A2600WDMaybeSwitch()
{
  I64 cycle;

  if (a2600_cart_type!=A2600_CART_WD &&
        a2600_cart_type!=A2600_CART_WDSW)
    return;
  if (a2600_wd_pending==0xF0)
    return;

  cycle=A2600WDCycle();
  if (cycle>a2600_wd_pending_cycle+3) {
    A2600WDSetBank(a2600_wd_pending);
    a2600_wd_pending=0xF0;
  }
}

U0 A2600WDReadHot(I64 a)
{
  I64 hot;

  if (a2600_cart_type!=A2600_CART_WD &&
        a2600_cart_type!=A2600_CART_WDSW)
    return;
  if (a&0x1000)
    return;

  hot=a&0xFF;
  if (hot>=0x30 && hot<=0x3F) {
    a2600_wd_pending=hot&0x0F;
    a2600_wd_pending_cycle=A2600AccessCycle();
  }
}

U0 A2600FEAccess(I64 a,I64 val)
{
  I64 bank,banks;

  if (a2600_cart_type!=A2600_CART_FE)
    return;

  if (a2600_fe_last) {
    banks=a2600_cart_size/A2600_BANK_SIZE;
    if (banks<1)
      banks=1;
    bank=((val>>5)^7)&7;
    a2600_bank=bank%banks;
    a2600_fe_last=0;
    return;
  }

  a2600_fe_last=(a==0x01FE);
}

Bool A2600FindSig2(U8 *data,I64 size,I64 a,I64 b)
{
  I64 i;

  if (size<2)
    return FALSE;
  for (i=0;i<=size-2;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        return TRUE;
  }
  return FALSE;
}

I64 A2600CountSig2(U8 *data,I64 size,I64 a,I64 b)
{
  I64 i,cnt;

  cnt=0;
  if (size<2)
    return 0;
  for (i=0;i<=size-2;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        cnt++;
  }
  return cnt;
}

I64 A2600CountSig3(U8 *data,I64 size,I64 a,I64 b,I64 c)
{
  I64 i,cnt;

  cnt=0;
  if (size<3)
    return 0;
  for (i=0;i<=size-3;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        if (data[i+2]==c)
          cnt++;
  }
  return cnt;
}

I64 A2600CountSig4(U8 *data,I64 size,I64 a,I64 b,I64 c,I64 d)
{
  I64 i,cnt;

  cnt=0;
  if (size<4)
    return 0;
  for (i=0;i<=size-4;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        if (data[i+2]==c)
          if (data[i+3]==d)
            cnt++;
  }
  return cnt;
}

Bool A2600FindSig3(U8 *data,I64 size,I64 a,I64 b,I64 c)
{
  I64 i;

  if (size<3)
    return FALSE;
  for (i=0;i<=size-3;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        if (data[i+2]==c)
          return TRUE;
  }
  return FALSE;
}

Bool A2600FindSig5(U8 *data,I64 size,I64 a,I64 b,I64 c,I64 d,I64 e)
{
  I64 i;

  if (size<5)
    return FALSE;
  for (i=0;i<=size-5;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        if (data[i+2]==c)
          if (data[i+3]==d)
            if (data[i+4]==e)
              return TRUE;
  }
  return FALSE;
}

Bool A2600FindSig6(U8 *data,I64 size,I64 a,I64 b,I64 c,I64 d,I64 e,I64 f)
{
  I64 i;

  if (size<6)
    return FALSE;
  for (i=0;i<=size-6;i++) {
    if (data[i]==a)
      if (data[i+1]==b)
        if (data[i+2]==c)
          if (data[i+3]==d)
            if (data[i+4]==e)
              if (data[i+5]==f)
                return TRUE;
  }
  return FALSE;
}

Bool A2600DetectSuperCart(U8 *data,I64 size)
{
  I64 bank,i;

  if (size==4096) {
    for (i=1;i<256;i++) {
      if (data[i]!=data[0])
        return FALSE;
    }
    if (data[size-6]==0x53)
      if (data[size-5]==0x43)
        return TRUE;
    return FALSE;
  }

  if (size!=8192 && size!=16384 && size!=32768)
    return FALSE;

  // z26 carries these 16K SC signatures for carts like Dig Dug and Off the Wall.
  if (size==16384) {
    if (A2600FindSig5(data,size,0xA2,0x7F,0x9D,0x00,0xF0))
      return TRUE;
    if (A2600FindSig5(data,size,0xAE,0xF6,0xFF,0x4C,0x00))
      return TRUE;
  }

  // Stella SC heuristic: each 4K bank repeats the write and read RAM windows.
  for (bank=0;bank<size;bank+=A2600_BANK_SIZE) {
    for (i=0;i<A2600_SARA_SIZE;i++) {
      if (data[bank+i]!=data[bank+A2600_SARA_SIZE+i])
        return FALSE;
    }
  }
  return TRUE;
}

Bool A2600TailSig4(U8 *data,I64 size,I64 a,I64 b,I64 c,I64 d)
{
  if (size<8)
    return FALSE;

  return data[size-8]==a && data[size-7]==b &&
        data[size-6]==c && data[size-5]==d;
}

Bool A2600DetectE0(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600FindSig3(data,size,0x8D,0xE0,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xE0,0x5F)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xE9,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0xE0,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE0,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE9,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xED,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xF3,0xBF)) return TRUE;
  return FALSE;
}

Bool A2600Detect3F(U8 *data,I64 size)
{
  if (size<8192)
    return FALSE;
  return A2600CountSig2(data,size,0x85,0x3F)>=2;
}

Bool A2600Detect3E(U8 *data,I64 size)
{
  if (size<8192)
    return FALSE;
  if (!A2600FindSig2(data,size,0x85,0x3E))
    return FALSE;
  return A2600CountSig2(data,size,0x85,0x3F)>=2;
}

Bool A2600Detect3EPlus(U8 *data,I64 size)
{
  return A2600CountSig4(data,size,0x54,0x4A,0x33,0x45)>0; // "TJ3E"
}

Bool A2600Detect3EX(U8 *data,I64 size)
{
  if (size<8192)
    return FALSE;
  return A2600CountSig3(data,size,0x33,0x45,0x58)>=2; // "3EX"
}

Bool A2600DetectJANE(U8 *data,I64 size)
{
  if (size!=16384)
    return FALSE;
  return A2600CountSig4(data,size,0xAD,0xF1,0xFF,0x60)>0;
}

Bool A2600DetectX07(U8 *data,I64 size)
{
  if (size!=65536)
    return FALSE;

  if (A2600FindSig3(data,size,0xAD,0x0D,0x08)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0x1D,0x08)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0x2D,0x08)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0x0D,0x08)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0x1D,0x08)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0x2D,0x08)) return TRUE;
  return FALSE;
}

Bool A2600DetectGL(U8 *data,I64 size)
{
  if (size!=4096 && size!=6144)
    return FALSE;

  return A2600FindSig3(data,size,0xAD,0xB8,0x0C);
}

Bool A2600Detect4A50(U8 *data,I64 size)
{
  I64 vec;

  if (size!=32768 && size!=65536 && size!=131072)
    return FALSE;
  if (data[size-6]==0x50 && data[size-5]==0x4A)
    return TRUE;
  if (size>=65536) {
    if ((data[0xFFFD]&0x1F)==0x1F) {
      vec=(data[0xFFFD]<<8)+data[0xFFFC];
      if (vec+2<size)
        if (data[vec]==0x0C)
          if ((data[vec+2]&0xFE)==0x6E)
            return TRUE;
    }
  }
  return FALSE;
}

Bool A2600DetectE7(U8 *data,I64 size)
{
  if (size!=8192)
    if (size!=12288)
      if (size!=16384)
        return FALSE;

  if (A2600FindSig3(data,size,0xAD,0xE2,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE5,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE5,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE7,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0xE7,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xE7,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xE7,0x1F)) return TRUE;
  return FALSE;
}

Bool A2600DetectFE(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600FindSig5(data,size,0x20,0x00,0xD0,0xC6,0xC5)) return TRUE;
  if (A2600FindSig5(data,size,0x20,0xC3,0xF8,0xA5,0x82)) return TRUE;
  if (A2600FindSig5(data,size,0xD0,0xFB,0x20,0x73,0xFE)) return TRUE;
  if (A2600FindSig5(data,size,0xD0,0xFB,0x20,0x68,0xFE)) return TRUE;
  if (A2600FindSig5(data,size,0x20,0x00,0xF0,0x84,0xD6)) return TRUE;
  return FALSE;
}

Bool A2600Detect0840(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600CountSig3(data,size,0xAD,0x00,0x08)>=2) return TRUE;
  if (A2600CountSig3(data,size,0xAD,0x40,0x08)>=2) return TRUE;
  if (A2600CountSig3(data,size,0x2C,0x00,0x08)>=2) return TRUE;
  if (A2600CountSig4(data,size,0x0C,0x00,0x08,0x4C)>=2) return TRUE;
  if (A2600CountSig4(data,size,0x0C,0xFF,0x0F,0x4C)>=2) return TRUE;
  return FALSE;
}

Bool A2600Detect0FA0(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600FindSig3(data,size,0x2C,0xC0,0x0F)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xC0,0x0F)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xC0,0x0F)) return TRUE;
  if (A2600FindSig3(data,size,0x2C,0xC0,0xEF)) return TRUE;
  return FALSE;
}

Bool A2600Detect03E0(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600CountSig4(data,size,0x0D,0xE0,0x03,0x0D)) return TRUE;
  if (A2600CountSig4(data,size,0xAD,0xE0,0x03,0xAD)) return TRUE;
  return FALSE;
}

Bool A2600DetectUA(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600FindSig3(data,size,0x8D,0x40,0x02)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0x40,0x02)) return TRUE;
  if (A2600FindSig3(data,size,0xBD,0x1F,0x02)) return TRUE;
  if (A2600FindSig3(data,size,0x2C,0xC0,0x02)) return TRUE;
  if (A2600FindSig3(data,size,0x8D,0xC0,0x02)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xC0,0x02)) return TRUE;
  return FALSE;
}

Bool A2600DetectUASW(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  if (A2600CountSig4(data,size,0x55,0x41,0x53,0x57)>0)
    return TRUE;
  return FALSE;
}

Bool A2600DetectWD(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  return A2600FindSig3(data,size,0xA5,0x39,0x4C);
}

Bool A2600DetectWF8(U8 *data,I64 size)
{
  if (size!=8192)
    return FALSE;

  return A2600TailSig4(data,size,0x57,0x46,0x38,0x21); // "WF8!"
}

Bool A2600DetectFC(U8 *data,I64 size)
{
  if (size!=4096 && size!=8192 && size!=16384 && size!=32768)
    return FALSE;

  if (A2600FindSig6(data,size,0x8D,0xF8,0x1F,0x4A,0x4A,0x8D)) return TRUE;
  if (A2600FindSig6(data,size,0x8D,0xF8,0xFF,0x8D,0xFC,0xFF)) return TRUE;
  if (A2600FindSig6(data,size,0x8C,0xF9,0xFF,0xAD,0xFC,0xFF)) return TRUE;
  return FALSE;
}

Bool A2600DetectCV(U8 *data,I64 size)
{
  if (size!=2048 && size!=4096)
    return FALSE;

  if (A2600FindSig3(data,size,0x9D,0xFF,0xF3)) return TRUE;
  if (A2600FindSig3(data,size,0x99,0x00,0xF4)) return TRUE;
  return FALSE;
}

Bool A2600DetectEF(U8 *data,I64 size)
{
  if (size!=65536)
    return FALSE;

  if (A2600TailSig4(data,size,0x45,0x46,0x45,0x46)) return TRUE;
  if (A2600TailSig4(data,size,0x45,0x46,0x53,0x43)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0xE0,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE0,0xFF)) return TRUE;
  if (A2600FindSig3(data,size,0x0C,0xE0,0x1F)) return TRUE;
  if (A2600FindSig3(data,size,0xAD,0xE0,0x1F)) return TRUE;
  return FALSE;
}

Bool A2600DetectEFSC(U8 *data,I64 size)
{
  if (size!=65536)
    return FALSE;

  if (A2600TailSig4(data,size,0x45,0x46,0x53,0x43))
    return TRUE;
  if (A2600TailSig4(data,size,0x45,0x46,0x45,0x46))
    return FALSE;
  if (!A2600DetectEF(data,size))
    return FALSE;
  return A2600DetectSuperCart(data,size);
}

Bool A2600DetectDF(U8 *data,I64 size)
{
  if (size!=131072)
    return FALSE;

  if (A2600TailSig4(data,size,0x44,0x46,0x44,0x46)) return TRUE;
  if (A2600TailSig4(data,size,0x44,0x46,0x53,0x43)) return TRUE;
  return FALSE;
}

Bool A2600DetectDFSC(U8 *data,I64 size)
{
  if (size!=131072)
    return FALSE;

  return A2600TailSig4(data,size,0x44,0x46,0x53,0x43);
}

Bool A2600DetectBF(U8 *data,I64 size)
{
  if (size!=262144)
    return FALSE;

  if (A2600TailSig4(data,size,0x42,0x46,0x42,0x46)) return TRUE;
  if (A2600TailSig4(data,size,0x42,0x46,0x53,0x43)) return TRUE;
  return FALSE;
}

Bool A2600DetectBFSC(U8 *data,I64 size)
{
  if (size!=262144)
    return FALSE;

  return A2600TailSig4(data,size,0x42,0x46,0x53,0x43);
}

Bool A2600DetectMDM(U8 *data,I64 size)
{
  I64 limit;

  limit=size;
  if (limit>8192)
    limit=8192;
  return A2600CountSig4(data,limit,0x4D,0x44,0x4D,0x43)>0; // "MDMC"
}

Bool A2600DetectTVBoy(U8 *data,I64 size)
{
  if (size!=524288)
    return FALSE;

  return A2600FindSig5(data,size,0x91,0x82,0x6C,0xFC,0xFF);
}

Bool A2600DetectFA2(U8 *data,I64 size)
{
  I64 i;

  if (size==24576 || size==A2600_FA2_SIZE || size==29696)
    return TRUE;

  if (size==32768) {
    for (i=29696;i<32768;i++)
      if (data[i])
        return FALSE;
    return TRUE;
  }
  return FALSE;
}

Bool A2600DetectCM(U8 *data,I64 size)
{
  I64 i,j;
  Bool ok;
  U8 *needle;

  if (size!=16384)
    return FALSE;
  needle="COMPUMATE";
  for (i=0;i<=size-9;i++) {
    ok=TRUE;
    for (j=0;j<9;j++) {
      if (data[i+j]!=needle[j]) {
        ok=FALSE;
        break;
      }
    }
    if (ok)
      return TRUE;
  }
  return FALSE;
}

I64 A2600DetectCartType(U8 *data,I64 size)
{
  if (A2600DetectCM(data,size)) return A2600_CART_CM;

  if (A2600DetectCV(data,size)) return A2600_CART_CV;

  if (A2600DetectGL(data,size)) return A2600_CART_GL;

  if (A2600DetectMDM(data,size)) return A2600_CART_MDM;

  if (A2600DetectTVBoy(data,size)) return A2600_CART_TVBOY;

  if (size==6144 || (size>=A2600_STARPATH_LOAD_SIZE && size%A2600_STARPATH_LOAD_SIZE==0))
    return A2600_CART_AR;

  if (size==10240 || size==10495)
    return A2600_CART_DPC;

  if (size==8195)
    return A2600_CART_WDSW;

  if (size==8192) {
    if (A2600Detect3EPlus(data,size)) return A2600_CART_3EP;
    if (A2600Detect3EX(data,size)) return A2600_CART_3EX;
    if (A2600DetectUASW(data,size)) return A2600_CART_UASW;
    if (A2600DetectWF8(data,size)) return A2600_CART_WF8;
    if (A2600DetectFE(data,size)) return A2600_CART_FE;
    if (A2600Detect0840(data,size)) return A2600_CART_0840;
    if (A2600DetectE0(data,size)) return A2600_CART_E0;
    if (A2600Detect3E(data,size)) return A2600_CART_3E;
    if (A2600Detect3F(data,size)) return A2600_CART_3F;
    if (A2600DetectUA(data,size)) return A2600_CART_UA;
    if (A2600DetectWD(data,size)) return A2600_CART_WD;
    if (A2600Detect0FA0(data,size)) return A2600_CART_0FA0;
    if (A2600DetectE7(data,size)) return A2600_CART_E7;
    if (A2600DetectFC(data,size)) return A2600_CART_FC;
    if (A2600Detect03E0(data,size)) return A2600_CART_03E0;
  }

  if (size==12288) {
    if (A2600DetectE7(data,size)) return A2600_CART_E7;
    return A2600_CART_FA;
  }

  if (size==24576 || size==A2600_FA2_SIZE || size==29696) {
    if (A2600DetectFA2(data,size)) return A2600_CART_FA2;
  }

  if (size==16384) {
    if (A2600DetectE7(data,size)) return A2600_CART_E7;
    if (A2600DetectJANE(data,size)) return A2600_CART_JANE;
    if (A2600Detect3EX(data,size)) return A2600_CART_3EX;
    if (A2600Detect3E(data,size)) return A2600_CART_3E;
    if (A2600Detect3F(data,size)) return A2600_CART_3F;
  }

  if (size==32768) {
    if (A2600Detect4A50(data,size)) return A2600_CART_4A50;
    if (A2600DetectFA2(data,size)) return A2600_CART_FA2;
    if (A2600DetectFC(data,size)) return A2600_CART_FC;
    if (A2600Detect3EX(data,size)) return A2600_CART_3EX;
    if (A2600Detect3E(data,size)) return A2600_CART_3E;
    if (A2600Detect3F(data,size)) return A2600_CART_3F;
  }

  if (size==A2600_F0_SIZE)
    if (A2600Detect4A50(data,size)) return A2600_CART_4A50;

  if (size==A2600_F0_SIZE)
    if (A2600DetectEF(data,size)) return A2600_CART_EF;

  if (size==A2600_F0_SIZE)
    if (A2600DetectX07(data,size)) return A2600_CART_X07;

  if (size==A2600_F0_SIZE)
    return A2600_CART_F0;

  if (size==131072)
    if (A2600Detect4A50(data,size)) return A2600_CART_4A50;

  if (size==131072)
    if (A2600DetectDF(data,size)) return A2600_CART_DF;

  if (size==131072)
    return A2600_CART_SB;

  if (size==262144)
    if (A2600DetectBF(data,size)) return A2600_CART_BF;

  if (size==262144)
    return A2600_CART_SB;

  return A2600_CART_STD;
}

I64 A2600FA2FlashAccess()
{
  I64 i,now,op,val;

  now=A2600AccessCycle();
  val=a2600_rom[(a2600_bank*A2600_BANK_SIZE)+0x0FF4]&0xFF;

  if (!a2600_fa2_flash_busy) {
    op=a2600_cart_ram[255]&0xFF;
    if (op==1) {
      for (i=0;i<256;i++)
        a2600_cart_ram[i]=a2600_fa2_flash[i];
      a2600_fa2_flash_done_cycle=now+A2600_FA2_READ_DELAY_CYCLES;
    } else if (op==2) {
      for (i=0;i<256;i++)
        a2600_fa2_flash[i]=a2600_cart_ram[i];
      a2600_fa2_flash_done_cycle=now+A2600_FA2_WRITE_DELAY_CYCLES;
    } else
      a2600_fa2_flash_done_cycle=now;
    a2600_fa2_flash_busy=TRUE;
    return A2600Bus(val|0x40);
  }

  if (now>=a2600_fa2_flash_done_cycle) {
    a2600_fa2_flash_busy=FALSE;
    a2600_cart_ram[255]=0;
    return A2600Bus(val&~0x40);
  }

  return A2600Bus(val|0x40);
}

I64 A26004A50ReadCart(I64 a)
{
  I64 addr,val,idx;

  addr=a&0x1FFF;
  if ((addr&0x1800)==0x1000) {
    idx=(addr&0x07FF)+a2600_4a50_slice_low;
    if (a2600_4a50_rom_low)
      val=a2600_rom[idx&0x1FFFF];
    else
      val=a2600_cart_ram[idx&0x7FFF];
  } else if (addr>=0x1800 && addr<=0x1DFF) {
    idx=(addr&0x07FF)+a2600_4a50_slice_mid;
    if (a2600_4a50_rom_mid)
      val=a2600_rom[(0x10000+idx)&0x1FFFF];
    else
      val=a2600_cart_ram[idx&0x7FFF];
  } else if ((addr&0x1F00)==0x1E00) {
    idx=(addr&0x00FF)+a2600_4a50_slice_high;
    if (a2600_4a50_rom_high)
      val=a2600_rom[(0x10000+idx)&0x1FFFF];
    else
      val=a2600_cart_ram[idx&0x7FFF];
  } else
    val=a2600_rom[0x1FF00+(addr&0x00FF)];

  A26004A50Access(a,val);
  return A2600Bus(val);
}

U0 A26004A50WriteCart(I64 a,I64 val)
{
  I64 addr,idx;

  addr=a&0x1FFF;
  if ((addr&0x1800)==0x1000) {
    if (!a2600_4a50_rom_low) {
      idx=(addr&0x07FF)+a2600_4a50_slice_low;
      a2600_cart_ram[idx&0x7FFF]=val&0xFF;
    }
  } else if (addr>=0x1800 && addr<=0x1DFF) {
    if (!a2600_4a50_rom_mid) {
      idx=(addr&0x07FF)+a2600_4a50_slice_mid;
      a2600_cart_ram[idx&0x7FFF]=val&0xFF;
    }
  } else if ((addr&0x1F00)==0x1E00) {
    if (!a2600_4a50_rom_high) {
      idx=(addr&0x00FF)+a2600_4a50_slice_high;
      a2600_cart_ram[idx&0x7FFF]=val&0xFF;
    }
  }
  A26004A50Access(a,val);
}

I64 A2600ReadCart(I64 a)
{
  I64 off,banks2,banks1,idx,seg,segval,sub;

  A2600WDMaybeSwitch;
  A2600CartHot(a);
  off=a&0x0FFF;

  if (a2600_cart_type==A2600_CART_4A50)
    return A26004A50ReadCart(a);

  if (a2600_cart_type==A2600_CART_CM) {
    if (off<0x0800)
      return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
    if (a2600_compumate_swcha&0x10)
      return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
    return A2600Bus(a2600_cart_ram[off&0x07FF]);
  }

  if (a2600_cart_type==A2600_CART_AR) {
    if (off&0x0800)
      idx=a2600_sc_slice1+(off&0x07FF);
    else
      idx=a2600_sc_slice0+(off&0x07FF);
    if (idx<0x1800)
      return A2600Bus(a2600_cart_ram[idx]);
    return A2600Bus(0x52);
  }

  if (a2600_cart_type==A2600_CART_DPC) {
    if (off<0x0040)
      return A2600DPCRead(off);
    if (off<0x0080) {
      A2600DPCClockRandom;
      return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
    }
    A2600DPCClockRandom;
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_GL) {
    if (a2600_gl_prom && off>=0x0FC0 && off<=0x0FDF)
      return A2600Bus(0);
    seg=(off>>10)&3;
    segval=A2600GLGetSeg(seg);
    sub=off&0x03FF;
    if (segval>=4)
      return A2600Bus(a2600_cart_ram[(((segval-4)%12)<<10)+sub]);
    return A2600Bus(a2600_rom[((segval&3)<<10)+sub]);
  }

  if (a2600_cart_type==A2600_CART_WD ||
        a2600_cart_type==A2600_CART_WDSW) {
    if (off<0x0040)
      return A2600Bus(a2600_cart_ram[off]);
    if (off<0x0080) {
      a2600_cart_ram[off&0x3F]=a2600_bus&0xFF;
      return A2600Bus(a2600_bus);
    }
    if (off<0x0400)
      return A2600Bus(a2600_rom[((a2600_cart_seg0&7)<<10)+off]);
    if (off<0x0800)
      return A2600Bus(a2600_rom[((a2600_cart_seg1&7)<<10)+(off&0x03FF)]);
    if (off<0x0C00)
      return A2600Bus(a2600_rom[((a2600_cart_seg2&7)<<10)+(off&0x03FF)]);
    return A2600Bus(a2600_rom[((a2600_cart_seg3&7)<<10)+(off&0x03FF)]);
  }

  if (a2600_cart_type==A2600_CART_E0) {
    if (off<0x0400)
      return A2600Bus(a2600_rom[(a2600_cart_seg0<<10)+off]);
    if (off<0x0800)
      return A2600Bus(a2600_rom[(a2600_cart_seg1<<10)+(off&0x03FF)]);
    if (off<0x0C00)
      return A2600Bus(a2600_rom[(a2600_cart_seg2<<10)+(off&0x03FF)]);
    return A2600Bus(a2600_rom[(a2600_cart_seg3<<10)+(off&0x03FF)]);
  }

  if (a2600_cart_type==A2600_CART_3F) {
    banks2=A2600Cart2KBanks;
    if (off<0x0800)
      return A2600Bus(a2600_rom[((a2600_cart_seg0%banks2)<<11)+off]);
    return A2600Bus(a2600_rom[((a2600_cart_seg1%banks2)<<11)+(off&0x07FF)]);
  }

  if (a2600_cart_type==A2600_CART_3E) {
    banks2=A2600Cart2KBanks;
    if (off<0x0800) {
      if (a2600_cart_ram_mode) {
        idx=((a2600_cart_seg0&31)<<10)+(off&0x03FF);
        if (off>=0x0400) {
          a2600_cart_ram[idx]=a2600_bus&0xFF;
          return a2600_bus&0xFF;
        }
        return A2600Bus(a2600_cart_ram[idx]);
      }
      return A2600Bus(a2600_rom[((a2600_cart_seg0%banks2)<<11)+off]);
    }
    return A2600Bus(a2600_rom[((a2600_cart_seg1%banks2)<<11)+(off&0x07FF)]);
  }

  if (a2600_cart_type==A2600_CART_3EX) {
    banks2=A2600Cart2KBanks;
    if (off<0x0800) {
      if (a2600_cart_ram_mode) {
        idx=((a2600_cart_seg0%A2600Cart3EXRamBanks())<<10)+(off&0x03FF);
        if (off>=0x0400) {
          a2600_cart_ram[idx]=a2600_bus&0xFF;
          return A2600Bus(a2600_bus);
        }
        return A2600Bus(a2600_cart_ram[idx]);
      }
      return A2600Bus(a2600_rom[((a2600_cart_seg0%banks2)<<11)+off]);
    }
    return A2600Bus(a2600_rom[((a2600_cart_seg1%banks2)<<11)+(off&0x07FF)]);
  }

  if (a2600_cart_type==A2600_CART_3EP) {
    banks1=A2600Cart1KBanks();
    seg=(off>>10)&3;
    segval=A2600Cart3EPGetSeg(seg);
    sub=off&0x03FF;
    if (segval>=banks1) {
      idx=((segval-banks1)&0x3F)<<9;
      if (sub>=0x0200) {
        a2600_cart_ram[idx+(sub&0x01FF)]=a2600_bus&0xFF;
        return A2600Bus(a2600_bus);
      }
      return A2600Bus(a2600_cart_ram[idx+sub]);
    }
    return A2600Bus(a2600_rom[((segval%banks1)<<10)+sub]);
  }

  if (a2600_cart_type==A2600_CART_E7) {
    banks2=A2600Cart2KBanks;
    if (off<0x0800) {
      if (a2600_cart_seg0==banks2-1) {
        idx=off&0x03FF;
        if (off<0x0400) {
          a2600_cart_ram[idx]=a2600_bus&0xFF;
          return a2600_bus&0xFF;
        }
        return A2600Bus(a2600_cart_ram[idx]);
      }
      return A2600Bus(a2600_rom[((a2600_cart_seg0%banks2)<<11)+off]);
    }
    if (off>=0x0800) {
      if (off<0x0900) {
        idx=0x0400+((a2600_cart_ram_bank&3)<<8)+(off&0x00FF);
        a2600_cart_ram[idx]=a2600_bus&0xFF;
        return a2600_bus&0xFF;
      }
      if (off<0x0A00) {
        idx=0x0400+((a2600_cart_ram_bank&3)<<8)+(off&0x00FF);
        return A2600Bus(a2600_cart_ram[idx]);
      }
    }
    return A2600Bus(a2600_rom[((a2600_cart_seg1%banks2)<<11)+(off&0x07FF)]);
  }

  if (a2600_cart_type==A2600_CART_03E0) {
    if (off<0x0400)
      return A2600Bus(a2600_rom[((a2600_cart_seg0&7)<<10)+off]);
    if (off<0x0800)
      return A2600Bus(a2600_rom[((a2600_cart_seg1&7)<<10)+(off&0x03FF)]);
    if (off<0x0C00)
      return A2600Bus(a2600_rom[((a2600_cart_seg2&7)<<10)+(off&0x03FF)]);
    return A2600Bus(a2600_rom[((a2600_cart_seg3&7)<<10)+(off&0x03FF)]);
  }

  if (a2600_cart_type==A2600_CART_FA) {
    if (off<0x0100) {
      a2600_cart_ram[off]=a2600_bus&0xFF;
      return a2600_bus&0xFF;
    }
    if (off<0x0200)
      return A2600Bus(a2600_cart_ram[off-0x0100]);
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_FA2) {
    if (off==0x0FF4)
      return A2600FA2FlashAccess();
    if (off<0x0100) {
      a2600_cart_ram[off]=a2600_bus&0xFF;
      return a2600_bus&0xFF;
    }
    if (off<0x0200)
      return A2600Bus(a2600_cart_ram[off-0x0100]);
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_FE)
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_FC) {
    banks2=a2600_cart_size/A2600_BANK_SIZE;
    if (banks2<1)
      banks2=1;
    return A2600Bus(a2600_rom[((a2600_bank%banks2)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_MDM) {
    banks2=a2600_cart_size/A2600_BANK_SIZE;
    if (banks2<1)
      banks2=1;
    return A2600Bus(a2600_rom[((a2600_bank%banks2)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_TVBOY) {
    banks2=a2600_cart_size/A2600_BANK_SIZE;
    if (banks2<1)
      banks2=1;
    return A2600Bus(a2600_rom[((a2600_bank%banks2)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_CV) {
    if (off<0x0400)
      return A2600Bus(a2600_cart_ram[off]);
    if (off<0x0800) {
      a2600_cart_ram[off&0x03FF]=a2600_bus&0xFF;
      return A2600Bus(a2600_bus);
    }
    return A2600Bus(a2600_rom[off]);
  }

  if (a2600_cart_type==A2600_CART_0840)
    return A2600Bus(a2600_rom[((a2600_bank&1)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_0FA0)
    return A2600Bus(a2600_rom[((a2600_bank&1)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_UA ||
        a2600_cart_type==A2600_CART_UASW)
    return A2600Bus(a2600_rom[((a2600_bank&1)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_WF8)
    return A2600Bus(a2600_rom[((a2600_bank&1)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_JANE)
    return A2600Bus(a2600_rom[((a2600_bank&3)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_SB)
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_X07)
    return A2600Bus(a2600_rom[((a2600_bank&15)*A2600_BANK_SIZE)+off]);

  if (a2600_cart_type==A2600_CART_EF) {
    if (a2600_cart_super) {
      if (off<A2600_SARA_SIZE) {
        a2600_sara[off]=a2600_bus&0xFF;
        return a2600_bus&0xFF;
      }
      if (off<A2600_SARA_SIZE*2)
        return A2600Bus(a2600_sara[off-A2600_SARA_SIZE]);
    }
    return A2600Bus(a2600_rom[((a2600_bank&15)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_DF) {
    if (a2600_cart_super) {
      if (off<A2600_SARA_SIZE) {
        a2600_sara[off]=a2600_bus&0xFF;
        return a2600_bus&0xFF;
      }
      if (off<A2600_SARA_SIZE*2)
        return A2600Bus(a2600_sara[off-A2600_SARA_SIZE]);
    }
    return A2600Bus(a2600_rom[((a2600_bank&31)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_type==A2600_CART_BF) {
    if (a2600_cart_super) {
      if (off<A2600_SARA_SIZE) {
        a2600_sara[off]=a2600_bus&0xFF;
        return a2600_bus&0xFF;
      }
      if (off<A2600_SARA_SIZE*2)
        return A2600Bus(a2600_sara[off-A2600_SARA_SIZE]);
    }
    return A2600Bus(a2600_rom[((a2600_bank&63)*A2600_BANK_SIZE)+off]);
  }

  if (a2600_cart_super) {
    if (off<A2600_SARA_SIZE) {
      a2600_sara[off]=a2600_bus&0xFF;
      return a2600_bus&0xFF;
    }
    if (off<A2600_SARA_SIZE*2)
      return A2600Bus(a2600_sara[off-A2600_SARA_SIZE]);
  }
  if (a2600_cart_size>=8192)
    return A2600Bus(a2600_rom[(a2600_bank*A2600_BANK_SIZE)+off]);
  return A2600Bus(a2600_rom[off]);
}

U0 A2600WriteCart(I64 a,I64 val)
{
  I64 off,banks2,banks1,idx,b,seg,segval,sub;

  A2600WDMaybeSwitch;
  A2600CartHot(a);
  off=a&0x0FFF;

  if (a2600_cart_type==A2600_CART_4A50) {
    A26004A50WriteCart(a,val);
    return;
  }

  if (a2600_cart_type==A2600_CART_CM) {
    if (off>=0x0800 && (a2600_compumate_swcha&0x30)==0x20)
      a2600_cart_ram[off&0x07FF]=val&0xFF;
    return;
  }

  if (a2600_cart_type==A2600_CART_AR)
    return;

  if (a2600_cart_type==A2600_CART_DPC) {
    if (off<0x0040) {
      A2600DPCRead(off);
      return;
    }
    if (off<0x0080)
      A2600DPCWrite(off,val);
    else
      A2600DPCClockRandom;
    return;
  }

  if (a2600_cart_type==A2600_CART_GL) {
    seg=(off>>10)&3;
    segval=A2600GLGetSeg(seg);
    if (segval>=4) {
      sub=off&0x03FF;
      a2600_cart_ram[(((segval-4)%12)<<10)+sub]=val&0xFF;
    }
    return;
  }

  if (a2600_cart_type==A2600_CART_WD ||
        a2600_cart_type==A2600_CART_WDSW) {
    if (off>=0x0040 && off<0x0080)
      a2600_cart_ram[off&0x3F]=val&0xFF;
    return;
  }

  if (a2600_cart_type==A2600_CART_3E) {
    if (a2600_cart_ram_mode) {
      if (off>=0x0400) {
        if (off<0x0800) {
          idx=((a2600_cart_seg0&31)<<10)+(off&0x03FF);
          a2600_cart_ram[idx]=val&0xFF;
        }
      }
    }
    return;
  }

  if (a2600_cart_type==A2600_CART_3EX) {
    if (a2600_cart_ram_mode && off>=0x0400 && off<0x0800) {
      idx=((a2600_cart_seg0%A2600Cart3EXRamBanks())<<10)+(off&0x03FF);
      a2600_cart_ram[idx]=val&0xFF;
    }
    return;
  }

  if (a2600_cart_type==A2600_CART_E7) {
    banks2=A2600Cart2KBanks;
    if (off<0x0800) {
      if (a2600_cart_seg0==banks2-1) {
        if (off<0x0400)
          a2600_cart_ram[off&0x03FF]=val&0xFF;
        return;
      }
    }
    if (off>=0x0800) {
      if (off<0x0900) {
        idx=0x0400+((a2600_cart_ram_bank&3)<<8)+(off&0x00FF);
        a2600_cart_ram[idx]=val&0xFF;
      }
    }
    return;
  }

  if (a2600_cart_type==A2600_CART_FA) {
    if (off<0x0100)
      a2600_cart_ram[off]=val&0xFF;
    return;
  }

  if (a2600_cart_type==A2600_CART_FA2) {
    if (off==0x0FF4) {
      A2600FA2FlashAccess();
      return;
    }
    if (off<0x0100)
      a2600_cart_ram[off]=val&0xFF;
    return;
  }

  if (a2600_cart_type==A2600_CART_FC) {
    banks2=a2600_cart_size/A2600_BANK_SIZE;
    if (banks2<1)
      banks2=1;
    if (off==0x0FF8)
      a2600_cart_seg0=val&3;
    else if (off==0x0FF9) {
      b=val&0xFF;
      if ((b<<2)<banks2) {
        a2600_cart_seg0=a2600_cart_seg0+(b<<2);
        a2600_cart_seg0=a2600_cart_seg0%banks2;
      } else
        a2600_cart_seg0=b%banks2;
    } else if (off==0x0FFC)
      a2600_bank=a2600_cart_seg0%banks2;
    return;
  }

  if (a2600_cart_type==A2600_CART_CV) {
    if (off>=0x0400 && off<0x0800)
      a2600_cart_ram[off&0x03FF]=val&0xFF;
    return;
  }

  if (a2600_cart_type==A2600_CART_3EP) {
    banks1=A2600Cart1KBanks();
    seg=(off>>10)&3;
    segval=A2600Cart3EPGetSeg(seg);
    sub=off&0x03FF;
    if (segval>=banks1 && sub>=0x0200) {
      idx=((segval-banks1)&0x3F)<<9;
      a2600_cart_ram[idx+(sub&0x01FF)]=val&0xFF;
    }
    return;
  }

  if (a2600_cart_type==A2600_CART_WF8) {
    if (off==0x0FF8)
      a2600_bank=(val&4)>>2;
    return;
  }

  if ((a2600_cart_type==A2600_CART_EF ||
        a2600_cart_type==A2600_CART_DF ||
        a2600_cart_type==A2600_CART_BF) && a2600_cart_super) {
    if (off<A2600_SARA_SIZE)
      a2600_sara[off]=val&0xFF;
    return;
  }

  if (a2600_cart_super) {
    if (off<A2600_SARA_SIZE)
      a2600_sara[off]=val&0xFF;
  }
}

I64 A2600TIAIndex(I64 tia)
{
  if (!tia)
    return 0;
  return (((tia >> 4) & 0x0F) * 8) + ((tia & 0x0E) >> 1);
}

Bool A2600TVUsesPALColors()
{
  if (a2600_tv_format==A2600_TV_PAL)
    return TRUE;
  if (a2600_tv_format==A2600_TV_PAL60)
    return TRUE;
  return FALSE;
}

Bool A2600TVUsesSECAMColors()
{
  if (a2600_tv_format==A2600_TV_SECAM)
    return TRUE;
  if (a2600_tv_format==A2600_TV_SECAM60)
    return TRUE;
  return FALSE;
}

I64 A2600TIAR(I64 idx)
{
  if (A2600TVUsesSECAMColors())
    return a2600_tia_secam_r[idx&7];
  if (A2600TVUsesPALColors())
    return a2600_tia_pal_r[idx];
  return a2600_tia_ntsc_r[idx];
}

I64 A2600TIAG(I64 idx)
{
  if (A2600TVUsesSECAMColors())
    return a2600_tia_secam_g[idx&7];
  if (A2600TVUsesPALColors())
    return a2600_tia_pal_g[idx];
  return a2600_tia_ntsc_g[idx];
}

I64 A2600TIAB(I64 idx)
{
  if (A2600TVUsesSECAMColors())
    return a2600_tia_secam_b[idx&7];
  if (A2600TVUsesPALColors())
    return a2600_tia_pal_b[idx];
  return a2600_tia_ntsc_b[idx];
}

I64 A2600TIATOSColor(I64 idx)
{
  if (A2600TVUsesSECAMColors())
    return a2600_tia_secam_pal[idx&7];
  if (A2600TVUsesPALColors())
    return a2600_tia_pal_pal[idx];
  return a2600_tia_ntsc_pal[idx];
}

I64 A2600TIAColor(I64 tia)
{
  return A2600TIATOSColor(A2600TIAIndex(tia));
}

I64 A2600NearestTOSColor(I64 r,I64 g,I64 b)
{
  I64 i,best,bestd,dr,dg,db,d;

  best=0;
  bestd=0x7FFFFFFF;
  for (i=0;i<16;i++) {
    dr=r-a2600_tos_r[i];
    dg=g-a2600_tos_g[i];
    db=b-a2600_tos_b[i];
    d=dr*dr+dg*dg+db*db;
    if (d<=bestd) {
      bestd=d;
      best=i;
    }
  }
  return best;
}

U0 A2600InitPhosphor()
{
  I64 c,p,r,g,b,pr,pg,pb,q,dom,cur,prev;

  for (c=0;c<A2600_TIA_COLOR_COUNT;c++)
    for (p=0;p<A2600_TIA_COLOR_COUNT;p++) {
      r=A2600TIAR(c);
      g=A2600TIAG(c);
      b=A2600TIAB(c);
      pr=A2600TIAR(p)/2;
      pg=A2600TIAG(p)/2;
      pb=A2600TIAB(p)/2;
      cur=r+g+b;
      prev=pr+pg+pb;
      if (cur>=prev)
        dom=c;
      else
        dom=p;
      if (pr>r) r=pr;
      if (pg>g) g=pg;
      if (pb>b) b=pb;
      q=A2600NearestTOSColor(r,g,b);
      if ((dom>>3) && (q==0 || q==7 || q==8 || q==15))
        q=A2600TIATOSColor(dom);
      a2600_phosphor_color[c*A2600_TIA_COLOR_COUNT+p]=q;
    }
  a2600_phosphor_ready=1;
}

Bool A2600PFBit(I64 idx)
{
  I64 bit;

  idx=idx>>2;

  if (idx>=20) {
    if (a2600_pf_reflect_latch) {
      idx=39-idx;
    } else {
      idx=idx-20;
    }
  }

  if (idx<4) {
    bit=4+idx;              // PF0 uses only high nibble.
    return (a2600_tia[A2600_PF0]>>bit)&1;
  }
  if (idx<12) {
    bit=11-idx;             // PF1 is displayed high bit first.
    return (a2600_tia[A2600_PF1]>>bit)&1;
  }
  bit=idx-12;               // PF2 is displayed low bit first.
  return (a2600_tia[A2600_PF2]>>bit)&1;
}

I64 A2600WrapX(I64 x)
{
  while (x<0)
    x+=A2600_FB_W;
  while (x>=A2600_FB_W)
    x-=A2600_FB_W;
  return x;
}

I64 A2600ColorClockAt(I64 cyc)
{
  return (cyc%76)*3;
}

I64 A2600CPUCycleAt(I64 cyc)
{
  return cyc%76;
}

I64 A2600BeamXAt(I64 cyc)
{
  I64 c,x;

  c=A2600ColorClockAt(cyc);
  x=c-68;
  if (x<0)
    return 0;
  if (x>A2600_FB_W)
    return A2600_FB_W;
  return x;
}

I64 A2600BeamDelayXAt(I64 cyc,I64 delay)
{
  I64 c,x;

  c=A2600ColorClockAt(cyc)+delay;
  x=c-68;
  if (x<0)
    return 0;
  if (x>A2600_FB_W)
    return A2600_FB_W;
  return x;
}

I64 A2600RespXAt(I64 cyc,I64 motion)
{
  I64 cpu,c;

  cpu=A2600CPUCycleAt(cyc);
  if (cpu*3<=67)
    cpu+=3;
  if (a2600_hmove_cycle==3 && cpu<=24) {
    c=a2600_weird_resp[cpu]-motion+226;
    if (c>234)
      c=234;
    if (c>=228)
      c=c-160;
  } else {
    c=cpu*3;
    if (c<=67)
      c=226;
  }
  return A2600WrapX(c-68);
}

I64 A2600BeamX()
{
  return A2600BeamXAt(a2600_cycles);
}

I64 A2600PFDelayX(I64 cyc)
{
  I64 c,delay,x;

  c=A2600ColorClockAt(cyc);
  delay=4;
  if ((c&3)==1)
    delay=3;
  if ((c&3)==2)
    delay=2;
  if ((c&3)==3)
    delay=5;
  x=c+delay-68;
  if (x<0)
    return 0;
  if (x>A2600_FB_W)
    return A2600_FB_W;
  return x;
}

U0 A2600QueuePFWrite(I64 r,I64 val,I64 x)
{
  val=val&0xFF;
  if (r==A2600_PF0) {
    a2600_pf0_pending=1;
    a2600_pf0_pending_x=x;
    a2600_pf0_pending_val=val;
  } else if (r==A2600_PF1) {
    a2600_pf1_pending=1;
    a2600_pf1_pending_x=x;
    a2600_pf1_pending_val=val;
  } else {
    a2600_pf2_pending=1;
    a2600_pf2_pending_x=x;
    a2600_pf2_pending_val=val;
  }
}

U0 A2600ApplyPFPending(I64 x)
{
  if (a2600_pf0_pending)
    if (x>=a2600_pf0_pending_x) {
      a2600_tia[A2600_PF0]=a2600_pf0_pending_val;
      a2600_pf0_pending=0;
    }
  if (a2600_pf1_pending)
    if (x>=a2600_pf1_pending_x) {
      a2600_tia[A2600_PF1]=a2600_pf1_pending_val;
      a2600_pf1_pending=0;
    }
  if (a2600_pf2_pending)
    if (x>=a2600_pf2_pending_x) {
      a2600_tia[A2600_PF2]=a2600_pf2_pending_val;
      a2600_pf2_pending=0;
    }
}

I64 A2600Motion(I64 v)
{
  I64 n;
  n=(v>>4)&0x0F;
  if (n&8)
    n=n-16;
  return n;
}

I64 A2600HMOVEMotion(I64 v,I64 cpu)
{
  I64 m,t;

  m=A2600Motion(v);
  if (cpu>20) {
    if (cpu<=54)
      return 0;
    if (cpu<=74) {
      t=m+8-a2600_hi_motion[cpu-55];
      if (t<0)
        t=0;
      return t;
    }
    return m;
  }
  if (cpu<=3)
    return m;
  t=a2600_max_motion[cpu];
  if (m>=t)
    return t;
  return m;
}

Bool A2600HMOVEApplies(I64 cpu)
{
  return cpu<=20 || cpu>54;
}

I64 A2600DeepMotion(I64 n)
{
  n=n&0x0F;
  if (n<=7)
    return n;
  if (n==8)
    return 7;
  return n-16;
}

I64 A2600DeepHMOVE(I64 old_val,I64 new_val,I64 cpu)
{
  I64 old_n,new_n,eold,enew,t;

  if (a2600_hmove_cycle!=3 || cpu<6 || cpu>=26)
    return 0;
  old_n=(old_val>>4)&0x0F;
  if (old_n==8)
    return 0;
  eold=a2600_deep_hmove_end[old_n];
  if (cpu>eold)
    return 0;

  new_n=(new_val>>4)&0x0F;
  t=A2600DeepMotion(old_n)-A2600DeepMotion(new_n);
  if (!t)
    return 0;
  if (t<0)
    return t;

  enew=a2600_deep_hmove_end[new_n];
  if (cpu<=enew)
    return t;
  return 99;
}

I64 A2600MissileOffset(I64 nusiz)
{
  I64 mode;

  mode=nusiz&7;
  if (mode==5)
    return 8;
  if (mode==7)
    return 12;
  return 5;
}

I64 A2600MissileLockOffset(I64 nusiz)
{
  return A2600MissileOffset(nusiz)-4;
}

U0 A2600UpdateMissileLocks()
{
  if (a2600_tia[A2600_RESMP0]&2)
    a2600_m0_x=A2600WrapX(a2600_p0_x+
          A2600MissileLockOffset(a2600_tia[A2600_NUSIZ0]));
  if (a2600_tia[A2600_RESMP1]&2)
    a2600_m1_x=A2600WrapX(a2600_p1_x+
          A2600MissileLockOffset(a2600_tia[A2600_NUSIZ1]));
}

U0 A2600UpdateM0LockFromRESP(I64 write_cycle)
{
  if (a2600_tia[A2600_RESMP0]&2)
    a2600_m0_x=A2600WrapX(A2600RespXAt(write_cycle+1,
          a2600_p0_motion)+A2600MissileLockOffset(a2600_tia[A2600_NUSIZ0]));
}

U0 A2600UpdateM1LockFromRESP(I64 write_cycle)
{
  if (a2600_tia[A2600_RESMP1]&2)
    a2600_m1_x=A2600WrapX(A2600RespXAt(write_cycle+1,
          a2600_p1_motion)+A2600MissileLockOffset(a2600_tia[A2600_NUSIZ1]));
}

I64 A2600BallWidth(I64 ctrlpf)
{
  return 1<<((ctrlpf>>4)&3);
}

U0 A2600BallDynBeginScanline()
{
  a2600_bl_dyn_alive=TRUE;
}

U0 A2600BallDynReset()
{
  a2600_bl_dyn_alive=TRUE;
}

U0 A2600BallDynCTRLPFWrite(I64 val,I64 old_val)
{
  I64 x,dx,old_width,new_width;

  if (a2600_vblank)
    return;
  x=A2600BeamXAt(a2600_tia_cycle);
  dx=x-a2600_bl_x;
  if (dx<0)
    dx+=A2600_FB_W;
  old_width=A2600BallWidth(old_val);
  new_width=A2600BallWidth(val);
  if (dx<80 && (dx>=old_width || dx>=new_width))
    a2600_bl_dyn_alive=FALSE;
}

U0 A2600LatchPFReflectMid()
{
  if (!a2600_pf_reflect_mid_latched) {
    a2600_pf_reflect_latch=a2600_tia[A2600_CTRLPF]&1;
    a2600_pf_reflect_mid_latched=1;
  }
}

U0 A2600ApplyDeepHMOVE(I64 obj,I64 old_val,I64 new_val)
{
  I64 t;

  t=A2600DeepHMOVE(old_val,new_val,A2600CPUCycleAt(A2600AccessCycle()));
  if (!t || t==99)
    return;

  if (obj==0) {
    a2600_p0_motion=-t;
    a2600_p0_x=A2600WrapX(a2600_p0_x+t);
  } else if (obj==1) {
    a2600_p1_motion=-t;
    a2600_p1_x=A2600WrapX(a2600_p1_x+t);
  } else if (obj==2) {
    a2600_m0_motion=-t;
    a2600_m0_x=A2600WrapX(a2600_m0_x+t);
  } else if (obj==3) {
    a2600_m1_motion=-t;
    a2600_m1_x=A2600WrapX(a2600_m1_x+t);
  } else {
    a2600_bl_motion=-t;
    a2600_bl_x=A2600WrapX(a2600_bl_x+t);
  }
  A2600UpdateMissileLocks;
}

Bool A2600TimerWrappedAt(I64 cyc)
{
  I64 first;

  first=a2600_timer_expire+1;
  if (cyc<first)
    return FALSE;
  return ((cyc-first)&0xFF)==0;
}

I64 A2600TimerNextIRQAfter(I64 cyc)
{
  I64 first,n;

  first=a2600_timer_expire+1;
  if (cyc<first)
    return first;
  n=((cyc-first)/256)+1;
  return first+(n*256);
}

U0 A2600TimerUpdateIRQ()
{
  if (!a2600_timer_irq)
    if (A2600AccessCycle()>=a2600_timer_next_irq)
      a2600_timer_irq=1;
}

U0 A2600SetTimer(I64 val,I64 div)
{
  I64 now,wrapped;

  now=A2600AccessCycle();
  A2600TimerUpdateIRQ;
  wrapped=A2600TimerWrappedAt(now);
  a2600_timer_expire=now+((val&0xFF)*div);
  a2600_timer_div=div;
  if (!wrapped)
    a2600_timer_irq=0;
  a2600_timer_next_irq=a2600_timer_expire+1;
}

I64 A2600TimerValue()
{
  I64 left,res,now,wrapped;

  now=A2600AccessCycle();
  A2600TimerUpdateIRQ;
  wrapped=A2600TimerWrappedAt(now);
  if (a2600_timer_irq && !wrapped) {
    a2600_timer_irq=0;
    a2600_timer_next_irq=A2600TimerNextIRQAfter(now);
  }
  left=a2600_timer_expire-now;
  if (left<0) {
    res=left&0xFF;
    return res;
  }
  if (a2600_timer_div<=1)
    return left&0xFF;
  return (left/a2600_timer_div)&0xFF;
}

I64 A2600TimerStatus()
{
  I64 res;

  A2600TimerUpdateIRQ;
  if (a2600_timer_irq)
    res=0x80;
  else
    res=0;
  if (a2600_pa7_irq)
    res=res|0x40;
  a2600_pa7_irq=0;
  return res;
}

U0 A2600PA7Update(I64 raw)
{
  I64 stable;

  raw=raw!=0;
  stable=a2600_pa7_sync1;
  a2600_pa7_sync1=raw;
  if (stable!=a2600_pa7_last && stable==a2600_pa7_edge_positive)
    a2600_pa7_irq=1;
  a2600_pa7_last=stable;
}

extern I64 A2600CompuMateCassetteBit();

I64 A2600PA7RawNow()
{
  I64 pins;

  if (a2600_swach_dir&0x80)
    return a2600_swcha_out&0x80;

  pins=a2600_swcha;
  if (a2600_cart_type==A2600_CART_CM) {
    if (A2600CompuMateCassetteBit())
      pins=pins|0x80;
    else
      pins=pins&0x7F;
  }
  return pins&0x80;
}

U0 A2600PA7Access()
{
  A2600PA7Update(A2600PA7RawNow());
}

U0 A2600ClearCollisions()
{
  I64 i;
  for (i=0;i<8;i++)
    a2600_coll[i]=0;
}

U0 A2600NoteCollisions(Bool play,Bool p0on,Bool p1on,
      Bool m0on,Bool m1on,Bool blon)
{
  if (m0on && p1on)
    a2600_coll[0]=a2600_coll[0] | 0x80;
  if (m0on && p0on)
    a2600_coll[0]=a2600_coll[0] | 0x40;
  if (m1on && p0on)
    a2600_coll[1]=a2600_coll[1] | 0x80;
  if (m1on && p1on)
    a2600_coll[1]=a2600_coll[1] | 0x40;
  if (p0on && play)
    a2600_coll[2]=a2600_coll[2] | 0x80;
  if (p0on && blon)
    a2600_coll[2]=a2600_coll[2] | 0x40;
  if (p1on && play)
    a2600_coll[3]=a2600_coll[3] | 0x80;
  if (p1on && blon)
    a2600_coll[3]=a2600_coll[3] | 0x40;
  if (m0on && play)
    a2600_coll[4]=a2600_coll[4] | 0x80;
  if (m0on && blon)
    a2600_coll[4]=a2600_coll[4] | 0x40;
  if (m1on && play)
    a2600_coll[5]=a2600_coll[5] | 0x80;
  if (m1on && blon)
    a2600_coll[5]=a2600_coll[5] | 0x40;
  if (blon && play)
    a2600_coll[6]=a2600_coll[6] | 0x80;
  if (p0on && p1on)
    a2600_coll[7]=a2600_coll[7] | 0x80;
  if (m0on && m1on)
    a2600_coll[7]=a2600_coll[7] | 0x40;
}

Bool A2600ControllerIsQuadTari(I64 ctl)
{
  return ctl==A2600_CTRL_QUADTARI;
}

Bool A2600QuadTariUseFirst()
{
  if (A2600AccessCycle()-a2600_quadtari_dump_cycle<
        A2600_QUADTARI_STABLE_CYCLES)
    return TRUE;
  return !a2600_analog_dump;
}

I64 A2600QuadTariPins(I64 pins)
{
  if (!A2600QuadTariUseFirst()) {
    if (A2600ControllerIsQuadTari(a2600_left_controller))
      pins=(pins&0x0F)|0xF0;
    if (A2600ControllerIsQuadTari(a2600_right_controller))
      pins=(pins&0xF0)|0x0F;
  }
  return pins;
}

Bool A2600QuadTariPadPresent(I64 pad)
{
  pad=pad&3;
  if (pad<2)
    return A2600ControllerIsQuadTari(a2600_left_controller);
  return A2600ControllerIsQuadTari(a2600_right_controller);
}

I64 A2600QuadTariINPT(I64 pad)
{
  pad=pad&3;
  if (pad==0 || pad==2)
    return 0;
  if (a2600_analog_dump)
    return 0;
  return 0x80;
}

Bool A2600ControllerIsKidVid(I64 ctl)
{
  return ctl==A2600_CTRL_KIDVID;
}

U0 A2600KidVidResetRuntime()
{
  a2600_kidvid_tape=0;
  a2600_kidvid_idx=0;
  a2600_kidvid_block=0;
  a2600_kidvid_block_idx=A2600_KIDVID_BLOCK_BITS;
  a2600_kidvid_pins=0xFF;
  a2600_kidvid_delay=0;
}

U0 A2600KidVidClear()
{
  a2600_kidvid_id=0;
  A2600KidVidResetRuntime;
}

U0 A2600KidVidSetGame(I64 id)
{
  if (id!=A2600_KIDVID_BBEARS)
    id=A2600_KIDVID_SMURFS;
  a2600_kidvid_id=id;
  a2600_right_controller=A2600_CTRL_KIDVID;
}

I64 A2600KidVidTapeIndex()
{
  if (a2600_kidvid_tape==4)
    return 3;
  if (a2600_kidvid_id==A2600_KIDVID_BBEARS)
    return a2600_kidvid_tape+2;
  return a2600_kidvid_tape-1;
}

U0 A2600KidVidSelectTape(I64 tape)
{
  if (!a2600_kidvid_id)
    A2600KidVidSetGame(A2600_KIDVID_SMURFS);
  if (tape<1 || tape>4)
    return;
  if (tape==4 && a2600_kidvid_id!=A2600_KIDVID_BBEARS)
    tape=1;
  a2600_kidvid_tape=tape;
  if (a2600_kidvid_id==A2600_KIDVID_BBEARS)
    a2600_kidvid_idx=A2600_KIDVID_BLOCK_BITS;
  else
    a2600_kidvid_idx=0;
  a2600_kidvid_block=0;
  a2600_kidvid_block_idx=A2600_KIDVID_BLOCK_BITS;
  a2600_kidvid_delay=0;
  a2600_kidvid_pins=0xFF;
}

U0 A2600KidVidSetDataBit()
{
  I64 bit;

  bit=(a2600_kidvid_data[(a2600_kidvid_idx>>3)%48]<<
        (a2600_kidvid_idx&7))&0x80;
  a2600_kidvid_pins=a2600_kidvid_pins&0xF7;
  if (bit)
    a2600_kidvid_pins=a2600_kidvid_pins|0x08;
}

U0 A2600KidVidAdvanceBlock()
{
  I64 tape_idx;

  if (a2600_kidvid_block==0)
    a2600_kidvid_idx=A2600_KIDVID_DATA00_BITS+
          (a2600_kidvid_tape-1)*A2600_KIDVID_BLOCK_BITS;
  else {
    tape_idx=A2600KidVidTapeIndex();
    if (tape_idx<0 || tape_idx>=6 ||
          a2600_kidvid_block>=a2600_kidvid_blocks[tape_idx])
      a2600_kidvid_idx=A2600_KIDVID_END_BITS;
    else {
      a2600_kidvid_idx=A2600_KIDVID_PAUSE_BITS;
      a2600_kidvid_delay=A2600_KIDVID_NO_WAV_DELAY;
    }
  }
  a2600_kidvid_block++;
  a2600_kidvid_block_idx=A2600_KIDVID_BLOCK_BITS;
}

U0 A2600KidVidFrame()
{
  I64 running;

  if (a2600_right_controller!=A2600_CTRL_KIDVID || !a2600_kidvid_tape)
    return;
  if (a2600_kidvid_delay>0) {
    a2600_kidvid_delay--;
    return;
  }
  running=(a2600_swcha_out | (0xFF-a2600_swach_dir))&0x01;
  if (!running)
    return;

  A2600KidVidSetDataBit;
  a2600_kidvid_idx++;
  a2600_kidvid_block_idx--;
  if (a2600_kidvid_block_idx<=0)
    A2600KidVidAdvanceBlock;
}

I64 A2600KidVidPins(I64 pins)
{
  if (a2600_right_controller==A2600_CTRL_KIDVID) {
    pins=pins&0xF7;
    if (a2600_kidvid_pins&0x08)
      pins=pins|0x08;
  }
  return pins;
}

Bool A2600ControllerIsCompuMate(I64 ctl)
{
  return ctl==A2600_CTRL_COMPUMATE;
}

Bool A2600CompuMateActive()
{
  return A2600ControllerIsCompuMate(a2600_left_controller) ||
        A2600ControllerIsCompuMate(a2600_right_controller);
}

U0 A2600CompuMateReset()
{
  I64 i;

  a2600_compumate_swcha=0xFF;
  a2600_compumate_column=0;
  for (i=0;i<40;i++)
    a2600_compumate_key_decay[i]=0;
  a2600_compumate_func_decay=0;
  a2600_compumate_shift_decay=0;
}

U0 A2600CompuMateClearSaveState()
{
  I64 i;

  a2600_compumate_save_active=FALSE;
  a2600_compumate_save_t0=-1;
  a2600_compumate_save_last_toggle=0;
  a2600_compumate_save_expected_size=0;
  a2600_compumate_save_byte_pos=0;
  a2600_compumate_save_in_header=TRUE;
  a2600_compumate_save_ok_count=0;
  a2600_compumate_save_fail_count=0;
  a2600_compumate_save_calibrated=FALSE;
  a2600_compumate_save_seen_signal=FALSE;
  a2600_compumate_save_cycles_per_bit=0;
  for (i=0;i<A2600_CM_CAS_FRAME_BITS;i++)
    a2600_compumate_save_bit_trans[i]=0;
}

U0 A2600CompuMateResetCassette()
{
  a2600_compumate_cas_size=0;
  a2600_compumate_cas_loaded=FALSE;
  a2600_compumate_cas_playing=FALSE;
  a2600_compumate_cas_start_cycle=0;
  a2600_compumate_cas_path[0]=0;
  A2600CompuMateClearSaveState;
}

Bool A2600CompuMateLoadCassette(U8 *filename)
{
  U8 *data;
  I64 size,i;

  A2600CompuMateResetCassette;
  if (!filename || !*filename)
    return FALSE;
  if (StrLen(filename)>=A2600_CART_PATH_MAX-5)
    return FALSE;
  StrCpy(a2600_compumate_cas_path,filename);
  FileExtRem(a2600_compumate_cas_path);
  CatPrint(a2600_compumate_cas_path,".CAS");
  if (!FileFind(a2600_compumate_cas_path,,FUF_JUST_FILES))
    return FALSE;
  data=FileRead(a2600_compumate_cas_path,&size);
  if (!data)
    return FALSE;
  if (size!=A2600_CM_CAS_MIN_SIZE && size!=A2600_CM_CAS_MAX_SIZE) {
    Free(data);
    return FALSE;
  }
  for (i=0;i<size;i++)
    a2600_compumate_cas[i]=data[i];
  Free(data);
  a2600_compumate_cas_size=size;
  a2600_compumate_cas_loaded=TRUE;
  return TRUE;
}

U0 A2600CompuMateStartCassette()
{
  if (!a2600_compumate_cas_loaded)
    return;
  a2600_compumate_cas_playing=TRUE;
  a2600_compumate_cas_start_cycle=A2600AccessCycle();
}

F64 A2600CompuMateCPUFreq()
{
  if (a2600_tv_format==A2600_TV_PAL || a2600_tv_format==A2600_TV_PAL60)
    return 1182298.0;
  if (a2600_tv_format==A2600_TV_SECAM || a2600_tv_format==A2600_TV_SECAM60)
    return 1187500.0;
  return 1193182.0;
}

Bool A2600CompuMateSaveCassette()
{
  Bool ok;

  if (!a2600_compumate_cas_loaded || a2600_compumate_cas_size<=0)
    return FALSE;
  if (!a2600_compumate_cas_path[0])
    return FALSE;
  ok=FALSE;
  try {
    ok=FileWrite(a2600_compumate_cas_path,a2600_compumate_cas,
          a2600_compumate_cas_size)>0;
  } catch
    Fs->catch_except=TRUE;
  return ok;
}

U0 A2600CompuMateFinalizeSave()
{
  a2600_compumate_save_active=FALSE;
  a2600_compumate_save_t0=-1;
  A2600CompuMateSaveCassette;
}

U0 A2600CompuMateStartRecord()
{
  I64 i,expected;

  if (!a2600_compumate_cas_path[0])
    return;

  expected=A2600_CM_CAS_MIN_SIZE;
  if (a2600_compumate_cas_size==A2600_CM_CAS_MAX_SIZE)
    expected=A2600_CM_CAS_MAX_SIZE;
  if (!a2600_compumate_cas_loaded) {
    for (i=0;i<expected;i++)
      a2600_compumate_cas[i]=0;
  } else if (a2600_compumate_cas_size<expected) {
    for (i=a2600_compumate_cas_size;i<expected;i++)
      a2600_compumate_cas[i]=0;
  }

  a2600_compumate_cas_size=expected;
  a2600_compumate_cas_loaded=TRUE;
  a2600_compumate_cas_playing=FALSE;
  A2600CompuMateClearSaveState;
  a2600_compumate_save_expected_size=expected;
  a2600_compumate_save_active=TRUE;
  a2600_compumate_save_last_toggle=A2600AccessCycle();
  a2600_compumate_save_in_header=TRUE;
  a2600_compumate_save_cycles_per_bit=18.0*A2600CompuMateCPUFreq()/22050.0;
}

U0 A2600CompuMateFinalizeSaveByte()
{
  I64 i,valid_stop,byte;

  if (a2600_compumate_save_t0<0)
    return;
  a2600_compumate_save_t0=-1;

  valid_stop=TRUE;
  for (i=9;i<=12;i++)
    if (a2600_compumate_save_bit_trans[i]!=4)
      valid_stop=FALSE;

  if (a2600_compumate_save_bit_trans[0]!=2 || !valid_stop) {
    a2600_compumate_save_fail_count++;
    return;
  }

  byte=0;
  for (i=1;i<=8;i++) {
    if (a2600_compumate_save_bit_trans[i]==4)
      byte=byte | (1<<(i-1));
    else if (a2600_compumate_save_bit_trans[i]!=2) {
      a2600_compumate_save_fail_count++;
      return;
    }
  }
  a2600_compumate_save_ok_count++;

  if (a2600_compumate_save_in_header) {
    if (byte==0xFF)
      return;
    a2600_compumate_save_in_header=FALSE;
  }

  if (a2600_compumate_save_byte_pos<a2600_compumate_save_expected_size) {
    a2600_compumate_cas[a2600_compumate_save_byte_pos]=byte;
    a2600_compumate_save_byte_pos++;
    if (a2600_compumate_save_byte_pos>=a2600_compumate_save_expected_size)
      A2600CompuMateFinalizeSave;
  }
}

U0 A2600CompuMateCassetteD6Toggled(I64 cycles)
{
  F64 cycles_since_t0;
  I64 i,gap,bit_window,byte_full;

  if (!a2600_compumate_save_active)
    return;

  gap=cycles-a2600_compumate_save_last_toggle;
  a2600_compumate_save_last_toggle=cycles;
  if (gap<A2600_CM_SAVE_MIN_FSK_GAP)
    return;
  a2600_compumate_save_seen_signal=TRUE;

  if (!a2600_compumate_save_calibrated) {
    if (a2600_compumate_save_t0>=0 && gap>A2600_CM_SAVE_MAX_CALIB_GAP) {
      a2600_compumate_save_t0=-1;
      for (i=0;i<A2600_CM_CAS_FRAME_BITS;i++)
        a2600_compumate_save_bit_trans[i]=0;
    }
    if (a2600_compumate_save_t0<0) {
      a2600_compumate_save_t0=cycles;
      a2600_compumate_save_bit_trans[0]=1;
    } else if (a2600_compumate_save_bit_trans[0]==1) {
      a2600_compumate_save_bit_trans[0]=2;
    } else {
      a2600_compumate_save_cycles_per_bit=cycles-a2600_compumate_save_t0;
      a2600_compumate_save_calibrated=TRUE;
      a2600_compumate_save_bit_trans[1]=1;
    }
    return;
  }

  if (a2600_compumate_save_t0>=0) {
    cycles_since_t0=cycles-a2600_compumate_save_t0;
    bit_window=(cycles_since_t0+a2600_compumate_save_cycles_per_bit/16.0)/
          a2600_compumate_save_cycles_per_bit;
    byte_full=bit_window>12 ||
          (bit_window==12 && a2600_compumate_save_bit_trans[12]>=4);
    if (!byte_full) {
      if (bit_window>=0 && bit_window<A2600_CM_CAS_FRAME_BITS)
        a2600_compumate_save_bit_trans[bit_window]++;
      return;
    }
    A2600CompuMateFinalizeSaveByte;
  }

  a2600_compumate_save_t0=cycles;
  for (i=0;i<A2600_CM_CAS_FRAME_BITS;i++)
    a2600_compumate_save_bit_trans[i]=0;
  a2600_compumate_save_bit_trans[0]=1;
}

U0 A2600CompuMateCheckCassetteTimeout()
{
  if (!a2600_compumate_save_active)
    return;
  if (!a2600_compumate_save_seen_signal)
    return;
  if (A2600AccessCycle()-a2600_compumate_save_last_toggle>
        A2600_CM_SAVE_TIMEOUT_CYCLES) {
    if (a2600_compumate_save_t0>=0)
      A2600CompuMateFinalizeSaveByte;
    if (a2600_compumate_save_active)
      A2600CompuMateFinalizeSave;
  }
}

I64 A2600CompuMateCassetteBit()
{
  F64 sample_pos,phase;
  I64 cycle,stream_bit,byte_idx,frame_bit,byte,bit;

  if (!a2600_compumate_cas_loaded || !a2600_compumate_cas_playing)
    return 1;
  cycle=A2600AccessCycle()-a2600_compumate_cas_start_cycle;
  if (cycle<0)
    cycle=0;
  sample_pos=cycle*22050.0/A2600CompuMateCPUFreq();
  stream_bit=sample_pos/18.0;
  phase=sample_pos-stream_bit*18.0;
  byte_idx=stream_bit/A2600_CM_CAS_FRAME_BITS;
  frame_bit=stream_bit%A2600_CM_CAS_FRAME_BITS;
  if (byte_idx<A2600_CM_CAS_SYNC_BYTES)
    byte=0xFF;
  else {
    byte_idx-=A2600_CM_CAS_SYNC_BYTES;
    if (byte_idx>=a2600_compumate_cas_size)
      return 1;
    byte=a2600_compumate_cas[byte_idx];
  }
  if (!frame_bit)
    bit=0;
  else if (frame_bit<9)
    bit=(byte>>(frame_bit-1))&1;
  else
    bit=1;
  if (!bit) {
    if (phase<9.0)
      return 0;
    return 1;
  }
  if (phase<5.0 || (phase>=9.0 && phase<14.0))
    return 0;
  return 1;
}

U0 A2600CompuMatePressKey(I64 idx)
{
  if (idx>=0 && idx<40)
    a2600_compumate_key_decay[idx]=180;
}

U0 A2600CompuMatePressFunc()
{
  a2600_compumate_func_decay=180;
}

U0 A2600CompuMatePressShift()
{
  a2600_compumate_shift_decay=180;
}

Bool A2600CompuMateRowActive(I64 row)
{
  I64 idx;

  if (!A2600CompuMateActive())
    return FALSE;
  idx=((a2600_compumate_column%10)*4)+(row&3);
  return a2600_compumate_key_decay[idx]>0;
}

U0 A2600CompuMateDecayKeys()
{
  I64 i;

  if (!A2600CompuMateActive())
    return;
  for (i=0;i<40;i++) {
    if (a2600_compumate_key_decay[i]>0)
      a2600_compumate_key_decay[i]--;
  }
  if (a2600_compumate_func_decay>0)
    a2600_compumate_func_decay--;
  if (a2600_compumate_shift_decay>0)
    a2600_compumate_shift_decay--;
}

U0 A2600CompuMateWriteSWCHA(I64 val)
{
  I64 prev;

  prev=a2600_compumate_swcha;
  val=val&0xFF;
  a2600_compumate_swcha=val;
  a2600_bank=val&3;
  if ((val^prev)&0x40)
    A2600CompuMateCassetteD6Toggled(A2600AccessCycle());
  if (val&0x10) {
    if (val&0x20)
      a2600_compumate_column=0;
    else if ((val&0x40) && !(prev&0x40))
      a2600_compumate_column=(a2600_compumate_column+1)%10;
  }
}

I64 A2600CompuMatePins(I64 pins)
{
  if (A2600CompuMateActive()) {
    pins=pins|0x8C;
    if (A2600CompuMateRowActive(1))
      pins=pins&0xFB;
    if (A2600CompuMateRowActive(3))
      pins=pins&0xF7;
    if (a2600_compumate_cas_loaded && a2600_compumate_cas_playing) {
      if (A2600CompuMateCassetteBit())
        pins=pins|0x80;
      else
        pins=pins&0x7F;
    }
  }
  return pins;
}

Bool A2600CompuMatePadPresent(I64 pad)
{
  pad=pad&3;
  if (pad<2)
    return a2600_left_controller==A2600_CTRL_COMPUMATE;
  return a2600_right_controller==A2600_CTRL_COMPUMATE;
}

I64 A2600CompuMateINPT(I64 pad)
{
  pad=pad&3;
  if (pad==0) {
    if (a2600_compumate_func_decay>0)
      return 0x80;
    return 0;
  }
  if (pad==3) {
    if (a2600_compumate_shift_decay>0)
      return 0x80;
    return 0;
  }
  if (a2600_analog_dump)
    return 0;
  return 0x80;
}

I64 A2600SaveKeyPins(I64 pins)
{
  if (a2600_right_controller==A2600_CTRL_SAVEKEY ||
        a2600_right_controller==A2600_CTRL_ATARIVOX) {
    pins=pins&0xFB;
    if (a2600_savekey_mdat && a2600_savekey_sdat)
      pins=pins|0x04;
    if (a2600_right_controller==A2600_CTRL_ATARIVOX)
      pins=pins|0x03;
  }
  return pins;
}

Bool A2600ControllerIsMindlink(I64 ctl)
{
  return ctl==A2600_CTRL_MINDLINK;
}

Bool A2600MindlinkPortActive(I64 port)
{
  if (port&1)
    return A2600ControllerIsMindlink(a2600_right_controller);
  return A2600ControllerIsMindlink(a2600_left_controller);
}

U0 A2600MindlinkNextBit(I64 port)
{
  port=port&1;
  if (port) {
    a2600_mindlink_pins=a2600_mindlink_pins&0xF7;
    if (a2600_mindlink_pos[1]&a2600_mindlink_shift[1])
      a2600_mindlink_pins=a2600_mindlink_pins|0x08;
    a2600_mindlink_shift[1]=a2600_mindlink_shift[1]<<1;
  } else {
    a2600_mindlink_pins=a2600_mindlink_pins&0x7F;
    if (a2600_mindlink_pos[0]&a2600_mindlink_shift[0])
      a2600_mindlink_pins=a2600_mindlink_pins|0x80;
    a2600_mindlink_shift[0]=a2600_mindlink_shift[0]<<1;
  }
}

U0 A2600MindlinkReset()
{
  a2600_mindlink_pos[0]=0x2800;
  a2600_mindlink_pos[1]=0x2800;
  a2600_mindlink_shift[0]=1;
  a2600_mindlink_shift[1]=1;
  a2600_mindlink_pins=0xFF;
  A2600MindlinkNextBit(0);
  A2600MindlinkNextBit(1);
}

U0 A2600MindlinkFrame()
{
  if (A2600MindlinkPortActive(0)) {
    a2600_mindlink_shift[0]=1;
    A2600MindlinkNextBit(0);
  }
  if (A2600MindlinkPortActive(1)) {
    a2600_mindlink_shift[1]=1;
    A2600MindlinkNextBit(1);
  }
}

U0 A2600MindlinkSWCHAWrite(I64 val)
{
  if (A2600MindlinkPortActive(0) && (val&0x10))
    A2600MindlinkNextBit(0);
  if (A2600MindlinkPortActive(1) && (val&0x01))
    A2600MindlinkNextBit(1);
}

I64 A2600MindlinkPins(I64 pins)
{
  if (A2600MindlinkPortActive(0)) {
    pins=pins&0x3F;
    if (a2600_mindlink_pins&0x80)
      pins=pins|0x80;
  }
  if (A2600MindlinkPortActive(1)) {
    pins=pins&0xF3;
    if (a2600_mindlink_pins&0x08)
      pins=pins|0x08;
  }
  return pins;
}

U0 A2600PollInput(I64 advance=TRUE)
{
  I64 swcha_pins,swchb_pins,drive0,drive1;

  swcha_pins=0xFF;
  a2600_joy0_mask=0;
  a2600_joy1_mask=0;
  a2600_joy0_decay=0;
  a2600_joy1_decay=0;
  if (a2600_joy0_up_decay>0) {
    swcha_pins=swcha_pins & 0xEF;
    a2600_joy0_mask=a2600_joy0_mask | 0x10;
    a2600_joy0_decay=a2600_joy0_up_decay;
    if (advance)
      a2600_joy0_up_decay--;
  }
  if (a2600_joy0_down_decay>0) {
    swcha_pins=swcha_pins & 0xDF;
    a2600_joy0_mask=a2600_joy0_mask | 0x20;
    if (a2600_joy0_down_decay>a2600_joy0_decay)
      a2600_joy0_decay=a2600_joy0_down_decay;
    if (advance)
      a2600_joy0_down_decay--;
  }
  if (a2600_joy0_left_decay>0) {
    swcha_pins=swcha_pins & 0xBF;
    a2600_joy0_mask=a2600_joy0_mask | 0x40;
    if (a2600_joy0_left_decay>a2600_joy0_decay)
      a2600_joy0_decay=a2600_joy0_left_decay;
    if (advance)
      a2600_joy0_left_decay--;
  }
  if (a2600_joy0_right_decay>0) {
    swcha_pins=swcha_pins & 0x7F;
    a2600_joy0_mask=a2600_joy0_mask | 0x80;
    if (a2600_joy0_right_decay>a2600_joy0_decay)
      a2600_joy0_decay=a2600_joy0_right_decay;
    if (advance)
      a2600_joy0_right_decay--;
  }
  if (a2600_joy1_up_decay>0) {
    swcha_pins=swcha_pins & 0xFE;
    a2600_joy1_mask=a2600_joy1_mask | 0x01;
    a2600_joy1_decay=a2600_joy1_up_decay;
    if (advance)
      a2600_joy1_up_decay--;
  }
  if (a2600_joy1_down_decay>0) {
    swcha_pins=swcha_pins & 0xFD;
    a2600_joy1_mask=a2600_joy1_mask | 0x02;
    if (a2600_joy1_down_decay>a2600_joy1_decay)
      a2600_joy1_decay=a2600_joy1_down_decay;
    if (advance)
      a2600_joy1_down_decay--;
  }
  if (a2600_joy1_left_decay>0) {
    swcha_pins=swcha_pins & 0xFB;
    a2600_joy1_mask=a2600_joy1_mask | 0x04;
    if (a2600_joy1_left_decay>a2600_joy1_decay)
      a2600_joy1_decay=a2600_joy1_left_decay;
    if (advance)
      a2600_joy1_left_decay--;
  }
  if (a2600_joy1_right_decay>0) {
    swcha_pins=swcha_pins & 0xF7;
    a2600_joy1_mask=a2600_joy1_mask | 0x08;
    if (a2600_joy1_right_decay>a2600_joy1_decay)
      a2600_joy1_decay=a2600_joy1_right_decay;
    if (advance)
      a2600_joy1_right_decay--;
  }
  if (a2600_paddle_mode && a2600_fire0_decay>0)
    swcha_pins=swcha_pins & 0x7F;
  if (a2600_lightgun_mode && a2600_fire0_decay>0) {
    if (a2600_lightgun_port&1)
      swcha_pins=swcha_pins & 0xFE;
    else
      swcha_pins=swcha_pins & 0xEF;
  }

  if (a2600_left_controller==A2600_CTRL_DRIVING)
    drive0=(a2600_driving_table[(a2600_drive0_count&0x0F)>>2]&0x0F)<<4;
  else
    drive0=0xF0;
  if (a2600_right_controller==A2600_CTRL_DRIVING)
    drive1=a2600_driving_table[(a2600_drive1_count&0x0F)>>2]&0x0F;
  else
    drive1=0x0F;
  swcha_pins=swcha_pins & (drive0|drive1);

  swchb_pins=a2600_swchb_base | 0x03;
  if (a2600_auto_reset>0) {
    swchb_pins=swchb_pins & 0xFE;
    if (advance)
      a2600_auto_reset--;
  }
  if (a2600_reset_decay>0) {
    swchb_pins=swchb_pins & 0xFE;
    if (advance)
      a2600_reset_decay--;
  }
  if (a2600_select_decay>0) {
    swchb_pins=swchb_pins & 0xFD;
    if (advance)
      a2600_select_decay--;
  }

  a2600_swcha=(a2600_swcha_out | (0xFF-a2600_swach_dir)) & swcha_pins;
  a2600_swcha=A2600QuadTariPins(a2600_swcha);
  a2600_swcha=A2600SaveKeyPins(a2600_swcha);
  a2600_swcha=A2600MindlinkPins(a2600_swcha);
  a2600_swchb=(a2600_swchb_out | (0xFF-a2600_swbch_dir)) & (swchb_pins | a2600_swbch_dir);

  if (a2600_fire0_decay>0) {
    a2600_fire0=1;
    if (advance)
      a2600_fire0_decay--;
  } else {
    a2600_fire0=0;
  }
  if (a2600_fire1_decay>0) {
    a2600_fire1=1;
    if (advance)
      a2600_fire1_decay--;
  } else {
    a2600_fire1=0;
  }
  if (a2600_inpt_latch_mode) {
    if (a2600_fire0)
      a2600_inpt4_latch=0;
    if (a2600_fire1)
      a2600_inpt5_latch=0;
  }
  if (advance && a2600_trigger0_decay>0)
    a2600_trigger0_decay--;
  if (advance && a2600_booster0_decay>0)
    a2600_booster0_decay--;
  if (advance && a2600_trigger1_decay>0)
    a2600_trigger1_decay--;
  if (advance && a2600_booster1_decay>0)
    a2600_booster1_decay--;
}

U0 A2600InputLatchVBlank(I64 val)
{
  if (val&0x40) {
    a2600_inpt_latch_mode=1;
  } else {
    a2600_inpt_latch_mode=0;
    a2600_inpt4_latch=0x80;
    a2600_inpt5_latch=0x80;
  }
}

U0 A2600PaddleSet(I64 pad,I64 pos)
{
  I64 span;

  pad=pad&3;
  if (pos<0)
    pos=0;
  if (pos>255)
    pos=255;

  a2600_paddle_pos[pad]=pos;
  span=A2600_PADDLE_CHARGE_CYCLES-A2600_PADDLE_MIN_CYCLES;
  a2600_paddle_charge[pad]=A2600_PADDLE_MIN_CYCLES+(span*pos)/255;
}

U0 A2600PaddleMove(I64 pad,I64 delta)
{
  A2600PaddleSet(pad,a2600_paddle_pos[pad&3]+delta);
  a2600_paddle_mode=1;
  if ((pad&3)<2)
    a2600_left_controller=A2600_CTRL_PADDLE;
  else
    a2600_right_controller=A2600_CTRL_PADDLE;
}

U0 A2600PaddleMoveAxis(I64 axis,I64 delta)
{
  A2600PaddleMove(axis&3,delta);
}

U0 A2600DrivingStep(I64 port,I64 delta)
{
  if (port&1)
    a2600_drive1_count=(a2600_drive1_count+delta)&0x0F;
  else
    a2600_drive0_count=(a2600_drive0_count+delta)&0x0F;
}

Bool A2600ControllerIsSaveKey(I64 ctl)
{
  return ctl==A2600_CTRL_SAVEKEY || ctl==A2600_CTRL_ATARIVOX;
}

Bool A2600ControllerIsAtariVox(I64 ctl)
{
  return ctl==A2600_CTRL_ATARIVOX;
}

Bool A2600SaveKeyActive()
{
  return A2600ControllerIsSaveKey(a2600_right_controller);
}

Bool A2600AtariVoxActive()
{
  return A2600ControllerIsAtariVox(a2600_right_controller);
}

U0 A2600AtariVoxResetSerial()
{
  a2600_atarivox_shift_count=0;
  a2600_atarivox_shift_reg=0;
  a2600_atarivox_last_write_cycle=0;
  a2600_atarivox_last_byte=0;
  a2600_atarivox_byte_count=0;
  a2600_atarivox_bad_start=0;
  a2600_atarivox_bad_stop=0;
}

U0 A2600AtariVoxClockDataIn(I64 value)
{
  I64 cycle;

  value=value!=0;
  if (value && !a2600_atarivox_shift_count)
    return;

  cycle=A2600AccessCycle();
  if (cycle<a2600_atarivox_last_write_cycle ||
        cycle>a2600_atarivox_last_write_cycle+A2600_ATARIVOX_GAP_CYCLES) {
    a2600_atarivox_shift_reg=0;
    a2600_atarivox_shift_count=0;
  }

  if (cycle<a2600_atarivox_last_write_cycle ||
        cycle>=a2600_atarivox_last_write_cycle+A2600_ATARIVOX_BIT_CYCLES) {
    a2600_atarivox_shift_reg=a2600_atarivox_shift_reg>>1;
    if (value)
      a2600_atarivox_shift_reg=a2600_atarivox_shift_reg|0x8000;
    a2600_atarivox_shift_count++;
    if (a2600_atarivox_shift_count==10) {
      a2600_atarivox_shift_count=0;
      a2600_atarivox_shift_reg=a2600_atarivox_shift_reg>>6;
      if (!(a2600_atarivox_shift_reg&0x0200))
        a2600_atarivox_bad_start++;
      else if (a2600_atarivox_shift_reg&1)
        a2600_atarivox_bad_stop++;
      else {
        a2600_atarivox_last_byte=(a2600_atarivox_shift_reg>>1)&0xFF;
        a2600_atarivox_byte_count++;
      }
      a2600_atarivox_shift_reg=0;
    }
  }

  a2600_atarivox_last_write_cycle=cycle;
}

U0 A2600SaveKeyResetBus()
{
  a2600_savekey_state=A2600_SAVEKEY_IDLE;
  a2600_savekey_mdat=1;
  a2600_savekey_sdat=1;
  a2600_savekey_mclk=0;
  a2600_savekey_addr_known=FALSE;
  a2600_savekey_pptr=0;
  a2600_savekey_nb=0;
  a2600_savekey_addr=0;
  a2600_savekey_timer_until=0;
}

U0 A2600SaveKeyErase()
{
  I64 i;

  for (i=0;i<A2600_SAVEKEY_SIZE;i++)
    a2600_savekey_eeprom[i]=0xFF;
  a2600_savekey_loaded=TRUE;
  a2600_savekey_dirty=FALSE;
}

U0 A2600SaveKeyClear()
{
  a2600_savekey_active=FALSE;
  a2600_savekey_loaded=FALSE;
  a2600_savekey_dirty=FALSE;
  a2600_savekey_path[0]=0;
  A2600SaveKeyResetBus;
  A2600AtariVoxResetSerial;
}

U0 A2600SaveKeySetController(I64 atarivox)
{
  a2600_savekey_active=TRUE;
  if (atarivox)
    a2600_right_controller=A2600_CTRL_ATARIVOX;
  else
    a2600_right_controller=A2600_CTRL_SAVEKEY;
  A2600SaveKeyResetBus;
  A2600AtariVoxResetSerial;
}

Bool A2600SaveKeyLoad(U8 *filename)
{
  U8 *data;
  I64 i,size,limit;

  A2600SaveKeyErase;
  a2600_savekey_path[0]=0;
  if (!filename || !*filename)
    return FALSE;
  if (StrLen(filename)>=A2600_CART_PATH_MAX-5)
    return FALSE;
  StrCpy(a2600_savekey_path,filename);
  FileExtRem(a2600_savekey_path);
  CatPrint(a2600_savekey_path,".SKY");
  if (!FileFind(a2600_savekey_path,,FUF_JUST_FILES))
    return FALSE;

  data=FileRead(a2600_savekey_path,&size);
  if (!data)
    return FALSE;
  limit=size;
  if (limit>A2600_SAVEKEY_SIZE)
    limit=A2600_SAVEKEY_SIZE;
  for (i=0;i<limit;i++)
    a2600_savekey_eeprom[i]=data[i];
  Free(data);
  return TRUE;
}

Bool A2600SaveKeySave()
{
  Bool ok;

  if (!a2600_savekey_path[0])
    return FALSE;
  ok=FALSE;
  try {
    if (FileFind(a2600_savekey_path,,FUF_JUST_FILES))
      Del(a2600_savekey_path);
    ok=FileWrite(a2600_savekey_path,a2600_savekey_eeprom,
          A2600_SAVEKEY_SIZE)>0;
  } catch {
    Fs->catch_except=TRUE;
  }
  if (ok)
    a2600_savekey_dirty=FALSE;
  return ok;
}

Bool A2600SaveKeyTimerBusy()
{
  if (a2600_savekey_timer_until>A2600AccessCycle())
    return TRUE;
  a2600_savekey_timer_until=0;
  return FALSE;
}

U0 A2600SaveKeyStart()
{
  if (a2600_savekey_state==A2600_SAVEKEY_BYTE_IN &&
        (a2600_savekey_nb!=1 || a2600_savekey_pptr!=3))
    a2600_savekey_addr_known=FALSE;
  if (A2600SaveKeyTimerBusy())
    a2600_savekey_state=A2600_SAVEKEY_IDLE;
  else
    a2600_savekey_state=A2600_SAVEKEY_ACK;
  a2600_savekey_pptr=0;
  a2600_savekey_nb=0;
  a2600_savekey_packet[0]=0;
}

U0 A2600SaveKeyStop()
{
  I64 i,limit,page_left;

  if (a2600_savekey_state==A2600_SAVEKEY_BYTE_IN &&
        a2600_savekey_nb!=1)
    a2600_savekey_addr_known=FALSE;
  if (a2600_savekey_state==A2600_SAVEKEY_BYTE_OUT)
    a2600_savekey_addr_known=FALSE;

  if (a2600_savekey_state==A2600_SAVEKEY_BYTE_IN &&
        a2600_savekey_nb==1 && a2600_savekey_pptr>3) {
    a2600_savekey_timer_until=A2600AccessCycle()+A2600_SAVEKEY_WRITE_CYCLES;
    limit=a2600_savekey_pptr;
    page_left=A2600_SAVEKEY_PAGE-(a2600_savekey_addr&(A2600_SAVEKEY_PAGE-1));
    if (limit-3>page_left)
      limit=3+page_left;
    for (i=3;i<limit;i++) {
      a2600_savekey_eeprom[a2600_savekey_addr&(A2600_SAVEKEY_SIZE-1)]=
            a2600_savekey_packet[i];
      a2600_savekey_addr++;
      a2600_savekey_dirty=TRUE;
    }
    if (a2600_savekey_dirty)
      A2600SaveKeySave;
    a2600_savekey_addr_known=FALSE;
  }

  a2600_savekey_state=A2600_SAVEKEY_IDLE;
}

U0 A2600SaveKeyClockFall()
{
  I64 data;

  switch (a2600_savekey_state) {
    case A2600_SAVEKEY_BYTE_IN:
      a2600_savekey_nb=(a2600_savekey_nb<<1) |
            (a2600_savekey_mdat!=0);
      if (a2600_savekey_nb&0x100) {
        if (!a2600_savekey_pptr) {
          a2600_savekey_packet[0]=a2600_savekey_nb&0xFF;
          if (a2600_savekey_nb==0x1A0) {
            a2600_savekey_state=A2600_SAVEKEY_ACK;
            a2600_savekey_sdat=0;
          } else if (a2600_savekey_nb==0x1A1) {
            a2600_savekey_state=A2600_SAVEKEY_WAIT_ACK;
            a2600_savekey_sdat=0;
          } else
            a2600_savekey_state=A2600_SAVEKEY_IDLE;
        } else {
          a2600_savekey_state=A2600_SAVEKEY_ACK;
          a2600_savekey_sdat=0;
        }
      }
      break;
    case A2600_SAVEKEY_ACK:
      if (a2600_savekey_nb) {
        if (!a2600_savekey_pptr) {
          a2600_savekey_packet[0]=a2600_savekey_nb&0xFF;
          a2600_savekey_pptr=1;
        } else if (a2600_savekey_pptr<A2600_SAVEKEY_PACKET_MAX) {
          a2600_savekey_packet[a2600_savekey_pptr++]=
                a2600_savekey_nb&0xFF;
          if (a2600_savekey_pptr>2) {
            a2600_savekey_addr=(a2600_savekey_packet[1]<<8) |
                  a2600_savekey_packet[2];
            a2600_savekey_addr_known=TRUE;
          }
        }
      }
      a2600_savekey_sdat=1;
      a2600_savekey_nb=1;
      a2600_savekey_state=A2600_SAVEKEY_BYTE_IN;
      break;
    case A2600_SAVEKEY_WAIT_ACK:
      if (a2600_savekey_mdat && a2600_savekey_sdat) {
        a2600_savekey_state=A2600_SAVEKEY_IDLE;
        break;
      }
      a2600_savekey_state=A2600_SAVEKEY_BYTE_OUT;
      data=a2600_savekey_eeprom[a2600_savekey_addr&
            (A2600_SAVEKEY_SIZE-1)];
      a2600_savekey_nb=(data<<1)|1;
    case A2600_SAVEKEY_BYTE_OUT:
      a2600_savekey_sdat=(a2600_savekey_nb&0x100)!=0;
      a2600_savekey_nb=a2600_savekey_nb<<1;
      if (!(a2600_savekey_nb&0x1FE)) {
        a2600_savekey_state=A2600_SAVEKEY_WAIT_ACK;
        a2600_savekey_sdat=1;
        a2600_savekey_addr++;
      }
      break;
  }
}

U0 A2600SaveKeyClock(I64 state)
{
  state=state!=0;
  if (!state && a2600_savekey_mclk)
    A2600SaveKeyClockFall;
  a2600_savekey_mclk=state;
}

U0 A2600SaveKeyData(I64 state)
{
  state=state!=0;
  if (state) {
    if (!a2600_savekey_mdat && a2600_savekey_sdat &&
          a2600_savekey_mclk)
      A2600SaveKeyStop;
    a2600_savekey_mdat=1;
  } else {
    if (a2600_savekey_mdat && a2600_savekey_sdat &&
          a2600_savekey_mclk)
      A2600SaveKeyStart;
    a2600_savekey_mdat=0;
  }
}

U0 A2600SaveKeyUpdatePins()
{
  I64 ioport,sda,scl;

  if (!A2600SaveKeyActive())
    return;
  if (!a2600_savekey_loaded)
    A2600SaveKeyErase;
  ioport=a2600_swcha_out | (0xFF-a2600_swach_dir);
  if (A2600AtariVoxActive())
    A2600AtariVoxClockDataIn(ioport&0x01);
  sda=ioport&0x04;
  scl=ioport&0x08;
  if ((scl!=0)!=(a2600_savekey_mclk!=0))
    A2600SaveKeyClock(scl);
  if ((sda!=0)!=(a2600_savekey_mdat!=0))
    A2600SaveKeyData(sda);
}

U0 A2600SetControllerDefaults()
{
  a2600_left_controller=A2600_CTRL_JS;
  a2600_right_controller=A2600_CTRL_JS;
  a2600_controller_lightgun_adjust=0;
  a2600_controller_lightgun_vadjust=5;
  a2600_controller_lightgun_wrap=78;
  A2600SaveKeyClear;
}

Bool A2600ControllerHasAnalogButtons(I64 ctl)
{
  return ctl==A2600_CTRL_BOOSTER || ctl==A2600_CTRL_GENESIS ||
        ctl==A2600_CTRL_JOY2B;
}

Bool A2600AnalogButtonPadPresent(I64 pad)
{
  I64 ctl;

  pad=pad&3;
  if (pad<2)
    ctl=a2600_left_controller;
  else
    ctl=a2600_right_controller;
  return A2600ControllerHasAnalogButtons(ctl);
}

Bool A2600AnalogButtonPadActive(I64 pad)
{
  pad=pad&3;
  if (pad==0)
    return a2600_trigger0_decay>0;
  if (pad==1)
    return a2600_booster0_decay>0;
  if (pad==2)
    return a2600_trigger1_decay>0;
  return a2600_booster1_decay>0;
}

I64 A2600AnalogButtonINPT(I64 pad)
{
  I64 ctl;

  pad=pad&3;
  if (pad<2)
    ctl=a2600_left_controller;
  else
    ctl=a2600_right_controller;

  if (a2600_analog_dump)
    return 0;
  if (ctl==A2600_CTRL_BOOSTER) {
    if (A2600AnalogButtonPadActive(pad))
      return 0x80;
    return 0;
  }
  if (ctl==A2600_CTRL_GENESIS) {
    if ((pad&1)==0)
      return 0x80;
    if (A2600AnalogButtonPadActive(pad))
      return 0;
    return 0x80;
  }
  if (ctl==A2600_CTRL_JOY2B) {
    if (A2600AnalogButtonPadActive(pad))
      return 0;
    return 0x80;
  }
  return 0x80;
}

U0 A2600BoosterGripPress(I64 port,I64 button)
{
  if (port&1) {
    if (button&1)
      a2600_booster1_decay=20;
    else
      a2600_trigger1_decay=20;
  } else {
    if (button&1)
      a2600_booster0_decay=20;
    else
      a2600_trigger0_decay=20;
  }
}

U0 A2600LightgunPort(I64 port)
{
  a2600_lightgun_port=port&1;
  if (a2600_lightgun_port&1)
    a2600_right_controller=A2600_CTRL_LIGHTGUN;
  else
    a2600_left_controller=A2600_CTRL_LIGHTGUN;
}

U0 A2600LightgunAim(I64 x,I64 y)
{
  if (x<0)
    x=0;
  if (x>=A2600_FB_W)
    x=A2600_FB_W-1;
  if (y<0)
    y=0;
  if (y>=A2600_FB_H)
    y=A2600_FB_H-1;

  a2600_lightgun_mode=1;
  if (a2600_lightgun_port&1)
    a2600_right_controller=A2600_CTRL_LIGHTGUN;
  else
    a2600_left_controller=A2600_CTRL_LIGHTGUN;
  a2600_lightgun_x=x;
  a2600_lightgun_y=y;
  a2600_lightgun_cycle=(x/3)+23+a2600_lightgun_adjust;
  a2600_lightgun_line=y+4-a2600_lightgun_vadjust;
  if (a2600_lightgun_cycle>=76)
    a2600_lightgun_line++;
  if (a2600_lightgun_line<0)
    a2600_lightgun_line=0;
}

U0 A2600LightgunMove(I64 dx,I64 dy)
{
  A2600LightgunAim(a2600_lightgun_x+dx,a2600_lightgun_y+dy);
}

I64 A2600LightgunTestAt(I64 rclock,I64 scanline)
{
  I64 beam,delta;

  if (!a2600_lightgun_mode)
    return 0x80;
  if (a2600_lightgun_line>scanline)
    return 0x80;

  beam=rclock;
  if (a2600_lightgun_cycle>=a2600_lightgun_wrap && rclock<=22)
    beam=rclock+76;
  delta=beam-a2600_lightgun_cycle;
  if (delta>=0 && delta<A2600_LIGHTGUN_WINDOW)
    return 0;
  return 0x80;
}

I64 A2600LightgunSensor()
{
  return A2600LightgunTestAt(A2600CPUCycleAt(A2600AccessCycle()),
        a2600_scanline);
}

U0 A2600AnalogVBlank(I64 val)
{
  I64 old_dump,new_dump;

  old_dump=a2600_analog_dump!=0;
  new_dump=(val&0x80)!=0;
  if (old_dump!=new_dump)
    a2600_quadtari_dump_cycle=A2600AccessCycle();
  if (val&0x80) {
    a2600_analog_dump=1;
    a2600_analog_charge_start=a2600_tia_cycle;
  } else if (a2600_analog_dump) {
    a2600_analog_dump=0;
    a2600_analog_charge_start=a2600_tia_cycle;
  }
}

I64 A2600AnalogINPT(I64 pad)
{
  I64 elapsed;

  if (A2600QuadTariPadPresent(pad))
    return A2600QuadTariINPT(pad);
  if (A2600AnalogButtonPadPresent(pad))
    return A2600AnalogButtonINPT(pad);
  if (a2600_analog_dump)
    return 0;

  elapsed=a2600_cycles-a2600_analog_charge_start;
  if (elapsed<0)
    elapsed=0;
  if (elapsed>=a2600_paddle_charge[pad&3])
    return 0x80;
  return 0;
}

I64 A2600INPT4()
{
  I64 val;

  if (A2600CompuMateActive()) {
    if (A2600CompuMateRowActive(0))
      val=0;
    else
      val=0x80;
  } else if (A2600ControllerIsQuadTari(a2600_left_controller) &&
        !A2600QuadTariUseFirst())
    val=0x80;
  else if (a2600_lightgun_mode && !(a2600_lightgun_port&1))
    val=A2600LightgunSensor();
  else if (a2600_fire0)
    val=0;
  else
    val=0x80;

  if (a2600_inpt_latch_mode) {
    a2600_inpt4_latch=a2600_inpt4_latch & val;
    val=a2600_inpt4_latch;
  }
  return val;
}

I64 A2600INPT5()
{
  I64 val;

  if (A2600CompuMateActive()) {
    if (A2600CompuMateRowActive(2))
      val=0;
    else
      val=0x80;
  } else if (A2600ControllerIsQuadTari(a2600_right_controller) &&
        !A2600QuadTariUseFirst())
    val=0x80;
  else if (a2600_lightgun_mode && (a2600_lightgun_port&1))
    val=A2600LightgunSensor();
  else if (a2600_fire1)
    val=0;
  else
    val=0x80;

  if (a2600_inpt_latch_mode) {
    a2600_inpt5_latch=a2600_inpt5_latch & val;
    val=a2600_inpt5_latch;
  }
  return val;
}

Bool A2600KidVidHandleKey(I64 ch,I64 code)
{
  if (a2600_right_controller!=A2600_CTRL_KIDVID)
    return FALSE;
  if (ch=='1') {
    A2600KidVidSelectTape(1);
    return TRUE;
  }
  if (ch=='2') {
    A2600KidVidSelectTape(2);
    return TRUE;
  }
  if (ch=='3') {
    A2600KidVidSelectTape(3);
    return TRUE;
  }
  if (ch=='4') {
    A2600KidVidSelectTape(4);
    return TRUE;
  }
  if (ch=='b' || ch=='B') {
    A2600KidVidSetGame(A2600_KIDVID_BBEARS);
    return TRUE;
  }
  if (ch=='g' || ch=='G') {
    A2600KidVidSetGame(A2600_KIDVID_SMURFS);
    return TRUE;
  }
  return FALSE;
}

I64 A2600CompuMateKeyIndex(I64 ch)
{
  if (ch>='a' && ch<='z')
    return ch-'a';
  if (ch>='A' && ch<='Z')
    return ch-'A';
  if (ch>='0' && ch<='9')
    return 26+ch-'0';
  if (ch==' ')
    return 36;
  if (ch=='.')
    return 37;
  if (ch==',')
    return 38;
  if (ch=='/')
    return 39;
  return -1;
}

Bool A2600CompuMateHandleSpecialKey(I64 ch,I64 code)
{
  if (!A2600CompuMateActive())
    return FALSE;
  if (ch=='[') {
    A2600CompuMatePressFunc;
    return TRUE;
  }
  if (ch==']') {
    A2600CompuMatePressShift;
    return TRUE;
  }
  return FALSE;
}

Bool A2600CompuMateHandleKey(I64 ch,I64 code)
{
  I64 idx;

  if (!A2600CompuMateActive())
    return FALSE;
  if (A2600CompuMateHandleSpecialKey(ch,code))
    return TRUE;
  idx=A2600CompuMateKeyIndex(ch);
  if (idx<0)
    return FALSE;
  A2600CompuMatePressKey(idx);
  return TRUE;
}

U0 A2600HandleKey(I64 ch,I64 sc)
{
  I64 code;
  code=sc.u8[0];

  if (A2600KidVidHandleKey(ch,code))
    return;
  if (A2600CompuMateHandleKey(ch,code))
    return;

  if (ch=='g' || ch=='G') {
    if (a2600_lightgun_mode)
      a2600_lightgun_mode=0;
    else
      A2600LightgunAim(a2600_lightgun_x,a2600_lightgun_y);
  }
  if (ch=='h' || ch=='H')
    A2600LightgunPort(a2600_lightgun_port+1);

  if (a2600_lightgun_mode) {
    if (code==SC_CURSOR_UP)
      A2600LightgunMove(0,-4);
    if (code==SC_CURSOR_DOWN)
      A2600LightgunMove(0,4);
    if (code==SC_CURSOR_LEFT)
      A2600LightgunMove(-4,0);
    if (code==SC_CURSOR_RIGHT)
      A2600LightgunMove(4,0);
  } else {
    if (code==SC_CURSOR_UP)
      a2600_joy0_up_decay=A2600_INPUT_HOLD_DECAY;
    if (code==SC_CURSOR_DOWN)
      a2600_joy0_down_decay=A2600_INPUT_HOLD_DECAY;
    if (code==SC_CURSOR_LEFT)
      a2600_joy0_left_decay=A2600_INPUT_HOLD_DECAY;
    if (code==SC_CURSOR_RIGHT)
      a2600_joy0_right_decay=A2600_INPUT_HOLD_DECAY;
  }
  if (ch=='f' || ch=='F' ||
        ch==CH_SPACE || code==A2600_SC_SPACE ||
        code==A2600_SC_ENTER ||
        ch=='\n' || ch=='\r' || ch==CH_CTRLM)
    a2600_fire0_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='i' || ch=='I')
    a2600_joy1_up_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='k' || ch=='K')
    a2600_joy1_down_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='j' || ch=='J')
    a2600_joy1_left_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='l' || ch=='L')
    a2600_joy1_right_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='m' || ch=='M')
    a2600_fire1_decay=A2600_INPUT_HOLD_DECAY;
  if (ch=='a' || ch=='A')
    A2600PaddleMoveAxis(0,A2600_PADDLE_STEP);
  if (ch=='d' || ch=='D')
    A2600PaddleMoveAxis(0,-A2600_PADDLE_STEP);
  if (ch=='w' || ch=='W')
    A2600PaddleMoveAxis(1,-A2600_PADDLE_STEP);
  if (ch=='s' || ch=='S')
    A2600PaddleMoveAxis(1,A2600_PADDLE_STEP);
  if (ch=='z' || ch=='Z')
    A2600DrivingStep(0,-4);
  if (ch=='x' || ch=='X')
    A2600DrivingStep(0,4);
  if (ch=='b' || ch=='B')
    A2600BoosterGripPress(0,1);
  if (ch=='n' || ch=='N' || ch=='/')
    A2600BoosterGripPress(0,0);
  if (ch=='v' || ch=='V')
    A2600BoosterGripPress(1,1);
  if (ch=='c' || ch=='C')
    A2600BoosterGripPress(1,0);
  if (code==SC_F1)
    a2600_reset_decay=8;
  if (code==SC_F2)
    a2600_select_decay=8;
  if (code==SC_F3)
    a2600_swchb_base=a2600_swchb_base & 0xF7;
  if (code==SC_F4)
    a2600_swchb_base=a2600_swchb_base | 0x08;
  if (code==SC_F5)
    a2600_swchb_base=a2600_swchb_base & 0xBF;
  if (code==SC_F6)
    a2600_swchb_base=a2600_swchb_base | 0x40;
  if (code==SC_F7)
    a2600_swchb_base=a2600_swchb_base & 0x7F;
  if (code==SC_F8)
    a2600_swchb_base=a2600_swchb_base | 0x80;
}

Bool A2600DrainInputKeys()
{
  I64 ch,sc,quit=FALSE;

  while (ScanKey(&ch,&sc,FALSE)) {
    A2600HandleKey(ch,sc);
    if (ch==CH_ESC || sc.u8[0]==SC_ESC) {
      a2600_quit_requested=TRUE;
      quit=TRUE;
    }
  }
  return quit;
}

Bool A2600PlayerCopyBit(I64 x,I64 pos,I64 grp,I64 reflect,I64 scale)
{
  I64 dx,bit;

  dx=x-pos;
  if (dx<0)
    dx+=A2600_FB_W;
  if (dx<0 || dx>=8*scale)
    return FALSE;

  bit=dx/scale;
  if (reflect&0x08)
    return (grp>>bit)&1;
  return (grp>>(7-bit))&1;
}

I64 A2600PlayerVisibleStart(I64 pos)
{
  if (pos<8)
    return pos;
  return A2600WrapX(pos+4);
}

Bool A2600PlayerBit(I64 x,I64 pos,I64 grp,I64 reflect,I64 nusiz)
{
  I64 mode,scale;

  mode=nusiz&7;
  scale=1;
  if (mode==5)
    scale=2;
  if (mode==7)
    scale=4;

  if (A2600PlayerCopyBit(x,A2600PlayerVisibleStart(pos),grp,reflect,scale))
    return TRUE;

  if (mode==1 || mode==3)
    if (A2600PlayerCopyBit(x,A2600PlayerVisibleStart(pos+16),grp,reflect,scale))
      return TRUE;

  if (mode==2 || mode==6)
    if (A2600PlayerCopyBit(x,A2600PlayerVisibleStart(pos+32),grp,reflect,scale))
      return TRUE;

  if (mode==3)
    if (A2600PlayerCopyBit(x,A2600PlayerVisibleStart(pos+32),grp,reflect,scale))
      return TRUE;

  if (mode==4 || mode==6)
    if (A2600PlayerCopyBit(x,A2600PlayerVisibleStart(pos+64),grp,reflect,scale))
      return TRUE;

  return FALSE;
}

I64 A2600PlayerDivider(I64 nusiz)
{
  I64 mode;

  mode=nusiz&7;
  if (mode==5)
    return 2;
  if (mode==7)
    return 4;
  return 1;
}

I64 A2600PlayerDecodePattern(I64 nusiz)
{
  I64 mode;

  mode=nusiz&7;
  if (mode==5 || mode==7)
    return 0;
  return mode;
}

U0 A2600PlayerDynSetDivider(I64 player,I64 divider)
{
  player=player&1;
  a2600_p_dyn_divider[player]=divider;
  if (divider==1)
    a2600_p_dyn_trip[player]=0;
  else
    a2600_p_dyn_trip[player]=1;
}

Bool A2600PlayerDynPrimeCopy(I64 player,I64 start,I64 divider)
{
  I64 width,counter,sample;

  player=player&1;
  start=A2600PlayerVisibleStart(start);
  width=8*divider;
  if (start<5)
    counter=-start;
  else if (start+width>A2600_FB_W)
    counter=A2600_FB_W-start;
  else
    return FALSE;

  if (counter<=0)
    sample=0;
  else if (divider==1)
    sample=counter;
  else
    sample=(counter-1)/divider;
  if (sample>7)
    return FALSE;

  A2600PlayerDynSetDivider(player,divider);
  a2600_p_dyn_pending[player]=divider;
  a2600_p_dyn_render[player]=TRUE;
  a2600_p_dyn_counter[player]=counter;
  a2600_p_dyn_sample[player]=sample;
  a2600_p_dyn_change[player]=-1;
  return TRUE;
}

U0 A2600PlayerDynPrimeScanline(I64 player,I64 pos,I64 nusiz)
{
  I64 mode,divider;

  player=player&1;
  mode=nusiz&7;
  divider=A2600PlayerDivider(nusiz);
  if (A2600PlayerDynPrimeCopy(player,pos,divider))
    return;
  if (mode==1 || mode==3)
    if (A2600PlayerDynPrimeCopy(player,A2600WrapX(pos+16),divider))
      return;
  if (mode==2 || mode==6)
    if (A2600PlayerDynPrimeCopy(player,A2600WrapX(pos+32),divider))
      return;
  if (mode==3)
    if (A2600PlayerDynPrimeCopy(player,A2600WrapX(pos+32),divider))
      return;
  if (mode==4 || mode==6)
    A2600PlayerDynPrimeCopy(player,A2600WrapX(pos+64),divider);
}

U0 A2600PlayerDynBeginScanline()
{
  I64 p;

  for (p=0;p<2;p++) {
    a2600_p_dyn_render[p]=0;
    a2600_p_dyn_counter[p]=0;
    a2600_p_dyn_sample[p]=0;
    a2600_p_dyn_pending[p]=A2600PlayerDivider(a2600_tia[A2600_NUSIZ0+p]);
    a2600_p_dyn_change[p]=-1;
    A2600PlayerDynSetDivider(p,a2600_p_dyn_pending[p]);
  }
  A2600PlayerDynPrimeScanline(0,a2600_p0_x,a2600_tia[A2600_NUSIZ0]);
  A2600PlayerDynPrimeScanline(1,a2600_p1_x,a2600_tia[A2600_NUSIZ1]);
}

Bool A2600PlayerCopyStart(I64 x,I64 pos,I64 nusiz)
{
  I64 mode;

  mode=nusiz&7;
  if (x==A2600PlayerVisibleStart(pos))
    return TRUE;
  if (mode==1 || mode==3)
    if (x==A2600PlayerVisibleStart(pos+16))
      return TRUE;
  if (mode==2 || mode==6)
    if (x==A2600PlayerVisibleStart(pos+32))
      return TRUE;
  if (mode==3)
    if (x==A2600PlayerVisibleStart(pos+32))
      return TRUE;
  if (mode==4 || mode==6)
    if (x==A2600PlayerVisibleStart(pos+64))
      return TRUE;
  return FALSE;
}

Bool A2600PlayerDecodeStart(I64 x,I64 pos,I64 nusiz)
{
  if (A2600PlayerCopyStart(A2600WrapX(x+5),pos,nusiz))
    return TRUE;
  return FALSE;
}

Bool A2600PlayerRecentDecodeStart(I64 x,I64 pos,I64 nusiz)
{
  I64 i;

  for (i=1;i<=3;i++)
    if (A2600PlayerDecodeStart(A2600WrapX(x-i),pos,nusiz))
      return i;
  return 0;
}

Bool A2600PlayerPatternBit(I64 sample,I64 grp,I64 reflect)
{
  if (sample<0 || sample>7)
    return FALSE;
  if (reflect&0x08)
    return (grp>>sample)&1;
  return (grp>>(7-sample))&1;
}

U0 A2600PlayerDynStart(I64 player)
{
  player=player&1;
  a2600_p_dyn_render[player]=TRUE;
  a2600_p_dyn_counter[player]=-5;
  a2600_p_dyn_sample[player]=0;
  a2600_p_dyn_change[player]=-1;
}

U0 A2600PlayerDynNUSIZWrite(I64 player,I64 val,I64 old_val)
{
  I64 pending,pair,delta,hblank,limit0,limit1;
  I64 old_pattern,new_pattern,x,pos,decode_x;

  player=player&1;
  pending=A2600PlayerDivider(val);
  a2600_p_dyn_pending[player]=pending;
  hblank=A2600ColorClockAt(a2600_tia_cycle)<68;

  x=A2600BeamXAt(a2600_tia_cycle);
  if (player)
    pos=a2600_p1_x;
  else
    pos=a2600_p0_x;

  if (!a2600_p_dyn_render[player] && !hblank &&
        A2600PlayerDecodeStart(A2600WrapX(x-1),pos,val))
    A2600PlayerDynStart(player);

  old_pattern=A2600PlayerDecodePattern(old_val);
  new_pattern=A2600PlayerDecodePattern(val);
  if (a2600_p_dyn_render[player] && old_pattern!=new_pattern) {
    delta=a2600_p_dyn_counter[player]+5;
    if (delta<2) {
      decode_x=A2600WrapX(x-delta-1);
      if (!A2600PlayerDecodeStart(decode_x,pos,val)) {
        a2600_p_dyn_render[player]=FALSE;
        a2600_p_dyn_change[player]=-1;
      }
    }
  }

  if (pending==a2600_p_dyn_divider[player])
    return;

  if (!a2600_p_dyn_render[player]) {
    a2600_p_dyn_change[player]=-1;
    A2600PlayerDynSetDivider(player,pending);
    if (!hblank) {
      if (player)
        delta=A2600PlayerRecentDecodeStart(A2600BeamXAt(a2600_tia_cycle),
              a2600_p1_x,val);
      else
        delta=A2600PlayerRecentDecodeStart(A2600BeamXAt(a2600_tia_cycle),
              a2600_p0_x,val);
      if (delta)
        A2600PlayerDynStart(player);
    }
    return;
  }

  delta=a2600_p_dyn_counter[player]+5;
  pair=(a2600_p_dyn_divider[player]<<4)|pending;
  if (pair==0x12 || pair==0x14) {
    if (hblank) {
      if (delta<4)
        A2600PlayerDynSetDivider(player,pending);
      else if (delta<5)
        a2600_p_dyn_change[player]=1;
      else
        a2600_p_dyn_change[player]=0;
    } else {
      if (delta<3)
        A2600PlayerDynSetDivider(player,pending);
      else
        a2600_p_dyn_change[player]=1;
    }
  } else if (pair==0x21 || pair==0x41) {
    if (hblank) {
      limit0=4;
      limit1=6;
    } else {
      limit0=3;
      limit1=5;
    }
    if (delta<limit0) {
      A2600PlayerDynSetDivider(player,pending);
    } else if (delta<limit1) {
      A2600PlayerDynSetDivider(player,pending);
      a2600_p_dyn_counter[player]--;
    } else {
      if (hblank)
        a2600_p_dyn_change[player]=0;
      else
        a2600_p_dyn_change[player]=1;
    }
  } else if (pair==0x42 || pair==0x24) {
    if (a2600_p_dyn_counter[player]<1 ||
          (hblank && (a2600_p_dyn_counter[player]%
          a2600_p_dyn_divider[player]==1))) {
      A2600PlayerDynSetDivider(player,pending);
    } else {
      a2600_p_dyn_change[player]=a2600_p_dyn_divider[player]-
            ((a2600_p_dyn_counter[player]-1)%
            a2600_p_dyn_divider[player]);
    }
  } else {
    A2600PlayerDynSetDivider(player,pending);
  }

}

U0 A2600PlayerDynAdvance(I64 player)
{
  player=player&1;
  if (!a2600_p_dyn_render[player])
    return;

  a2600_p_dyn_counter[player]++;
  if (a2600_p_dyn_divider[player]==1) {
    if (a2600_p_dyn_counter[player]>0)
      a2600_p_dyn_sample[player]++;
    if (a2600_p_dyn_counter[player]>=0 &&
          a2600_p_dyn_change[player]>=0) {
      if (a2600_p_dyn_change[player]==0)
        A2600PlayerDynSetDivider(player,a2600_p_dyn_pending[player]);
      a2600_p_dyn_change[player]--;
    }
  } else {
    if (a2600_p_dyn_counter[player]>1 &&
          (((a2600_p_dyn_counter[player]-1)&
          (a2600_p_dyn_divider[player]-1))==0))
      a2600_p_dyn_sample[player]++;
    if (a2600_p_dyn_counter[player]>0 &&
          a2600_p_dyn_change[player]>=0) {
      if (a2600_p_dyn_change[player]==0)
        A2600PlayerDynSetDivider(player,a2600_p_dyn_pending[player]);
      a2600_p_dyn_change[player]--;
    }
  }
  if (a2600_p_dyn_sample[player]>7)
    a2600_p_dyn_render[player]=0;
}

Bool A2600PlayerDynBit(I64 player,I64 x,I64 pos,I64 grp,I64 reflect,I64 nusiz)
{
  Bool on;
  I64 divider;

  player=player&1;
  if (!a2600_p_dyn_render[player] && A2600PlayerDecodeStart(x,pos,nusiz)) {
    divider=A2600PlayerDivider(nusiz);
    A2600PlayerDynSetDivider(player,divider);
    a2600_p_dyn_pending[player]=divider;
    A2600PlayerDynStart(player);
    return FALSE;
  }

  on=a2600_p_dyn_render[player] &&
        a2600_p_dyn_counter[player]>=a2600_p_dyn_trip[player] &&
        A2600PlayerPatternBit(a2600_p_dyn_sample[player],grp,reflect);
  A2600PlayerDynAdvance(player);
  return on;
}

Bool A2600MissileCopyBit(I64 x,I64 pos,I64 width)
{
  I64 dx;

  dx=x-pos;
  if (dx<0)
    dx+=A2600_FB_W;
  return dx>=0 && dx<width;
}

I64 A2600MissileVisibleStart(I64 pos)
{
  return A2600WrapX(pos+4);
}

Bool A2600MissileStarCopyBit(I64 player,I64 x,I64 start,I64 width)
{
  I64 phase;

  player=player&1;
  if (a2600_m_hmove_active[player] && width<4) {
    phase=(start+69)&3;
    if (phase==2)
      return FALSE;
    if (phase==3)
      return A2600MissileCopyBit(x,A2600WrapX(start-1),2);
  }
  return A2600MissileCopyBit(x,start,width);
}

I64 A2600MissileCopyMask(I64 nusiz)
{
  I64 mode,mask;

  mode=nusiz&7;
  mask=1;
  if (mode==1 || mode==3)
    mask=mask|2;
  if (mode==2 || mode==3 || mode==6)
    mask=mask|4;
  if (mode==4 || mode==6)
    mask=mask|8;
  return mask;
}

I64 A2600MissileWidth(I64 nusiz)
{
  return 1<<((nusiz>>4)&3);
}

I64 A2600MissileAgingDx(I64 x,I64 start,I64 width)
{
  I64 dx;

  dx=x-start;
  if (dx<0) {
    if (start+width>A2600_FB_W)
      dx+=A2600_FB_W;
    else
      return -1;
  }
  return dx;
}

I64 A2600MissileCopyStartX(I64 pos,I64 copy)
{
  if (copy==1)
    return A2600MissileVisibleStart(pos+16);
  if (copy==2)
    return A2600MissileVisibleStart(pos+32);
  if (copy==3)
    return A2600MissileVisibleStart(pos+64);
  return A2600MissileVisibleStart(pos);
}

Bool A2600MissileCopyDecodeFuture(I64 x,I64 start)
{
  if (start<5)
    return FALSE;
  return x<=start-5;
}

U0 A2600MissileDynBeginScanline()
{
  a2600_m_dyn_mask[0]=A2600MissileCopyMask(a2600_tia[A2600_NUSIZ0]);
  a2600_m_dyn_mask[1]=A2600MissileCopyMask(a2600_tia[A2600_NUSIZ1]);
  a2600_m_dyn_ended[0]=0;
  a2600_m_dyn_ended[1]=0;
}

U0 A2600BeginScanline()
{
  I64 old_motion;

  A2600BallDynBeginScanline;
  A2600PlayerDynBeginScanline;
  A2600MissileDynBeginScanline;
  a2600_pf_reflect_latch=a2600_tia[A2600_CTRLPF]&1;
  a2600_pf_reflect_mid_latched=0;
  a2600_m0_cosmic_graphics=0;
  if (a2600_m0_confused) {
    old_motion=a2600_m0_motion;
    a2600_m0_motion=17;
    a2600_m0_x=A2600WrapX(a2600_m0_x-a2600_m0_motion);
    a2600_m0_motion=old_motion;
    if ((a2600_tia[A2600_ENAM0]&2) && !(a2600_tia[A2600_RESMP0]&2)) {
      if ((a2600_cosmic_scanline&3)<2)
        a2600_m0_cosmic_graphics=0x40;
      else if ((a2600_cosmic_scanline&3)==2)
        a2600_m0_cosmic_graphics=0xC0;
      a2600_cosmic_scanline++;
    }
  }
}

U0 A2600MissileDynReset(I64 player)
{
  player=player&1;
  a2600_m_dyn_mask[player]=
        A2600MissileCopyMask(a2600_tia[A2600_NUSIZ0+player]);
  a2600_m_dyn_ended[player]=0;
}

U0 A2600MissileDynNUSIZWrite(I64 player,I64 val,I64 old_val)
{
  I64 x,pos,new_mask,mask,ended,bit,copy,start,new_width,dx;

  player=player&1;
  x=A2600BeamXAt(a2600_tia_cycle);
  if (player)
    pos=a2600_m1_x;
  else
    pos=a2600_m0_x;
  new_mask=A2600MissileCopyMask(val);
  if (a2600_vblank) {
    a2600_m_dyn_mask[player]=new_mask;
    a2600_m_dyn_ended[player]=0;
    return;
  }
  new_width=A2600MissileWidth(val);
  mask=a2600_m_dyn_mask[player];
  ended=a2600_m_dyn_ended[player];
  bit=1;
  for (copy=0;copy<4;copy++) {
    start=A2600MissileCopyStartX(pos,copy);
    if (A2600MissileCopyDecodeFuture(x,start)) {
      if (new_mask&bit) {
        mask=mask|bit;
        ended=ended & (0x0F-bit);
      } else {
        mask=mask & (0x0F-bit);
        ended=ended & (0x0F-bit);
      }
    } else if (mask&bit) {
      dx=A2600MissileAgingDx(x,start,new_width);
      if ((ended&bit) || (dx<80 && dx>=new_width))
        mask=mask & (0x0F-bit);
    }
    bit=bit<<1;
  }
  a2600_m_dyn_mask[player]=mask;
  a2600_m_dyn_ended[player]=ended&mask;
}

Bool A2600MissileMaskBit(I64 player,I64 x,I64 pos,I64 nusiz,I64 mask)
{
  I64 width,copy,bit,start;

  width=A2600MissileWidth(nusiz);
  bit=1;
  for (copy=0;copy<4;copy++) {
    if (mask&bit) {
      start=A2600MissileCopyStartX(pos,copy);
      if (A2600MissileStarCopyBit(player,x,start,width))
        return TRUE;
    }
    bit=bit<<1;
  }
  return FALSE;
}

Bool A2600MissileDynBit(I64 player,I64 x,I64 pos,I64 nusiz)
{
  Bool on;
  I64 width,copy,bit,start,dx,mask,ended;

  player=player&1;
  width=A2600MissileWidth(nusiz);
  mask=a2600_m_dyn_mask[player];
  ended=a2600_m_dyn_ended[player];
  on=FALSE;
  bit=1;
  for (copy=0;copy<4;copy++) {
    if (mask&bit) {
      start=A2600MissileCopyStartX(pos,copy);
      if (A2600MissileStarCopyBit(player,x,start,width))
        on=TRUE;
      dx=A2600MissileAgingDx(x,start,width);
      if (dx<80 && dx>=width-1)
        ended=ended|bit;
    }
    bit=bit<<1;
  }
  a2600_m_dyn_ended[player]=ended&mask;
  return on;
}

Bool A2600MissileBit(I64 x,I64 pos,I64 nusiz)
{
  I64 mode,width;

  mode=nusiz&7;
  width=A2600MissileWidth(nusiz);
  if (A2600MissileCopyBit(x,A2600MissileVisibleStart(pos),width))
    return TRUE;
  if (mode==1 || mode==3)
    if (A2600MissileCopyBit(x,A2600MissileVisibleStart(pos+16),width))
      return TRUE;
  if (mode==2 || mode==6)
    if (A2600MissileCopyBit(x,A2600MissileVisibleStart(pos+32),width))
      return TRUE;
  if (mode==3)
    if (A2600MissileCopyBit(x,A2600MissileVisibleStart(pos+32),width))
      return TRUE;
  if (mode==4 || mode==6)
    if (A2600MissileCopyBit(x,A2600MissileVisibleStart(pos+64),width))
      return TRUE;
  return FALSE;
}

Bool A2600M0Bit(I64 x,I64 pos,I64 nusiz)
{
  I64 dx;

  if (a2600_tia[A2600_RESMP0]&2)
    return FALSE;
  if (a2600_m0_confused) {
    dx=x-pos;
    if (dx<0)
      dx+=A2600_FB_W;
    if (a2600_m0_cosmic_graphics==0x40)
      return dx==5;
    if (a2600_m0_cosmic_graphics==0xC0)
      return dx==4 || dx==5;
    return FALSE;
  }
  return A2600MissileDynBit(0,x,pos,nusiz);
}

Bool A2600BallBit(I64 x)
{
  I64 width,en;

  if (!a2600_bl_dyn_alive)
    return FALSE;
  en=a2600_tia[A2600_ENABL];
  if (a2600_tia[A2600_VDELBL]&1)
    en=a2600_enabl_old;
  if (!(en&2))
    return FALSE;
  width=A2600BallWidth(a2600_tia[A2600_CTRLPF]);
  if (a2600_bl_hmove_active && width<4) {
    if (((a2600_bl_x+68)&3)==2)
      return FALSE;
    if (((a2600_bl_x+68)&3)==3)
      return A2600MissileCopyBit(x,A2600WrapX(a2600_bl_x-1),2);
  }
  return A2600MissileCopyBit(x,a2600_bl_x,width);
}

U0 A2600FinishFrame()
{
  if (!a2600_frame_done) {
    a2600_last_frame_scanlines=a2600_frame_scanline;
    a2600_frames++;
    A2600KidVidFrame;
    A2600CompuMateCheckCassetteTimeout;
    a2600_frame_done=TRUE;
  }
}

U0 A2600StartVisibleFrame()
{
  I64 i;

  for (i=0;i<A2600_FB_W*A2600_FB_H;i++)
    a2600_prev_fb[i]=a2600_fb[i];
  a2600_visible_active=TRUE;
  a2600_visible_y=0;
  a2600_scanline=0;
  a2600_line_x=0;
  a2600_hmove_cycle=0;
  a2600_m_hmove_active[0]=0;
  a2600_m_hmove_active[1]=0;
  a2600_hmove_blank_x=0;
  a2600_hmove_blank_next=0;
}

U0 A2600StopVisibleFrame()
{
  a2600_visible_active=FALSE;
}

U0 A2600LatchPrevFrame()
{
  I64 i;

  for (i=0;i<A2600_FB_W*A2600_FB_H;i++)
    a2600_prev_fb[i]=a2600_fb[i];
}

I64 A2600FrameExpectedLines()
{
  if (a2600_tv_format==A2600_TV_PAL ||
        a2600_tv_format==A2600_TV_SECAM ||
        a2600_tv_format==A2600_TV_NTSC50)
    return A2600_FM_PAL_LINES;
  return A2600_FM_NTSC_LINES;
}

I64 A2600FrameYStart()
{
  if (a2600_tv_format==A2600_TV_PAL ||
        a2600_tv_format==A2600_TV_SECAM ||
        a2600_tv_format==A2600_TV_NTSC50)
    return A2600_FM_PAL_YSTART;
  return A2600_FM_NTSC_YSTART;
}

I64 A2600FrameHeight()
{
  if (a2600_tv_format==A2600_TV_PAL ||
        a2600_tv_format==A2600_TV_SECAM ||
        a2600_tv_format==A2600_TV_NTSC50)
    return A2600_FM_PAL_HEIGHT;
  return A2600_FM_NTSC_HEIGHT;
}

U0 A2600FrameSetState(I64 state)
{
  I64 old_state;

  if (a2600_frame_state==state)
    return;
  old_state=a2600_frame_state;
  if (old_state==A2600_FM_FRAME && state!=A2600_FM_FRAME)
    A2600StopVisibleFrame;
  a2600_frame_state=state;
  a2600_frame_line_state=0;
  if (state==A2600_FM_WAIT_FRAME_START) {
    A2600FinishFrame;
    a2600_frame_scanline=0;
    a2600_frame_vsync_lines=0;
  } else if (state==A2600_FM_FRAME) {
    A2600StartVisibleFrame;
    a2600_frame_vsync_lines=0;
    a2600_frame_done=FALSE;
  }
}

U0 A2600FrameSetVsync(Bool on)
{
  if (on)
    A2600FrameSetState(A2600_FM_WAIT_VSYNC_END);
  else if (a2600_frame_state==A2600_FM_WAIT_VSYNC_END)
    A2600FrameSetState(A2600_FM_WAIT_FRAME_START);
}

U0 A2600FrameNextLine()
{
  a2600_frame_line_state++;
  switch (a2600_frame_state) {
    case A2600_FM_WAIT_VSYNC_START:
      if (a2600_frame_scanline>A2600FrameExpectedLines()-3 || !a2600_frames) {
        if (a2600_vblank || a2600_frame_scanline>A2600_FM_PAL_LINES*2)
          a2600_frame_vsync_lines++;
      }
      if (a2600_frame_vsync_lines>A2600_FM_MAX_VSYNC_LINES)
        A2600FrameSetState(A2600_FM_WAIT_FRAME_START);
      break;
    case A2600_FM_WAIT_VSYNC_END:
      if (a2600_vblank || a2600_frame_scanline>A2600_FM_PAL_LINES*2)
        a2600_frame_vsync_lines++;
      if (a2600_frame_vsync_lines>A2600_FM_MAX_VSYNC_LINES)
        A2600FrameSetState(A2600_FM_WAIT_FRAME_START);
      break;
    case A2600_FM_WAIT_FRAME_START:
      if (a2600_frame_line_state>=A2600FrameYStart())
        A2600FrameSetState(A2600_FM_FRAME);
      break;
    case A2600_FM_FRAME:
      if (a2600_frame_line_state>=A2600FrameHeight())
        A2600FrameSetState(A2600_FM_WAIT_VSYNC_START);
      break;
  }
}

U0 A2600AdvanceScanline()
{
  a2600_scanline++;
  a2600_frame_scanline++;
  A2600FrameNextLine;
}

U0 A2600AdvanceVisibleScanline()
{
  if (!a2600_visible_active)
    return;
  if (a2600_visible_y<A2600_FB_H) {
    a2600_visible_y++;
    if (a2600_visible_y>=A2600_FB_H)
      a2600_visible_active=FALSE;
  } else
    a2600_visible_active=FALSE;
}

I64 A2600PhosphorPixel(I64 off)
{
  I64 c,p;

  if (!a2600_display_phosphor)
    return A2600TIAColor(a2600_fb[off]);
  if (!a2600_phosphor_ready)
    A2600InitPhosphor;
  c=A2600TIAIndex(a2600_fb[off]);
  p=A2600TIAIndex(a2600_prev_fb[off]);
  return a2600_phosphor_color[c*A2600_TIA_COLOR_COUNT+p];
}

I64 A2600Z26CRCHardware(I64 data,I64 genpoly,I64 accum)
{
  I64 i;

  data=(data<<1)&0xFFFFFFFF;
  for (i=8;i>0;i--) {
    data=data>>1;
    if ((data^accum)&1)
      accum=((accum>>1)^genpoly)&0xFFFFFFFF;
    else
      accum=(accum>>1)&0xFFFFFFFF;
  }
  return accum&0xFFFFFFFF;
}

I64 A2600Z26CRC(U8 *data,I64 size)
{
  I64 i,crc;

  crc=0;
  if (!data || size<=0)
    return crc;
  for (i=0;i<size;i++)
    crc=((crc>>8)^A2600Z26CRCHardware((crc^data[i])&0xFF,
          A2600_Z26_CRC32_REV,0))&0xFFFFFFFF;
  return crc;
}

Bool A2600Z26CRCLookup(I64 crc,I64 *table)
{
  I64 i;

  crc=crc&0xFFFFFFFF;
  if (!table)
    return FALSE;
  for (i=0;table[i]>=0;i++)
    if ((table[i]&0xFFFFFFFF)==crc)
      return TRUE;
  return FALSE;
}

Bool A2600MemHas(U8 *data,I64 size,U8 *needle)
{
  I64 i,j,n,ok;

  if (!data || !needle)
    return FALSE;
  n=StrLen(needle);
  if (n<=0 || size<n)
    return FALSE;

  for (i=0;i<=size-n;i++) {
    ok=TRUE;
    for (j=0;j<n;j++) {
      if (data[i+j]!=needle[j]) {
        ok=FALSE;
        break;
      }
    }
    if (ok)
      return TRUE;
  }
  return FALSE;
}

U0 A2600ApplyControllerHints(I64 crc)
{
  A2600SetControllerDefaults;
  crc=crc&0xFFFFFFFF;
  if (A2600Z26CRCLookup(crc,a2600_z26_genesis_both)) {
    a2600_left_controller=A2600_CTRL_GENESIS;
    a2600_right_controller=A2600_CTRL_GENESIS;
  }
  if (A2600Z26CRCLookup(crc,a2600_z26_joy2b_both)) {
    a2600_left_controller=A2600_CTRL_JOY2B;
    a2600_right_controller=A2600_CTRL_JOY2B;
  }
  if (A2600Z26CRCLookup(crc,a2600_stella_atarivox_right))
    A2600SaveKeySetController(TRUE);
  if (crc==0x0FEBD060) {
    a2600_left_controller=A2600_CTRL_LIGHTGUN;
    a2600_controller_lightgun_adjust=7;
    a2600_controller_lightgun_vadjust=11;
  }
  if (crc==0x56E2D735) {
    a2600_left_controller=A2600_CTRL_LIGHTGUN;
    a2600_controller_lightgun_adjust=8;
    a2600_controller_lightgun_vadjust=0;
  }
  if (crc==0xDDE8600B) {
    a2600_left_controller=A2600_CTRL_LIGHTGUN;
    a2600_controller_lightgun_adjust=9;
    a2600_controller_lightgun_vadjust=5;
    a2600_controller_lightgun_wrap=75;
  }
}

U0 A2600ApplyCartControllerSignatures(U8 *data,I64 size)
{
  if (A2600MemHas(data,size,"ATARIVOX"))
    A2600SaveKeySetController(TRUE);
  else if (A2600MemHas(data,size,"SAVEKEY"))
    A2600SaveKeySetController(FALSE);
  if (A2600MemHas(data,size,"KIDVIDB"))
    A2600KidVidSetGame(A2600_KIDVID_BBEARS);
  else if (A2600MemHas(data,size,"KIDVID"))
    A2600KidVidSetGame(A2600_KIDVID_SMURFS);
  if (A2600MemHas(data,size,"KIDVID1"))
    A2600KidVidSelectTape(1);
  if (A2600MemHas(data,size,"KIDVID2"))
    A2600KidVidSelectTape(2);
  if (A2600MemHas(data,size,"KIDVID3"))
    A2600KidVidSelectTape(3);
  if (A2600MemHas(data,size,"KIDVID4"))
    A2600KidVidSelectTape(4);
  if (A2600MemHas(data,size,"COMPUMATE")) {
    a2600_left_controller=A2600_CTRL_COMPUMATE;
    a2600_right_controller=A2600_CTRL_COMPUMATE;
  }
  if (A2600MemHas(data,size,"MINDLINK")) {
    a2600_left_controller=A2600_CTRL_MINDLINK;
    a2600_right_controller=A2600_CTRL_MINDLINK;
  }
  if (A2600MemHas(data,size,"MLINKL"))
    a2600_left_controller=A2600_CTRL_MINDLINK;
  if (A2600MemHas(data,size,"MLINKR"))
    a2600_right_controller=A2600_CTRL_MINDLINK;
  if (A2600MemHas(data,size,"QUADTARI")) {
    a2600_left_controller=A2600_CTRL_QUADTARI;
    a2600_right_controller=A2600_CTRL_QUADTARI;
  }
}

Bool A2600StellaPhosphorCRC(I64 crc)
{
  return A2600Z26CRCLookup(crc,a2600_stella_phosphor_crc);
}

I64 A2600StellaTVFormatCRC(I64 crc)
{
  if (A2600Z26CRCLookup(crc,a2600_stella_tv_ntsc_crc))
    return A2600_TV_NTSC;
  if (A2600Z26CRCLookup(crc,a2600_stella_tv_pal_crc))
    return A2600_TV_PAL;
  if (A2600Z26CRCLookup(crc,a2600_stella_tv_ntsc50_crc))
    return A2600_TV_NTSC50;
  if (A2600Z26CRCLookup(crc,a2600_stella_tv_pal60_crc))
    return A2600_TV_PAL60;
  return A2600_TV_UNKNOWN;
}

Bool A2600TVUses50Hz()
{
  if (a2600_tv_format==A2600_TV_PAL)
    return TRUE;
  if (a2600_tv_format==A2600_TV_SECAM)
    return TRUE;
  if (a2600_tv_format==A2600_TV_NTSC50)
    return TRUE;
  return FALSE;
}

I64 A2600FrameRate()
{
  if (A2600TVUses50Hz())
    return 50;
  return 60;
}

U8 *A2600TVName()
{
  if (a2600_tv_format==A2600_TV_PAL)
    return "PAL";
  if (a2600_tv_format==A2600_TV_SECAM)
    return "SECAM";
  if (a2600_tv_format==A2600_TV_NTSC50)
    return "NTSC50";
  if (a2600_tv_format==A2600_TV_PAL60)
    return "PAL60";
  if (a2600_tv_format==A2600_TV_SECAM60)
    return "SECAM60";
  return "NTSC";
}

U0 A2600RenderSpan(I64 to_x)
{
  I64 x,off,bg,pf,p0,p1,c0,c1,c,pc,ctrl,priority,score,m0x,m1x;
  I64 actual_x;
  Bool play,p0on,p1on,m0on,m1on,blon;

  if (to_x<0)
    to_x=0;
  if (to_x>A2600_FB_W)
    to_x=A2600_FB_W;
  if (to_x<a2600_line_x) {
    actual_x=A2600BeamXAt(A2600AccessCycle());
    if (actual_x>=a2600_line_x) {
      A2600RenderSpan(actual_x);
      to_x=a2600_line_x;
    } else {
      A2600RenderSpan(A2600_FB_W);
      A2600ApplyPFPending(A2600_FB_W);
      a2600_line_x=0;
      a2600_m_hmove_active[0]=0;
      a2600_m_hmove_active[1]=0;
      a2600_bl_hmove_active=0;
      if (a2600_hmove_blank_next) {
        a2600_hmove_blank_x=8;
        a2600_hmove_blank_next=0;
      } else
        a2600_hmove_blank_x=0;
      a2600_hmove_cycle=0;
      A2600AdvanceVisibleScanline;
      A2600AdvanceScanline;
    }
  }
  if (to_x<=a2600_line_x)
    return;
  if (a2600_line_x==0)
    A2600BeginScanline;

  bg=a2600_tia[A2600_COLUBK];
  pf=a2600_tia[A2600_COLUPF];
  p0=a2600_tia[A2600_GRP0];
  p1=a2600_tia[A2600_GRP1];
  if (a2600_tia[A2600_VDELP0]&1)
    p0=a2600_grp0_old;
  if (a2600_tia[A2600_VDELP1]&1)
    p1=a2600_grp1_old;
  c0=a2600_tia[A2600_COLUP0];
  c1=a2600_tia[A2600_COLUP1];
  m0x=a2600_m0_x;
  m1x=a2600_m1_x;
  if (a2600_tia[A2600_RESMP0]&2)
    m0x=A2600WrapX(a2600_p0_x+
          A2600MissileLockOffset(a2600_tia[A2600_NUSIZ0]));
  if (a2600_tia[A2600_RESMP1]&2)
    m1x=A2600WrapX(a2600_p1_x+
          A2600MissileLockOffset(a2600_tia[A2600_NUSIZ1]));

  if (a2600_visible_active && a2600_visible_y<A2600_FB_H) {
    off=a2600_visible_y*A2600_FB_W;
    if (a2600_vblank) {
      for (x=a2600_line_x;x<to_x;x++)
        a2600_fb[off+x]=0;
    } else {
      ctrl=a2600_tia[A2600_CTRLPF];
      priority=ctrl&4;
      score=(ctrl&6)==2;
      for (x=a2600_line_x;x<to_x;x++) {
        if (x==79)
          A2600LatchPFReflectMid;
        A2600ApplyPFPending(x);
        c=bg;
        pc=pf;
        if (score) {
          if (x<A2600_SCORE_SPLIT_X)
            pc=c0;
          else
            pc=c1;
        }

        play=A2600PFBit(x);
        p0on=A2600PlayerDynBit(0,x,a2600_p0_x,p0,a2600_tia[A2600_REFP0],
              a2600_tia[A2600_NUSIZ0]);
        p1on=A2600PlayerDynBit(1,x,a2600_p1_x,p1,a2600_tia[A2600_REFP1],
              a2600_tia[A2600_NUSIZ1]);
        m0on=(a2600_tia[A2600_ENAM0]&2) &&
              A2600M0Bit(x,m0x,a2600_tia[A2600_NUSIZ0]);
        m1on=(a2600_tia[A2600_ENAM1]&2) &&
              !(a2600_tia[A2600_RESMP1]&2) &&
              A2600MissileDynBit(1,x,m1x,a2600_tia[A2600_NUSIZ1]);
        blon=A2600BallBit(x);
        A2600NoteCollisions(play,p0on,p1on,m0on,m1on,blon);

        if (priority) {
          if (play)
            c=pc;
          else if (blon)
            c=pf;
          else if (p0on || m0on)
            c=c0;
          else if (p1on || m1on)
            c=c1;
        } else if (score) {
          if (p0on || m0on)
            c=c0;
          else if (play)
            c=pc;
          else if (p1on || m1on)
            c=c1;
          else if (blon)
            c=pf;
        } else {
          if (p0on || m0on)
            c=c0;
          else if (p1on || m1on)
            c=c1;
          else if (play)
            c=pc;
          else if (blon)
            c=pf;
        }

        if (x<a2600_hmove_blank_x)
          c=0;
        a2600_fb[off+x]=c;
      }
    }
  }
  if (to_x>=A2600_FB_W)
    A2600ApplyPFPending(A2600_FB_W);
  if (to_x>=a2600_hmove_blank_x)
    a2600_hmove_blank_x=0;
  a2600_line_x=to_x;
}

U0 A2600CatchUpTIARead()
{
  A2600RenderSpan(A2600BeamDelayXAt(A2600AccessCycle(),2));
}

U0 A2600CatchUpTIABus()
{
  A2600RenderSpan(A2600BeamXAt(A2600AccessCycle()));
}

U0 A2600RenderScanline()
{
  A2600RenderSpan(A2600_FB_W);
  a2600_line_x=0;
  if (a2600_hmove_blank_next) {
    a2600_hmove_blank_x=8;
    a2600_hmove_blank_next=0;
  } else
    a2600_hmove_blank_x=0;
  a2600_hmove_cycle=0;
  A2600AdvanceVisibleScanline;
  A2600AdvanceScanline;
}

U0 A2600RSync()
{
  I64 x,off;

  if (a2600_visible_active && a2600_visible_y<A2600_FB_H) {
    off=a2600_visible_y*A2600_FB_W;
    for (x=a2600_line_x;x<A2600_FB_W;x++)
      a2600_fb[off+x]=0;
  }
  A2600ApplyPFPending(A2600_FB_W);
  a2600_line_x=0;
  if (a2600_hmove_blank_next) {
    a2600_hmove_blank_x=8;
    a2600_hmove_blank_next=0;
  } else
    a2600_hmove_blank_x=0;
  a2600_hmove_cycle=0;
  A2600AdvanceVisibleScanline;
  A2600AdvanceScanline;
}

U0 A2600AudioReset()
{
  I64 i;

  for (i=0;i<2;i++) {
    a2600_audio_d6[i]=0;
    a2600_audio_p4[i]=0;
    a2600_audio_p5[i]=0;
    a2600_audio_p9[i]=1;
    a2600_audio_out[i]=0;
    a2600_audio_div_cnt[i]=0;
    a2600_audio_div_max[i]=0;
    a2600_audio_clock_enable[i]=0;
    a2600_audio_noise_feedback[i]=0;
    a2600_audio_noise_bit4[i]=0;
    a2600_audio_pulse_hold[i]=0;
    a2600_audio_div_counter[i]=0;
    a2600_audio_pulse_counter[i]=0;
    a2600_audio_noise_counter[i]=0;
  }
  a2600_audio_sample=0;
  a2600_audio_ona=0;
  a2600_audio_chan=-1;
  a2600_audio_freq=0;
  a2600_audio_next_cycle=0;
  a2600_audio_counter=0;
  a2600_audio_sum0=0;
  a2600_audio_sum1=0;
  a2600_audio_sum_ct=0;
}

I64 A2600AudioVol(I64 chan)
{
  if (chan&1)
    return a2600_tia[A2600_AUDV1]&0x0F;
  return a2600_tia[A2600_AUDV0]&0x0F;
}

I64 A2600AudioDivisor(I64 audc)
{
  audc=audc&0x0F;
  if (audc==6 || audc==10 || audc==14)
    return 31;
  if (audc==12 || audc==13 || audc==15)
    return 6;
  return 1;
}

F64 A2600AudioFreq(I64 chan)
{
  I64 audc,audf,audv,div;

  if (chan&1) {
    audc=a2600_tia[A2600_AUDC1]&0x0F;
    audf=a2600_tia[A2600_AUDF1]&0x1F;
    audv=a2600_tia[A2600_AUDV1]&0x0F;
  } else {
    audc=a2600_tia[A2600_AUDC0]&0x0F;
    audf=a2600_tia[A2600_AUDF0]&0x1F;
    audv=a2600_tia[A2600_AUDV0]&0x0F;
  }

  if (!audv || !audc)
    return 0;
  div=A2600AudioDivisor(audc);
  return 31400.0/(2.0*(audf+1)*div);
}

I64 A2600AudioActualVol(I64 chan)
{
  chan=chan&1;
  return (a2600_audio_pulse_counter[chan]&1)*A2600AudioVol(chan);
}

U0 A2600AudioUpdateChan(I64 chan)
{
  chan=chan&1;
  a2600_audio_out[chan]=A2600AudioActualVol(chan);
}

U0 A2600AudioPhase0Chan(I64 chan)
{
  I64 audc,audf;

  chan=chan&1;
  if (chan) {
    audc=a2600_tia[A2600_AUDC1]&0x0F;
    audf=a2600_tia[A2600_AUDF1]&0x1F;
  } else {
    audc=a2600_tia[A2600_AUDC0]&0x0F;
    audf=a2600_tia[A2600_AUDF0]&0x1F;
  }

  if (a2600_audio_clock_enable[chan]) {
    a2600_audio_noise_bit4[chan]=a2600_audio_noise_counter[chan]&1;

    switch (audc&3) {
      case 0:
      case 1:
        a2600_audio_pulse_hold[chan]=0;
        break;
      case 2:
        a2600_audio_pulse_hold[chan]=
              ((a2600_audio_noise_counter[chan]&0x1E)!=0x02);
        break;
      case 3:
        a2600_audio_pulse_hold[chan]=!a2600_audio_noise_bit4[chan];
        break;
    }

    if ((audc&3)==0) {
      if (((a2600_audio_pulse_counter[chan]^
              a2600_audio_noise_counter[chan])&1) ||
            !(a2600_audio_noise_counter[chan] ||
              (a2600_audio_pulse_counter[chan]!=0x0A)) ||
            !(audc&0x0C))
        a2600_audio_noise_feedback[chan]=1;
      else
        a2600_audio_noise_feedback[chan]=0;
    } else {
      if ((((a2600_audio_noise_counter[chan]&4)!=0) ^
              (a2600_audio_noise_counter[chan]&1)) ||
            !a2600_audio_noise_counter[chan])
        a2600_audio_noise_feedback[chan]=1;
      else
        a2600_audio_noise_feedback[chan]=0;
    }
  }

  a2600_audio_clock_enable[chan]=(a2600_audio_div_counter[chan]==audf);
  if (a2600_audio_div_counter[chan]==audf ||
        a2600_audio_div_counter[chan]==0x1F)
    a2600_audio_div_counter[chan]=0;
  else
    a2600_audio_div_counter[chan]++;
}

U0 A2600AudioPhase1Chan(I64 chan)
{
  I64 audc,pulse_feedback;

  chan=chan&1;
  if (chan)
    audc=a2600_tia[A2600_AUDC1]&0x0F;
  else
    audc=a2600_tia[A2600_AUDC0]&0x0F;

  if (a2600_audio_clock_enable[chan]) {
    pulse_feedback=0;
    switch (audc>>2) {
      case 0:
        pulse_feedback=((((a2600_audio_pulse_counter[chan]&2)!=0) ^
              (a2600_audio_pulse_counter[chan]&1)) &&
              a2600_audio_pulse_counter[chan]!=0x0A &&
              (audc&3));
        break;
      case 1:
        pulse_feedback=!(a2600_audio_pulse_counter[chan]&8);
        break;
      case 2:
        pulse_feedback=!a2600_audio_noise_bit4[chan];
        break;
      case 3:
        pulse_feedback=!((a2600_audio_pulse_counter[chan]&2) ||
              !(a2600_audio_pulse_counter[chan]&0x0E));
        break;
    }

    a2600_audio_noise_counter[chan]=a2600_audio_noise_counter[chan]>>1;
    if (a2600_audio_noise_feedback[chan])
      a2600_audio_noise_counter[chan]=a2600_audio_noise_counter[chan]|0x10;

    if (!a2600_audio_pulse_hold[chan]) {
      a2600_audio_pulse_counter[chan]=
            (~(a2600_audio_pulse_counter[chan]>>1))&7;
      if (pulse_feedback)
        a2600_audio_pulse_counter[chan]=
              a2600_audio_pulse_counter[chan]|8;
    }
  }
  a2600_audio_out[chan]=A2600AudioActualVol(chan);
}

U0 A2600AudioCreateSample()
{
  I64 sample0,sample1;

  if (a2600_audio_sum_ct>0) {
    sample0=a2600_audio_sum0/a2600_audio_sum_ct;
    sample1=a2600_audio_sum1/a2600_audio_sum_ct;
  } else {
    sample0=A2600AudioActualVol(0);
    sample1=A2600AudioActualVol(1);
  }

  a2600_audio_sum0=0;
  a2600_audio_sum1=0;
  a2600_audio_sum_ct=0;
  a2600_audio_out[0]=sample0&0x0F;
  a2600_audio_out[1]=sample1&0x0F;

  if (a2600_cart_type==A2600_CART_DPC) {
    a2600_audio_sample=((a2600_dpc_audv&0x0F)<<3)+
          (a2600_audio_out[1]&0x0F);
  } else
    a2600_audio_sample=(a2600_audio_out[0]+a2600_audio_out[1])&0xFF;
}

U0 A2600AudioTick()
{
  a2600_audio_sum0+=A2600AudioActualVol(0);
  a2600_audio_sum1+=A2600AudioActualVol(1);
  a2600_audio_sum_ct++;

  switch (a2600_audio_counter) {
    case 9:
    case 81:
      A2600AudioPhase0Chan(0);
      A2600AudioPhase0Chan(1);
      break;
    case 37:
    case 149:
      A2600AudioPhase1Chan(0);
      A2600AudioPhase1Chan(1);
      A2600AudioCreateSample;
      break;
  }

  a2600_audio_counter++;
  if (a2600_audio_counter>=228)
    a2600_audio_counter=0;
}

I64 A2600AudioClockSample()
{
  I64 i;

  for (i=0;i<114;i++)
    A2600AudioTick;
  return a2600_audio_sample;
}

U0 A2600AudioCatchUp(I64 target_cycle)
{
  I64 guard=0,target_cc;

  target_cc=target_cycle*3;
  while (a2600_audio_next_cycle<=target_cc && guard<768) {
    A2600AudioTick;
    a2600_audio_next_cycle++;
    guard++;
  }
  if (guard>=768 && a2600_audio_next_cycle<target_cc)
    a2600_audio_next_cycle=target_cc+1;
}

U0 A2600AudioUpdateHost()
{
  I64 v0,v1,chan,ona;
  F64 freq;

  v0=a2600_tia[A2600_AUDV0]&0x0F;
  v1=a2600_tia[A2600_AUDV1]&0x0F;
  if (v1>v0)
    chan=1;
  else
    chan=0;
  freq=A2600AudioFreq(chan);
  if (freq<=0) {
    chan=1-chan;
    freq=A2600AudioFreq(chan);
  }
  if (freq<=0) {
    if (a2600_audio_ona)
      Snd;
    a2600_audio_ona=0;
    a2600_audio_chan=-1;
    a2600_audio_freq=0;
    return;
  }

  ona=Freq2Ona(freq);
  if (ona!=a2600_audio_ona)
    Snd(ona);
  a2600_audio_ona=ona;
  a2600_audio_chan=chan;
  a2600_audio_freq=freq;
}

U0 A2600TrakBallClear()
{
  a2600_trakball_count_h=0;
  a2600_trakball_count_v=0;
  a2600_trakball_pending_h=0;
  a2600_trakball_pending_v=0;
  a2600_trakball_lines_h=1;
  a2600_trakball_lines_v=1;
  a2600_trakball_scan_h=0;
  a2600_trakball_scan_v=0;
  a2600_trakball_left=0;
  a2600_trakball_down=0;
}

U0 A2600TrakBallPort(I64 port)
{
  a2600_trakball_port=port&1;
  if (!a2600_trakball_mode)
    a2600_trakball_mode=1;
  if (a2600_trakball_port&1)
    a2600_right_controller=A2600_CTRL_TRAKBALL;
  else
    a2600_left_controller=A2600_CTRL_TRAKBALL;
}

U0 A2600TrakBallMode(I64 mode)
{
  if (mode<0)
    mode=0;
  if (mode>3)
    mode=3;
  a2600_trakball_mode=mode;
  if (mode==0) {
    if (a2600_trakball_port&1)
      a2600_right_controller=A2600_CTRL_JS;
    else
      a2600_left_controller=A2600_CTRL_JS;
  } else if (mode==1) {
    if (a2600_trakball_port&1)
      a2600_right_controller=A2600_CTRL_TRAKBALL;
    else
      a2600_left_controller=A2600_CTRL_TRAKBALL;
  } else if (mode==2) {
    if (a2600_trakball_port&1)
      a2600_right_controller=A2600_CTRL_ST_MOUSE;
    else
      a2600_left_controller=A2600_CTRL_ST_MOUSE;
  } else if (mode==3) {
    if (a2600_trakball_port&1)
      a2600_right_controller=A2600_CTRL_AMIGA_MOUSE;
    else
      a2600_left_controller=A2600_CTRL_AMIGA_MOUSE;
  }
}

U0 A2600TrakBallQueue(I64 steps_h,I64 steps_v,I64 left,I64 down,I64 lines)
{
  if (!a2600_trakball_mode)
    a2600_trakball_mode=1;
  if (steps_h<0)
    steps_h=-steps_h;
  if (steps_v<0)
    steps_v=-steps_v;
  if (lines<1)
    lines=1;
  a2600_trakball_pending_h=steps_h;
  a2600_trakball_pending_v=steps_v;
  a2600_trakball_left=left&1;
  a2600_trakball_down=down&1;
  a2600_trakball_lines_h=lines;
  a2600_trakball_lines_v=lines;
  a2600_trakball_scan_h=0;
  a2600_trakball_scan_v=0;
}

U0 A2600TrakBallUpdate()
{
  I64 scan;

  if (!a2600_trakball_mode)
    return;
  scan=a2600_scanline;
  if (a2600_trakball_scan_h>scan)
    a2600_trakball_scan_h=0;
  if (a2600_trakball_scan_v>scan)
    a2600_trakball_scan_v=0;
  if (a2600_trakball_lines_h<1)
    a2600_trakball_lines_h=1;
  if (a2600_trakball_lines_v<1)
    a2600_trakball_lines_v=1;

  while (a2600_trakball_scan_h+a2600_trakball_lines_h<scan) {
    if (a2600_trakball_pending_h>0) {
      if (a2600_trakball_left)
        a2600_trakball_count_h--;
      else
        a2600_trakball_count_h++;
      a2600_trakball_pending_h--;
    }
    a2600_trakball_scan_h+=a2600_trakball_lines_h;
  }

  while (a2600_trakball_scan_v+a2600_trakball_lines_v<scan) {
    if (a2600_trakball_pending_v>0) {
      if (a2600_trakball_down)
        a2600_trakball_count_v--;
      else
        a2600_trakball_count_v++;
      a2600_trakball_pending_v--;
    }
    a2600_trakball_scan_v+=a2600_trakball_lines_v;
  }

  a2600_trakball_count_h=a2600_trakball_count_h&3;
  a2600_trakball_count_v=a2600_trakball_count_v&3;
}

I64 A2600TrakBallPins(I64 pins)
{
  I64 h,v,p;

  if (!a2600_trakball_mode)
    return pins;
  if (a2600_trakball_mode==2) {
    h=a2600_trakball_count_h&3;
    v=a2600_trakball_count_v&3;
    p=a2600_trakball_st_h[h] | a2600_trakball_st_v[v];
  } else if (a2600_trakball_mode==3) {
    h=a2600_trakball_count_h&3;
    v=a2600_trakball_count_v&3;
    p=a2600_trakball_am_h[h] | a2600_trakball_am_v[v];
  } else {
    h=(a2600_trakball_count_h&1)*2+(a2600_trakball_left&1);
    v=(a2600_trakball_count_v&1)*2+(a2600_trakball_down&1);
    p=a2600_trakball_tb_h[h] | a2600_trakball_tb_v[v];
  }
  if (a2600_trakball_both)
    return (pins&0x00) | p | (p>>4);
  if (a2600_trakball_port&1)
    return (pins&0xF0) | (p>>4);
  return (pins&0x0F) | p;
}

I64 A2600Read(I64 addr)
{
  I64 a,r,v,old_access_active,old_access_cycle;

  old_access_active=a2600_access_cycle_active;
  old_access_cycle=a2600_access_cycle;
  if (a2600_cpu_bus_active && !a2600_access_cycle_active) {
    a2600_access_cycle_active=TRUE;
    a2600_access_cycle=a2600_cycles+a2600_cpu_bus_cycle;
    a2600_cpu_bus_cycle++;
  }

  a=addr & 0x1FFF; // 6507 exposes 13 address lines; z26 mirrors this space.
  if (a>=0x80)
    A2600CatchUpTIABus;
  A2600SCObserveAddr(a);
  A2600UAHot(a);
  A2600MZHot(a);
  A2600MZTEHot(a);
  A2600SBHot(a);
  A2600MDMHot(a);
  A2600TVBoyHot(a);
  A2600WDMaybeSwitch;
  if (A2600GLIsLowPage(a)) {
    v=A2600GLReadLow(a);
    A2600FEAccess(a,v);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return v;
  }
  if (a2600_cart_type==A2600_CART_0840)
    A2600CartHot(a);

  if (a>=0x1000) {
    v=A2600ReadCart(a);
    A2600FEAccess(a,v);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return v;
  }

  if ((a&0x0280)==0x0280) {
    A2600PA7Access;
    r=a&0x07;
    if (r==0) {
      A2600TrakBallUpdate;
      a2600_swcha=A2600TrakBallPins(a2600_swcha);
      a2600_swcha=A2600QuadTariPins(a2600_swcha);
      a2600_swcha=A2600SaveKeyPins(a2600_swcha);
      a2600_swcha=A2600KidVidPins(a2600_swcha);
      a2600_swcha=A2600CompuMatePins(a2600_swcha);
      v=A2600Bus(a2600_swcha);
    }
    else if (r==1)
      v=A2600Bus(a2600_swach_dir);
    else if (r==2)
      v=A2600Bus(a2600_swchb);
    else if (r==3)
      v=A2600Bus(a2600_swbch_dir);
    else if (r==4 || r==6)
      v=A2600Bus(A2600TimerValue());
    else if (r==5 || r==7)
      v=A2600Bus(A2600TimerStatus());
    else
      v=A2600Bus(0xFF);
    A2600X07Hot(a);
    A26004A50Access(a,v);
    A2600FEAccess(a,v);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return v;
  }

  if (a&0x80) {
    v=A2600Bus(a2600_ram[a & 0x7F]);
    A2600X07Hot(a);
    A26004A50Access(a,v);
    A2600FEAccess(a,v);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return v;
  }

  A2600CatchUpTIARead;
  r=a&0x0F;
  if (r<8)
    v=A2600Bus((a2600_bus&0x3F)|a2600_coll[r]);
  else if (r>=8 && r<=0x0B)
    v=A2600Bus((a2600_bus&0x3F)|A2600AnalogINPT(r-8));
  else if (r==0x0C)
    v=A2600Bus((a2600_bus&0x3F)|A2600INPT4());
  else if (r==0x0D)
    v=A2600Bus((a2600_bus&0x3F)|A2600INPT5());
  else
    v=A2600Bus(a2600_bus&0x3F);
  A2600X07Hot(a);
  A2600WDReadHot(a);
  A26004A50Access(a,v);
  A2600FEAccess(a,v);
  a2600_access_cycle_active=old_access_active;
  a2600_access_cycle=old_access_cycle;
  return v;
}

U0 A2600TIAWrite(I64 tia_addr,I64 val)
{
  I64 r,render_x,old_val,write_cycle;
  I64 old_vblank=a2600_vblank;
  I64 old_vsync;
  r=tia_addr & 0x3F;
  old_val=a2600_tia[r];
  old_vsync=a2600_tia[A2600_VSYNC]&0x02;
  write_cycle=A2600AccessCycle();
  if (r==A2600_COLUP0 || r==A2600_COLUP1 ||
        r==A2600_COLUPF || r==A2600_COLUBK)
    val=val&0xFE;
  if (r==A2600_AUDC0 || r==A2600_AUDC1)
    val=val&0x0F;
  if (r==A2600_AUDF0 || r==A2600_AUDF1)
    val=val&0x1F;
  if (r==A2600_AUDV0 || r==A2600_AUDV1)
    val=val&0x0F;

  render_x=A2600BeamXAt(a2600_tia_cycle);
  if (r==A2600_REFP0 || r==A2600_REFP1)
    render_x=A2600BeamDelayXAt(a2600_tia_cycle,2);
  else if (r==A2600_GRP0 || r==A2600_GRP1 ||
        r==A2600_ENAM0 || r==A2600_ENAM1 || r==A2600_ENABL ||
        r==A2600_COLUPF || r==A2600_COLUBK || r==A2600_VBLANK)
    render_x=A2600BeamDelayXAt(a2600_tia_cycle,1);

  if (r!=A2600_WSYNC && r!=A2600_VSYNC && r!=A2600_HMCLR)
    A2600RenderSpan(render_x);

  if (r==A2600_PF0 || r==A2600_PF1 || r==A2600_PF2) {
    if (a2600_vblank || a2600_visible_y>=A2600_FB_H)
      a2600_tia[r]=val;
    else
      A2600QueuePFWrite(r,val,A2600PFDelayX(a2600_tia_cycle));
    return;
  }

  if (r==A2600_CTRLPF && render_x>=79 && !a2600_vblank &&
        a2600_visible_active &&
        a2600_visible_y<A2600_FB_H)
    A2600LatchPFReflectMid;

  a2600_tia[r]=val;
  if (r>=A2600_AUDC0 && r<=A2600_AUDV1) {
    if (r==A2600_AUDC1 || r==A2600_AUDF1 || r==A2600_AUDV1)
      A2600AudioUpdateChan(1);
    else
      A2600AudioUpdateChan(0);
    A2600AudioUpdateHost;
  }

  switch (r) {
    case A2600_VSYNC:
      if ((val&0x02) && !old_vsync) {
        a2600_vsync_frame_mode=TRUE;
        a2600_frame_done=FALSE;
        A2600FrameSetVsync(TRUE);
      }
      if (old_vsync && !(val&0x02)) {
        a2600_vsync_frame_mode=TRUE;
        A2600FrameSetVsync(FALSE);
      }
      break;
    case A2600_VBLANK:
      A2600AnalogVBlank(val);
      A2600InputLatchVBlank(val);
      a2600_vblank=val&0x02;
      if (!a2600_vblank && !a2600_vsync_frame_mode &&
            (old_vblank || a2600_visible_y>=A2600_FB_H)) {
        A2600StartVisibleFrame;
        a2600_frame_done=FALSE;
      }
      if (!old_vblank && a2600_vblank && !a2600_frame_done &&
            !a2600_vsync_frame_mode) {
        A2600FinishFrame;
        a2600_frame_scanline=0;
      }
      break;
    case A2600_WSYNC:
      A2600RenderScanline;
      a2600_wsync_target=((a2600_tia_cycle/76)+1)*76;
      a2600_wsync_pending=TRUE;
      break;
    case A2600_RSYNC:
      A2600RSync;
      a2600_cycles=((a2600_tia_cycle/76)+1)*76;
      break;
    case A2600_NUSIZ0:
      A2600PlayerDynNUSIZWrite(0,val,old_val);
      A2600MissileDynNUSIZWrite(0,val,old_val);
      break;
    case A2600_NUSIZ1:
      A2600PlayerDynNUSIZWrite(1,val,old_val);
      A2600MissileDynNUSIZWrite(1,val,old_val);
      break;
    case A2600_RESP0:
      a2600_p0_x=A2600RespXAt(write_cycle,a2600_p0_motion);
      A2600UpdateM0LockFromRESP(write_cycle);
      break;
    case A2600_RESP1:
      a2600_p1_x=A2600RespXAt(write_cycle,a2600_p1_motion);
      A2600UpdateM1LockFromRESP(write_cycle);
      break;
    case A2600_RESM0:
      a2600_m0_x=A2600RespXAt(write_cycle,a2600_m0_motion);
      A2600MissileDynReset(0);
      break;
    case A2600_RESM1:
      a2600_m1_x=A2600RespXAt(write_cycle,a2600_m1_motion);
      A2600MissileDynReset(1);
      break;
    case A2600_RESBL:
      a2600_bl_x=A2600RespXAt(write_cycle,a2600_bl_motion);
      A2600BallDynReset;
      break;
    case A2600_CTRLPF:
      A2600BallDynCTRLPFWrite(val,old_val);
      break;
    case A2600_GRP0:
      a2600_grp1_old=a2600_tia[A2600_GRP1];
      break;
    case A2600_GRP1:
      a2600_grp0_old=a2600_tia[A2600_GRP0];
      a2600_enabl_old=a2600_tia[A2600_ENABL];
      break;
    case A2600_RESMP0:
      if (val&2)
        a2600_m0_x=A2600WrapX(a2600_p0_x+
              A2600MissileLockOffset(a2600_tia[A2600_NUSIZ0]));
      A2600MissileDynReset(0);
      break;
    case A2600_RESMP1:
      if (val&2)
        a2600_m1_x=A2600WrapX(a2600_p1_x+
              A2600MissileLockOffset(a2600_tia[A2600_NUSIZ1]));
      A2600MissileDynReset(1);
      break;
    case A2600_HMP0:
      A2600ApplyDeepHMOVE(0,old_val,val);
      break;
    case A2600_HMP1:
      A2600ApplyDeepHMOVE(1,old_val,val);
      break;
    case A2600_HMM0:
      if (a2600_hmove_cycle==3 &&
            A2600CPUCycleAt(write_cycle)==24 &&
            a2600_m0_motion==7 && val==0x60) {
        a2600_m0_confused=1;
        a2600_cosmic_scanline=1;
        a2600_m0_motion=2;
        a2600_m0_x=A2600WrapX(a2600_m0_x-a2600_m0_motion);
      }
      A2600ApplyDeepHMOVE(2,old_val,val);
      break;
    case A2600_HMM1:
      A2600ApplyDeepHMOVE(3,old_val,val);
      break;
    case A2600_HMBL:
      A2600ApplyDeepHMOVE(4,old_val,val);
      break;
    case A2600_HMOVE:
      a2600_hmove_cycle=A2600CPUCycleAt(write_cycle);
      if (a2600_m0_confused) {
        a2600_m0_confused=0;
        a2600_m0_cosmic_graphics=0;
      }
      a2600_p0_motion=A2600HMOVEMotion(a2600_tia[A2600_HMP0],a2600_hmove_cycle);
      a2600_p1_motion=A2600HMOVEMotion(a2600_tia[A2600_HMP1],a2600_hmove_cycle);
      a2600_m0_motion=A2600HMOVEMotion(a2600_tia[A2600_HMM0],a2600_hmove_cycle);
      a2600_m1_motion=A2600HMOVEMotion(a2600_tia[A2600_HMM1],a2600_hmove_cycle);
      a2600_bl_motion=A2600HMOVEMotion(a2600_tia[A2600_HMBL],a2600_hmove_cycle);
      if (A2600HMOVEApplies(a2600_hmove_cycle)) {
        a2600_m_hmove_active[0]=1;
        a2600_m_hmove_active[1]=1;
        a2600_bl_hmove_active=1;
      }
      if (a2600_hmove_cycle<=20)
        a2600_hmove_blank_x=8;
      else if (a2600_hmove_cycle>74)
        a2600_hmove_blank_next=1;
      if (A2600HMOVEApplies(a2600_hmove_cycle)) {
        a2600_p0_x=A2600WrapX(a2600_p0_x-a2600_p0_motion);
        a2600_p1_x=A2600WrapX(a2600_p1_x-a2600_p1_motion);
        a2600_m0_x=A2600WrapX(a2600_m0_x-a2600_m0_motion);
        a2600_m1_x=A2600WrapX(a2600_m1_x-a2600_m1_motion);
        a2600_bl_x=A2600WrapX(a2600_bl_x-a2600_bl_motion);
        A2600UpdateMissileLocks;
      }
      break;
    case A2600_HMCLR:
      if (a2600_hmove_cycle==3 &&
            A2600CPUCycleAt(write_cycle)==23 &&
            a2600_m0_motion==7) {
        a2600_m0_confused=1;
        a2600_cosmic_scanline=1;
      }
      A2600ApplyDeepHMOVE(0,a2600_tia[A2600_HMP0],0);
      A2600ApplyDeepHMOVE(1,a2600_tia[A2600_HMP1],0);
      A2600ApplyDeepHMOVE(2,a2600_tia[A2600_HMM0],0);
      A2600ApplyDeepHMOVE(3,a2600_tia[A2600_HMM1],0);
      A2600ApplyDeepHMOVE(4,a2600_tia[A2600_HMBL],0);
      a2600_tia[A2600_HMP0]=0;
      a2600_tia[A2600_HMP1]=0;
      a2600_tia[A2600_HMM0]=0;
      a2600_tia[A2600_HMM1]=0;
      a2600_tia[A2600_HMBL]=0;
      break;
    case A2600_CXCLR:
      A2600ClearCollisions;
      break;
  }
}

U0 A2600Write(I64 addr,I64 val)
{
  I64 a,r,banks2,old_access_active,old_access_cycle;

  old_access_active=a2600_access_cycle_active;
  old_access_cycle=a2600_access_cycle;
  if (a2600_cpu_bus_active && !a2600_access_cycle_active) {
    a2600_access_cycle_active=TRUE;
    a2600_access_cycle=a2600_cycles+a2600_cpu_bus_cycle;
    a2600_cpu_bus_cycle++;
  }
  a2600_bus=val&0xFF;
  a=addr & 0x1FFF;
  if (a>=0x80)
    A2600CatchUpTIABus;
  A2600SCObserveAddr(a);
  A2600UAHot(a);
  A2600MZHot(a);
  A2600MZTEHot(a);
  A2600SBHot(a);
  A2600MDMHot(a);
  A2600TVBoyHot(a);
  A2600WDMaybeSwitch;
  if (a2600_cart_type==A2600_CART_0840)
    A2600CartHot(a);

  if (a>=0x1000) {
    A2600WriteCart(a,val);
    A2600FEAccess(a,val);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return;
  }

  if ((a&0x0280)==0x0280) {
    A2600PA7Access;
    r=a&0x1F;
    if (r==0 || r==8 || r==16 || r==24) {
      a2600_swcha_out=val&0xFF;
      A2600SaveKeyUpdatePins;
      A2600MindlinkSWCHAWrite(val);
      if (a2600_cart_type==A2600_CART_CM)
        A2600CompuMateWriteSWCHA(val);
    }
    if (r==1 || r==9 || r==17 || r==25) {
      a2600_swach_dir=val&0xFF;
      A2600SaveKeyUpdatePins;
    }
    if (r==2 || r==10 || r==18 || r==26)
      a2600_swchb_out=val&0xFF;
    if (r==3 || r==11 || r==19 || r==27)
      a2600_swbch_dir=val&0xFF;
    if (r<4 || (r>=8 && r<12) || (r>=16 && r<20) || (r>=24 && r<28))
      A2600PollInput(FALSE);
    if ((r&0x04) && !(r&0x10))
      a2600_pa7_edge_positive=r&1;
    if (r==20 || r==28)
      A2600SetTimer(val,1);
    if (r==21 || r==29)
      A2600SetTimer(val,8);
    if (r==22 || r==30)
      A2600SetTimer(val,64);
    if (r==23 || r==31)
      A2600SetTimer(val,1024);
    A2600X07Hot(a);
    A26004A50Access(a,val);
    A2600FEAccess(a,val);
    a2600_access_cycle_active=old_access_active;
    a2600_access_cycle=old_access_cycle;
    return;
  }

  if (a&0x80)
    a2600_ram[a & 0x7F]=val;
  else {
    if (a<=0x3F) {
      if (a2600_cart_type==A2600_CART_3F) {
        banks2=A2600Cart2KBanks;
        a2600_cart_seg0=(val&0xFF)%banks2;
      }
      if (a2600_cart_type==A2600_CART_3E) {
        banks2=A2600Cart2KBanks;
        if (a==0x3F) {
          a2600_cart_seg0=(val&0xFF)%banks2;
          a2600_cart_ram_mode=0;
        } else if (a==0x3E) {
          a2600_cart_seg0=val&31;
          a2600_cart_ram_mode=1;
        }
      }
      if (a2600_cart_type==A2600_CART_3EX) {
        banks2=A2600Cart2KBanks;
        if (a==0x3F) {
          a2600_cart_seg0=(val&0xFF)%banks2;
          a2600_cart_ram_mode=0;
        } else if (a==0x3E) {
          a2600_cart_seg0=val&0xFF;
          a2600_cart_ram_mode=1;
        }
      }
      if (a2600_cart_type==A2600_CART_3EP)
        A2600Cart3EPHot(a,val);
    }
    A2600TIAWrite(a,val);
  }
  A2600X07Hot(a);
  A26004A50Access(a,val);
  A2600FEAccess(a,val);
  a2600_access_cycle_active=old_access_active;
  a2600_access_cycle=old_access_cycle;
}

U0 A2600WriteAt(I64 addr,I64 val,I64 cyc)
{
  I64 old_cycle,old_access_active,old_access_cycle;
  old_cycle=a2600_tia_cycle;
  old_access_active=a2600_access_cycle_active;
  old_access_cycle=a2600_access_cycle;
  a2600_tia_cycle=a2600_cycles+cyc;
  a2600_access_cycle_active=TRUE;
  a2600_access_cycle=a2600_tia_cycle;
  A2600Write(addr,val);
  if (a2600_cpu_bus_active && a2600_cpu_bus_cycle<=cyc)
    a2600_cpu_bus_cycle=cyc+1;
  a2600_access_cycle_active=old_access_active;
  a2600_access_cycle=old_access_cycle;
  a2600_tia_cycle=old_cycle;
}

U0 A2600RMWWriteAt(I64 addr,I64 old_val,I64 new_val,I64 cyc)
{
  old_val=old_val&0xFF;
  new_val=new_val&0xFF;
  A2600WriteAt(addr,old_val,cyc-1);
  A2600WriteAt(addr,new_val,cyc);
}

I64 A2600Fetch()
{
  I64 res=A2600Read(a2600_pc);
  a2600_pc=(a2600_pc+1)&0xFFFF;
  return res;
}

I64 A2600IndX(I64 zp)
{
  I64 ptr;
  A2600Read(zp&0xFF);
  ptr=(zp+a2600_x)&0xFF;
  return A2600Read(ptr)+(A2600Read((ptr+1)&0xFF)<<8);
}

I64 A2600ZPIndexed(I64 zp,I64 idx)
{
  A2600Read(zp&0xFF);
  return (zp+idx)&0xFF;
}

I64 A2600IndY(I64 zp)
{
  return A2600Read(zp)+(A2600Read((zp+1)&0xFF)<<8)+a2600_y;
}

I64 A2600ReadAbsIndexed(I64 base,I64 idx)
{
  I64 sum,dummy;

  sum=(base&0xFF)+(idx&0xFF);
  if (sum>0xFF) {
    dummy=(base&0xFF00)|(sum&0xFF);
    A2600Read(dummy);
  }
  return A2600Read((base+idx)&0xFFFF);
}

I64 A2600ReadIndY(I64 zp)
{
  I64 base;

  base=A2600Read(zp)+(A2600Read((zp+1)&0xFF)<<8);
  return A2600ReadAbsIndexed(base,a2600_y);
}

I64 A2600WriteAbsIndexed(I64 base,I64 idx)
{
  I64 dummy;

  dummy=(base&0xFF00)|((base+idx)&0xFF);
  A2600Read(dummy);
  return (base+idx)&0xFFFF;
}

I64 A2600WriteIndY(I64 zp)
{
  I64 base;

  base=A2600Read(zp)+(A2600Read((zp+1)&0xFF)<<8);
  return A2600WriteAbsIndexed(base,a2600_y);
}

I64 A2600PageCross(I64 base,I64 addr)
{
  if ((base&0xFF00)!=(addr&0xFF00))
    return 1;
  return 0;
}

I64 A2600Branch(Bool cond)
{
  I64 rel,old_pc,new_pc,dummy,page_cross;
  rel=A2600Fetch();
  if (cond) {
    old_pc=a2600_pc;
    if (rel&0x80)
      rel=rel-0x100;
    new_pc=(a2600_pc+rel)&0xFFFF;
    A2600Read(old_pc);
    page_cross=A2600PageCross(old_pc,new_pc);
    if (page_cross) {
      dummy=(old_pc&0xFF00)|(new_pc&0xFF);
      A2600Read(dummy);
    }
    a2600_pc=new_pc;
    return 1+page_cross;
  }
  return 0;
}

U0 A2600Push(I64 v)
{
  A2600Write(0x100+(a2600_sp&0xFF),v);
  a2600_sp=(a2600_sp-1)&0xFF;
}

I64 A2600PullData()
{
  a2600_sp=(a2600_sp+1)&0xFF;
  return A2600Read(0x100+(a2600_sp&0xFF));
}

I64 A2600Pull()
{
  A2600Read(0x100+(a2600_sp&0xFF));
  return A2600PullData();
}

U0 A2600SetC(Bool set)
{
  if (set)
    a2600_p=a2600_p | A2600_F_C;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_C);
}

I64 A2600ASLVal(I64 v)
{
  v=v&0xFF;
  A2600SetC(v&0x80);
  v=(v<<1)&0xFF;
  A2600SetZN(v);
  return v;
}

I64 A2600LSRVal(I64 v)
{
  v=v&0xFF;
  A2600SetC(v&1);
  v=(v>>1)&0x7F;
  A2600SetZN(v);
  return v;
}

I64 A2600ROLVal(I64 v)
{
  I64 c;
  v=v&0xFF;
  c=a2600_p&A2600_F_C;
  A2600SetC(v&0x80);
  v=((v<<1)|c)&0xFF;
  A2600SetZN(v);
  return v;
}

I64 A2600RORVal(I64 v)
{
  I64 c;
  v=v&0xFF;
  if (a2600_p&A2600_F_C)
    c=0x80;
  else
    c=0;
  A2600SetC(v&1);
  v=((v>>1)|c)&0xFF;
  A2600SetZN(v);
  return v;
}

U0 A2600OpSLO(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=A2600ASLVal(old);
  A2600RMWWriteAt(addr,old,v,cyc);
  a2600_a=(a2600_a|v)&0xFF;
  A2600SetZN(a2600_a);
}

U0 A2600OpRLA(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=A2600ROLVal(old);
  A2600RMWWriteAt(addr,old,v,cyc);
  a2600_a=(a2600_a&v)&0xFF;
  A2600SetZN(a2600_a);
}

U0 A2600OpSRE(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=A2600LSRVal(old);
  A2600RMWWriteAt(addr,old,v,cyc);
  a2600_a=(a2600_a^v)&0xFF;
  A2600SetZN(a2600_a);
}

U0 A2600OpRRA(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=A2600RORVal(old);
  A2600RMWWriteAt(addr,old,v,cyc);
  A2600ADC(v);
}

U0 A2600OpDCP(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=(old-1)&0xFF;
  A2600RMWWriteAt(addr,old,v,cyc);
  A2600Cmp(a2600_a,v);
}

U0 A2600OpISB(I64 addr,I64 cyc)
{
  I64 old,v;
  old=A2600Read(addr);
  v=(old+1)&0xFF;
  A2600RMWWriteAt(addr,old,v,cyc);
  A2600SBC(v);
}

U0 A2600LAX(I64 v)
{
  a2600_a=v&0xFF;
  a2600_x=a2600_a;
  A2600SetZN(a2600_a);
}

U0 A2600ANC(I64 v)
{
  a2600_a=(a2600_a&v)&0xFF;
  A2600SetZN(a2600_a);
  A2600SetC(a2600_a&0x80);
}

U0 A2600ALR(I64 v)
{
  a2600_a=(a2600_a&v)&0xFF;
  a2600_a=A2600LSRVal(a2600_a);
}

U0 A2600ARR(I64 v)
{
  I64 a,old_c,lo,hi;

  old_c=a2600_p&A2600_F_C;
  a=(a2600_a&v)&0xFF;
  if (old_c)
    a=(a>>1)|0x80;
  else
    a=a>>1;

  if (!(a2600_p&A2600_F_D)) {
    a2600_a=a&0xFF;
    A2600SetZN(a2600_a);
    A2600SetC(a2600_a&0x40);
    if (((a2600_a&0x40)^((a2600_a&0x20)<<1))&0x40)
      a2600_p=a2600_p | A2600_F_V;
    else
      a2600_p=a2600_p & (0xFF - A2600_F_V);
    return;
  }

  lo=(a2600_a&v)&0x0F;
  hi=((a2600_a&v)>>4)&0x0F;
  a2600_a=a&0xFF;
  A2600SetZN(a2600_a);
  if (((a2600_a&0x40)^((a2600_a&0x20)<<1))&0x40)
    a2600_p=a2600_p | A2600_F_V;
  else
    a2600_p=a2600_p & (0xFF - A2600_F_V);
  if (lo+(lo&1)>5)
    a2600_a=(a2600_a&0xF0)|((a2600_a+6)&0x0F);
  if (hi+(hi&1)>5) {
    a2600_a=(a2600_a+0x60)&0xFF;
    A2600SetC(TRUE);
  } else
    A2600SetC(FALSE);
}

U0 A2600ANE(I64 v)
{
  a2600_a=((a2600_a|0xEE)&a2600_x&v)&0xFF;
  A2600SetZN(a2600_a);
}

U0 A2600LXA(I64 v)
{
  a2600_a=((a2600_a|0xEE)&v)&0xFF;
  a2600_x=a2600_a;
  A2600SetZN(a2600_a);
}

U0 A2600SBX(I64 v)
{
  I64 t;
  t=(a2600_a&a2600_x)&0xFF;
  A2600SetC(t>=(v&0xFF));
  a2600_x=(t-v)&0xFF;
  A2600SetZN(a2600_x);
}

U0 A2600LAS(I64 v)
{
  a2600_a=(a2600_sp&v)&0xFF;
  a2600_x=a2600_a;
  a2600_sp=a2600_a;
  A2600SetZN(a2600_a);
}

I64 A2600StoreHigh(I64 addr)
{
  return ((addr+0x100)>>8)&0xFF;
}

U0 A2600Step()
{
  I64 lo,hi,addr,op,old;

  if (a2600_halted)
    return;

  a2600_cpu_bus_active=1;
  a2600_cpu_bus_cycle=1;
  a2600_last_pc=a2600_pc;
  op=A2600Fetch();
  a2600_last_op=op;
  a2600_steps++;

  switch (op) {
    case 0x00: // BRK
      A2600Read(a2600_pc);
      a2600_pc=(a2600_pc+1)&0xFFFF;
      A2600Push(a2600_pc>>8);
      A2600Push(a2600_pc&0xFF);
      A2600Push((a2600_p|A2600_F_B|0x20)&0xFF);
      a2600_p=(a2600_p|A2600_F_I|0x20)&0xFF;
      a2600_pc=A2600Read(0xFFFE)+(A2600Read(0xFFFF)<<8);
      a2600_cycles+=7;
      break;
    case 0x02: case 0x12: case 0x22: case 0x32:
    case 0x42: case 0x52: case 0x62: case 0x72:
    case 0x92: case 0xB2: case 0xD2: case 0xF2: // JAM/KIL
      if (!A2600SCJAM()) {
        a2600_halt_reason=A2600_HALT_JAM;
        a2600_halted=TRUE;
      }
      break;
    case 0x1A: case 0x3A: case 0x5A: case 0x7A:
    case 0xDA: case 0xFA: // NOP implied
      a2600_cycles+=2;
      break;
    case 0x80: case 0x82: case 0x89:
    case 0xC2: case 0xE2: // NOP #imm
      A2600Fetch();
      a2600_cycles+=2;
      break;
    case 0x04: case 0x44: case 0x64: // NOP zp
      addr=A2600Fetch();
      A2600Read(addr);
      a2600_cycles+=3;
      break;
    case 0x14: case 0x34: case 0x54:
    case 0x74: case 0xD4: case 0xF4: // NOP zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600Read(addr);
      a2600_cycles+=4;
      break;
    case 0x0C: // NOP abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600Read(lo+(hi<<8));
      a2600_cycles+=4;
      break;
    case 0x1C: case 0x3C: case 0x5C:
    case 0x7C: case 0xDC: case 0xFC: // NOP abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600ReadAbsIndexed(addr,a2600_x);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0x03: // SLO (zp,X)
      addr=A2600Fetch();
      A2600OpSLO(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0x07: // SLO zp
      addr=A2600Fetch();
      A2600OpSLO(addr,5);
      a2600_cycles+=5;
      break;
    case 0x0F: // SLO abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSLO(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0x13: // SLO (zp),Y
      addr=A2600Fetch();
      A2600OpSLO(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0x17: // SLO zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpSLO(addr,6);
      a2600_cycles+=6;
      break;
    case 0x1B: // SLO abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSLO(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0x1F: // SLO abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSLO(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0x0B: case 0x2B: // ANC #imm
      A2600ANC(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0x23: // RLA (zp,X)
      addr=A2600Fetch();
      A2600OpRLA(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0x27: // RLA zp
      addr=A2600Fetch();
      A2600OpRLA(addr,5);
      a2600_cycles+=5;
      break;
    case 0x2F: // RLA abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRLA(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0x33: // RLA (zp),Y
      addr=A2600Fetch();
      A2600OpRLA(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0x37: // RLA zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpRLA(addr,6);
      a2600_cycles+=6;
      break;
    case 0x3B: // RLA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRLA(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0x3F: // RLA abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRLA(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0x40: // RTI
      A2600Read(0x100+(a2600_sp&0xFF));
      a2600_p=A2600PullData()|0x20;
      lo=A2600PullData(); hi=A2600PullData();
      a2600_pc=(lo+(hi<<8))&0xFFFF;
      a2600_cycles+=6;
      break;
    case 0x43: // SRE (zp,X)
      addr=A2600Fetch();
      A2600OpSRE(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0x47: // SRE zp
      addr=A2600Fetch();
      A2600OpSRE(addr,5);
      a2600_cycles+=5;
      break;
    case 0x4B: // ALR/ASR #imm
      A2600ALR(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0x4F: // SRE abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSRE(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0x53: // SRE (zp),Y
      addr=A2600Fetch();
      A2600OpSRE(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0x57: // SRE zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpSRE(addr,6);
      a2600_cycles+=6;
      break;
    case 0x5B: // SRE abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSRE(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0x5F: // SRE abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpSRE(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0x63: // RRA (zp,X)
      addr=A2600Fetch();
      A2600OpRRA(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0x67: // RRA zp
      addr=A2600Fetch();
      A2600OpRRA(addr,5);
      a2600_cycles+=5;
      break;
    case 0x6B: // ARR #imm
      A2600ARR(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0x6F: // RRA abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRRA(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0x73: // RRA (zp),Y
      addr=A2600Fetch();
      A2600OpRRA(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0x77: // RRA zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpRRA(addr,6);
      a2600_cycles+=6;
      break;
    case 0x7B: // RRA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRRA(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0x7F: // RRA abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpRRA(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0x83: // SAX (zp,X)
      addr=A2600Fetch();
      A2600WriteAt(A2600IndX(addr),a2600_a&a2600_x,6);
      a2600_cycles+=6;
      break;
    case 0x87: // SAX zp
      addr=A2600Fetch();
      A2600WriteAt(addr,a2600_a&a2600_x,3);
      a2600_cycles+=3;
      break;
    case 0x8B: // ANE #imm
      A2600ANE(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0x8F: // SAX abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(lo+(hi<<8),a2600_a&a2600_x,4);
      a2600_cycles+=4;
      break;
    case 0x93: // SHA (zp),Y
      addr=A2600Fetch();
      addr=A2600WriteIndY(addr);
      A2600WriteAt(addr,A2600StoreHigh(addr)&a2600_a&a2600_x,6);
      a2600_cycles+=6;
      break;
    case 0x97: // SAX zp,Y
      addr=A2600ZPIndexed(A2600Fetch(),a2600_y);
      A2600WriteAt(addr,a2600_a&a2600_x,4);
      a2600_cycles+=4;
      break;
    case 0x9B: // SHS/TAS abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_y);
      a2600_sp=(a2600_a&a2600_x)&0xFF;
      A2600WriteAt(addr,A2600StoreHigh(addr)&a2600_a&a2600_x,5);
      a2600_cycles+=5;
      break;
    case 0x9C: // SHY abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      A2600WriteAt(addr,A2600StoreHigh(addr)&a2600_y,5);
      a2600_cycles+=5;
      break;
    case 0x9E: // SHX abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_y);
      A2600WriteAt(addr,A2600StoreHigh(addr)&a2600_x,5);
      a2600_cycles+=5;
      break;
    case 0x9F: // SHA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_y);
      A2600WriteAt(addr,A2600StoreHigh(addr)&a2600_a&a2600_x,5);
      a2600_cycles+=5;
      break;
    case 0xA3: // LAX (zp,X)
      addr=A2600Fetch();
      A2600LAX(A2600Read(A2600IndX(addr)));
      a2600_cycles+=6;
      break;
    case 0xA7: // LAX zp
      addr=A2600Fetch();
      A2600LAX(A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0xAB: // LXA #imm
      A2600LXA(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0xAF: // LAX abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600LAX(A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0xB3: // LAX (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      A2600LAX(A2600ReadAbsIndexed(lo,a2600_y));
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xB7: // LAX zp,Y
      addr=A2600ZPIndexed(A2600Fetch(),a2600_y);
      A2600LAX(A2600Read(addr));
      a2600_cycles+=4;
      break;
    case 0xBB: // LAS abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600LAS(A2600ReadAbsIndexed(addr,a2600_y));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xBF: // LAX abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600LAX(A2600ReadAbsIndexed(addr,a2600_y));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xC3: // DCP (zp,X)
      addr=A2600Fetch();
      A2600OpDCP(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0xC7: // DCP zp
      addr=A2600Fetch();
      A2600OpDCP(addr,5);
      a2600_cycles+=5;
      break;
    case 0xCB: // SBX/AXS #imm
      A2600SBX(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0xCF: // DCP abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpDCP(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0xD3: // DCP (zp),Y
      addr=A2600Fetch();
      A2600OpDCP(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0xD7: // DCP zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpDCP(addr,6);
      a2600_cycles+=6;
      break;
    case 0xDB: // DCP abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpDCP(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0xDF: // DCP abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpDCP(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0xE3: // ISB (zp,X)
      addr=A2600Fetch();
      A2600OpISB(A2600IndX(addr),8);
      a2600_cycles+=8;
      break;
    case 0xE7: // ISB zp
      addr=A2600Fetch();
      A2600OpISB(addr,5);
      a2600_cycles+=5;
      break;
    case 0xEB: // SBC #imm unofficial
      A2600SBC(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0xEF: // ISB abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpISB(lo+(hi<<8),6);
      a2600_cycles+=6;
      break;
    case 0xF3: // ISB (zp),Y
      addr=A2600Fetch();
      A2600OpISB(A2600WriteIndY(addr),8);
      a2600_cycles+=8;
      break;
    case 0xF7: // ISB zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600OpISB(addr,6);
      a2600_cycles+=6;
      break;
    case 0xFB: // ISB abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpISB(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),7);
      a2600_cycles+=7;
      break;
    case 0xFF: // ISB abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600OpISB(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),7);
      a2600_cycles+=7;
      break;
    case 0x18: // CLC
      a2600_p=a2600_p & (0xFF - A2600_F_C);
      a2600_cycles+=2;
      break;
    case 0x38: // SEC
      a2600_p=a2600_p | A2600_F_C;
      a2600_cycles+=2;
      break;
    case 0x78: // SEI
      a2600_p=a2600_p | A2600_F_I;
      a2600_cycles+=2;
      break;
    case 0x58: // CLI
      a2600_p=a2600_p & (0xFF - A2600_F_I);
      a2600_cycles+=2;
      break;
    case 0xD8: // CLD
      a2600_p=a2600_p & (0xFF - A2600_F_D);
      a2600_cycles+=2;
      break;
    case 0xF8: // SED
      a2600_p=a2600_p | A2600_F_D;
      a2600_cycles+=2;
      break;
    case 0xB8: // CLV
      a2600_p=a2600_p & (0xFF - A2600_F_V);
      a2600_cycles+=2;
      break;
    case 0xEA: // NOP
      a2600_cycles+=2;
      break;
    case 0x48: // PHA
      A2600Push(a2600_a);
      a2600_cycles+=3;
      break;
    case 0x68: // PLA
      a2600_a=A2600Pull();
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x08: // PHP
      lo=(a2600_p|A2600_F_B|0x20)&0xFF;
      A2600Push(lo);
      a2600_cycles+=3;
      break;
    case 0x28: // PLP
      lo=A2600Pull();
      a2600_p=lo|0x20;
      a2600_cycles+=4;
      break;
    case 0x0A: // ASL A
      if (a2600_a&0x80)
        a2600_p=a2600_p | A2600_F_C;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_C);
      a2600_a=(a2600_a<<1)&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x06: // ASL zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=A2600ASLVal(old);
      A2600RMWWriteAt(addr,old,lo,5);
      a2600_cycles+=5;
      break;
    case 0x16: // ASL zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=A2600ASLVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x0E: // ASL abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=A2600ASLVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x1E: // ASL abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=A2600ASLVal(old);
      A2600RMWWriteAt(addr,old,lo,7);
      a2600_cycles+=7;
      break;
    case 0x4A: // LSR A
      if (a2600_a&1)
        a2600_p=a2600_p | A2600_F_C;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_C);
      a2600_a=(a2600_a>>1)&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x46: // LSR zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=A2600LSRVal(old);
      A2600RMWWriteAt(addr,old,lo,5);
      a2600_cycles+=5;
      break;
    case 0x56: // LSR zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=A2600LSRVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x4E: // LSR abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=A2600LSRVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x5E: // LSR abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=A2600LSRVal(old);
      A2600RMWWriteAt(addr,old,lo,7);
      a2600_cycles+=7;
      break;
    case 0x2A: // ROL A
      lo=a2600_p&A2600_F_C;
      if (a2600_a&0x80)
        a2600_p=a2600_p | A2600_F_C;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_C);
      a2600_a=((a2600_a<<1)|lo)&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x26: // ROL zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=A2600ROLVal(old);
      A2600RMWWriteAt(addr,old,lo,5);
      a2600_cycles+=5;
      break;
    case 0x36: // ROL zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=A2600ROLVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x2E: // ROL abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=A2600ROLVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x3E: // ROL abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=A2600ROLVal(old);
      A2600RMWWriteAt(addr,old,lo,7);
      a2600_cycles+=7;
      break;
    case 0x6A: // ROR A
      lo=a2600_p&A2600_F_C;
      if (a2600_a&1)
        a2600_p=a2600_p | A2600_F_C;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_C);
      a2600_a=(a2600_a>>1)|(lo<<7);
      a2600_a=a2600_a&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x66: // ROR zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=A2600RORVal(old);
      A2600RMWWriteAt(addr,old,lo,5);
      a2600_cycles+=5;
      break;
    case 0x76: // ROR zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=A2600RORVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x6E: // ROR abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=A2600RORVal(old);
      A2600RMWWriteAt(addr,old,lo,6);
      a2600_cycles+=6;
      break;
    case 0x7E: // ROR abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=A2600RORVal(old);
      A2600RMWWriteAt(addr,old,lo,7);
      a2600_cycles+=7;
      break;
    case 0xA9: // LDA #imm
      a2600_a=A2600Fetch();
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0xA5: // LDA zp
      addr=A2600Fetch();
      a2600_a=A2600Read(addr);
      A2600SetZN(a2600_a);
      a2600_cycles+=3;
      break;
    case 0xB5: // LDA zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      a2600_a=A2600Read(addr);
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0xAD: // LDA abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_a=A2600Read(lo+(hi<<8));
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0xBD: // LDA abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=A2600ReadAbsIndexed(addr,a2600_x);
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0xB9: // LDA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=A2600ReadAbsIndexed(addr,a2600_y);
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xA1: // LDA (zp,X)
      addr=A2600Fetch();
      a2600_a=A2600Read(A2600IndX(addr));
      A2600SetZN(a2600_a);
      a2600_cycles+=6;
      break;
    case 0xB1: // LDA (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      a2600_a=A2600ReadAbsIndexed(lo,a2600_y);
      A2600SetZN(a2600_a);
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xA0: // LDY #imm
      a2600_y=A2600Fetch();
      A2600SetZN(a2600_y);
      a2600_cycles+=2;
      break;
    case 0xA4: // LDY zp
      addr=A2600Fetch();
      a2600_y=A2600Read(addr);
      A2600SetZN(a2600_y);
      a2600_cycles+=3;
      break;
    case 0xB4: // LDY zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      a2600_y=A2600Read(addr);
      A2600SetZN(a2600_y);
      a2600_cycles+=4;
      break;
    case 0xAC: // LDY abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_y=A2600Read(lo+(hi<<8));
      A2600SetZN(a2600_y);
      a2600_cycles+=4;
      break;
    case 0xBC: // LDY abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_y=A2600ReadAbsIndexed(addr,a2600_x);
      A2600SetZN(a2600_y);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0xA2: // LDX #imm
      a2600_x=A2600Fetch();
      A2600SetZN(a2600_x);
      a2600_cycles+=2;
      break;
    case 0xA6: // LDX zp
      addr=A2600Fetch();
      a2600_x=A2600Read(addr);
      A2600SetZN(a2600_x);
      a2600_cycles+=3;
      break;
    case 0xB6: // LDX zp,Y
      addr=A2600ZPIndexed(A2600Fetch(),a2600_y);
      a2600_x=A2600Read(addr);
      A2600SetZN(a2600_x);
      a2600_cycles+=4;
      break;
    case 0xAE: // LDX abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_x=A2600Read(lo+(hi<<8));
      A2600SetZN(a2600_x);
      a2600_cycles+=4;
      break;
    case 0xBE: // LDX abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_x=A2600ReadAbsIndexed(addr,a2600_y);
      A2600SetZN(a2600_x);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xAA: // TAX
      a2600_x=a2600_a&0xFF;
      A2600SetZN(a2600_x);
      a2600_cycles+=2;
      break;
    case 0xA8: // TAY
      a2600_y=a2600_a&0xFF;
      A2600SetZN(a2600_y);
      a2600_cycles+=2;
      break;
    case 0x8A: // TXA
      a2600_a=a2600_x&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x98: // TYA
      a2600_a=a2600_y&0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x9A: // TXS
      a2600_sp=a2600_x&0xFF;
      a2600_cycles+=2;
      break;
    case 0xBA: // TSX
      a2600_x=a2600_sp&0xFF;
      A2600SetZN(a2600_x);
      a2600_cycles+=2;
      break;
    case 0x85: // STA zp
      addr=A2600Fetch();
      A2600WriteAt(addr,a2600_a,3);
      a2600_cycles+=3;
      break;
    case 0x95: // STA zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600WriteAt(addr,a2600_a,4);
      a2600_cycles+=4;
      break;
    case 0x86: // STX zp
      addr=A2600Fetch();
      A2600WriteAt(addr,a2600_x,3);
      a2600_cycles+=3;
      break;
    case 0x96: // STX zp,Y
      addr=A2600ZPIndexed(A2600Fetch(),a2600_y);
      A2600WriteAt(addr,a2600_x,4);
      a2600_cycles+=4;
      break;
    case 0x8E: // STX abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(lo+(hi<<8),a2600_x,4);
      a2600_cycles+=4;
      break;
    case 0x84: // STY zp
      addr=A2600Fetch();
      A2600WriteAt(addr,a2600_y,3);
      a2600_cycles+=3;
      break;
    case 0x94: // STY zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600WriteAt(addr,a2600_y,4);
      a2600_cycles+=4;
      break;
    case 0x8C: // STY abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(lo+(hi<<8),a2600_y,4);
      a2600_cycles+=4;
      break;
    case 0x8D: // STA abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(lo+(hi<<8),a2600_a,4);
      a2600_cycles+=4;
      break;
    case 0x9D: // STA abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(A2600WriteAbsIndexed(lo+(hi<<8),a2600_x),a2600_a,5);
      a2600_cycles+=5;
      break;
    case 0x99: // STA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600WriteAt(A2600WriteAbsIndexed(lo+(hi<<8),a2600_y),a2600_a,5);
      a2600_cycles+=5;
      break;
    case 0x81: // STA (zp,X)
      addr=A2600Fetch();
      A2600WriteAt(A2600IndX(addr),a2600_a,6);
      a2600_cycles+=6;
      break;
    case 0x91: // STA (zp),Y
      addr=A2600Fetch();
      A2600WriteAt(A2600WriteIndY(addr),a2600_a,6);
      a2600_cycles+=6;
      break;
    case 0xE6: // INC zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=(old+1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,5);
      A2600SetZN(lo);
      a2600_cycles+=5;
      break;
    case 0xF6: // INC zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=(old+1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,6);
      A2600SetZN(lo);
      a2600_cycles+=6;
      break;
    case 0xEE: // INC abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=(old+1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,6);
      A2600SetZN(lo);
      a2600_cycles+=6;
      break;
    case 0xFE: // INC abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=(old+1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,7);
      A2600SetZN(lo);
      a2600_cycles+=7;
      break;
    case 0xC6: // DEC zp
      addr=A2600Fetch();
      old=A2600Read(addr);
      lo=(old-1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,5);
      A2600SetZN(lo);
      a2600_cycles+=5;
      break;
    case 0xD6: // DEC zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      old=A2600Read(addr);
      lo=(old-1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,6);
      A2600SetZN(lo);
      a2600_cycles+=6;
      break;
    case 0xCE: // DEC abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      old=A2600Read(addr);
      lo=(old-1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,6);
      A2600SetZN(lo);
      a2600_cycles+=6;
      break;
    case 0xDE: // DEC abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600WriteAbsIndexed(lo+(hi<<8),a2600_x);
      old=A2600Read(addr);
      lo=(old-1)&0xFF;
      A2600RMWWriteAt(addr,old,lo,7);
      A2600SetZN(lo);
      a2600_cycles+=7;
      break;
    case 0x29: // AND #imm
      a2600_a=a2600_a & A2600Fetch();
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x25: // AND zp
      addr=A2600Fetch();
      a2600_a=a2600_a & A2600Read(addr);
      A2600SetZN(a2600_a);
      a2600_cycles+=3;
      break;
    case 0x2D: // AND abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_a=a2600_a & A2600Read(lo+(hi<<8));
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x35: // AND zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      a2600_a=a2600_a & A2600Read(addr);
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x3D: // AND abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a & A2600ReadAbsIndexed(addr,a2600_x);
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0x39: // AND abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a & A2600ReadAbsIndexed(addr,a2600_y);
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0x21: // AND (zp,X)
      addr=A2600Fetch();
      a2600_a=a2600_a & A2600Read(A2600IndX(addr));
      A2600SetZN(a2600_a);
      a2600_cycles+=6;
      break;
    case 0x31: // AND (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      a2600_a=a2600_a & A2600ReadAbsIndexed(lo,a2600_y);
      A2600SetZN(a2600_a);
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0x24: // BIT zp
      addr=A2600Fetch();
      lo=A2600Read(addr);
      if (a2600_a & lo)
        a2600_p=a2600_p & (0xFF - A2600_F_Z);
      else
        a2600_p=a2600_p | A2600_F_Z;
      if (lo&0x80)
        a2600_p=a2600_p | A2600_F_N;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_N);
      if (lo&0x40)
        a2600_p=a2600_p | A2600_F_V;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_V);
      a2600_cycles+=3;
      break;
    case 0x2C: // BIT abs
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=A2600Read(lo+(hi<<8));
      if (a2600_a & addr)
        a2600_p=a2600_p & (0xFF - A2600_F_Z);
      else
        a2600_p=a2600_p | A2600_F_Z;
      if (addr&0x80)
        a2600_p=a2600_p | A2600_F_N;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_N);
      if (addr&0x40)
        a2600_p=a2600_p | A2600_F_V;
      else
        a2600_p=a2600_p & (0xFF - A2600_F_V);
      a2600_cycles+=4;
      break;
    case 0x09: // ORA #imm
      a2600_a=a2600_a | A2600Fetch();
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x05: // ORA zp
      addr=A2600Fetch();
      a2600_a=a2600_a | A2600Read(addr);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=3;
      break;
    case 0x15: // ORA zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      a2600_a=a2600_a | A2600Read(addr);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x0D: // ORA abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_a=a2600_a | A2600Read(lo+(hi<<8));
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x1D: // ORA abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a | A2600ReadAbsIndexed(addr,a2600_x);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0x19: // ORA abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a | A2600ReadAbsIndexed(addr,a2600_y);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0x01: // ORA (zp,X)
      addr=A2600Fetch();
      a2600_a=a2600_a | A2600Read(A2600IndX(addr));
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=6;
      break;
    case 0x11: // ORA (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      a2600_a=a2600_a | A2600ReadAbsIndexed(lo,a2600_y);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0x69: // ADC #imm
      A2600ADC(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0x65: // ADC zp
      addr=A2600Fetch();
      A2600ADC(A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0x75: // ADC zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600ADC(A2600Read(addr));
      a2600_cycles+=4;
      break;
    case 0x6D: // ADC abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600ADC(A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0x7D: // ADC abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600ADC(A2600ReadAbsIndexed(addr,a2600_x));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0x79: // ADC abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600ADC(A2600ReadAbsIndexed(addr,a2600_y));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0x61: // ADC (zp,X)
      addr=A2600Fetch();
      A2600ADC(A2600Read(A2600IndX(addr)));
      a2600_cycles+=6;
      break;
    case 0x71: // ADC (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      A2600ADC(A2600ReadAbsIndexed(lo,a2600_y));
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xE9: // SBC #imm
      A2600SBC(A2600Fetch());
      a2600_cycles+=2;
      break;
    case 0xE5: // SBC zp
      addr=A2600Fetch();
      A2600SBC(A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0xF5: // SBC zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600SBC(A2600Read(addr));
      a2600_cycles+=4;
      break;
    case 0xED: // SBC abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600SBC(A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0xFD: // SBC abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600SBC(A2600ReadAbsIndexed(addr,a2600_x));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0xF9: // SBC abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600SBC(A2600ReadAbsIndexed(addr,a2600_y));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xE1: // SBC (zp,X)
      addr=A2600Fetch();
      A2600SBC(A2600Read(A2600IndX(addr)));
      a2600_cycles+=6;
      break;
    case 0xF1: // SBC (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      A2600SBC(A2600ReadAbsIndexed(lo,a2600_y));
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xC9: // CMP #imm
      lo=A2600Fetch();
      A2600Cmp(a2600_a,lo);
      a2600_cycles+=2;
      break;
    case 0xC5: // CMP zp
      addr=A2600Fetch();
      A2600Cmp(a2600_a,A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0xD5: // CMP zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      A2600Cmp(a2600_a,A2600Read(addr));
      a2600_cycles+=4;
      break;
    case 0xCD: // CMP abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600Cmp(a2600_a,A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0xDD: // CMP abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600Cmp(a2600_a,A2600ReadAbsIndexed(addr,a2600_x));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0xD9: // CMP abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      A2600Cmp(a2600_a,A2600ReadAbsIndexed(addr,a2600_y));
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0xC1: // CMP (zp,X)
      addr=A2600Fetch();
      A2600Cmp(a2600_a,A2600Read(A2600IndX(addr)));
      a2600_cycles+=6;
      break;
    case 0xD1: // CMP (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      A2600Cmp(a2600_a,A2600ReadAbsIndexed(lo,a2600_y));
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xE0: // CPX #imm
      lo=A2600Fetch();
      A2600Cmp(a2600_x,lo);
      a2600_cycles+=2;
      break;
    case 0xE4: // CPX zp
      addr=A2600Fetch();
      A2600Cmp(a2600_x,A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0xEC: // CPX abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600Cmp(a2600_x,A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0xC0: // CPY #imm
      lo=A2600Fetch();
      A2600Cmp(a2600_y,lo);
      a2600_cycles+=2;
      break;
    case 0xC4: // CPY zp
      addr=A2600Fetch();
      A2600Cmp(a2600_y,A2600Read(addr));
      a2600_cycles+=3;
      break;
    case 0xCC: // CPY abs
      lo=A2600Fetch(); hi=A2600Fetch();
      A2600Cmp(a2600_y,A2600Read(lo+(hi<<8)));
      a2600_cycles+=4;
      break;
    case 0x45: // EOR zp
      addr=A2600Fetch();
      a2600_a=a2600_a ^ A2600Read(addr);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=3;
      break;
    case 0x55: // EOR zp,X
      addr=A2600ZPIndexed(A2600Fetch(),a2600_x);
      a2600_a=a2600_a ^ A2600Read(addr);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x49: // EOR #imm
      a2600_a=a2600_a ^ A2600Fetch();
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=2;
      break;
    case 0x4D: // EOR abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_a=a2600_a ^ A2600Read(lo+(hi<<8));
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4;
      break;
    case 0x5D: // EOR abs,X
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a ^ A2600ReadAbsIndexed(addr,a2600_x);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_x);
      break;
    case 0x59: // EOR abs,Y
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      a2600_a=a2600_a ^ A2600ReadAbsIndexed(addr,a2600_y);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=4+A2600PageCross(addr,addr+a2600_y);
      break;
    case 0x41: // EOR (zp,X)
      addr=A2600Fetch();
      a2600_a=a2600_a ^ A2600Read(A2600IndX(addr));
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=6;
      break;
    case 0x51: // EOR (zp),Y
      addr=A2600Fetch();
      lo=A2600Read(addr)+(A2600Read((addr+1)&0xFF)<<8);
      a2600_a=a2600_a ^ A2600ReadAbsIndexed(lo,a2600_y);
      a2600_a=a2600_a & 0xFF;
      A2600SetZN(a2600_a);
      a2600_cycles+=5+A2600PageCross(lo,lo+a2600_y);
      break;
    case 0xCA: // DEX
      a2600_x=(a2600_x-1)&0xFF;
      A2600SetZN(a2600_x);
      a2600_cycles+=2;
      break;
    case 0xE8: // INX
      a2600_x=(a2600_x+1)&0xFF;
      A2600SetZN(a2600_x);
      a2600_cycles+=2;
      break;
    case 0xC8: // INY
      a2600_y=(a2600_y+1)&0xFF;
      A2600SetZN(a2600_y);
      a2600_cycles+=2;
      break;
    case 0x88: // DEY
      a2600_y=(a2600_y-1)&0xFF;
      A2600SetZN(a2600_y);
      a2600_cycles+=2;
      break;
    case 0x10: // BPL
      a2600_cycles+=2+A2600Branch(!(a2600_p&A2600_F_N));
      break;
    case 0x30: // BMI
      a2600_cycles+=2+A2600Branch(a2600_p&A2600_F_N);
      break;
    case 0x70: // BVS
      a2600_cycles+=2+A2600Branch(a2600_p&A2600_F_V);
      break;
    case 0x50: // BVC
      a2600_cycles+=2+A2600Branch(!(a2600_p&A2600_F_V));
      break;
    case 0x90: // BCC
      a2600_cycles+=2+A2600Branch(!(a2600_p&A2600_F_C));
      break;
    case 0xB0: // BCS
      a2600_cycles+=2+A2600Branch(a2600_p&A2600_F_C);
      break;
    case 0xD0: // BNE
      a2600_cycles+=2+A2600Branch(!(a2600_p&A2600_F_Z));
      break;
    case 0xF0: // BEQ
      a2600_cycles+=2+A2600Branch(a2600_p&A2600_F_Z);
      break;
    case 0x4C: // JMP abs
      lo=A2600Fetch(); hi=A2600Fetch();
      a2600_pc=(lo+(hi<<8))&0xFFFF;
      a2600_cycles+=3;
      break;
    case 0x6C: // JMP (abs), including the original 6502 page-wrap quirk
      lo=A2600Fetch(); hi=A2600Fetch();
      addr=lo+(hi<<8);
      lo=A2600Read(addr);
      if ((addr&0xFF)==0xFF)
        hi=A2600Read(addr&0xFF00);
      else
        hi=A2600Read(addr+1);
      a2600_pc=(lo+(hi<<8))&0xFFFF;
      a2600_cycles+=5;
      break;
    case 0x20: // JSR abs
      lo=A2600Fetch();
      addr=a2600_pc&0xFFFF;
      A2600Read(0x100+(a2600_sp&0xFF));
      A2600Push(addr>>8);
      A2600Push(addr&0xFF);
      hi=A2600Fetch();
      addr=(lo+(hi<<8))&0xFFFF;
      a2600_pc=addr;
      a2600_cycles+=6;
      break;
    case 0x60: // RTS
      A2600Read(0x100+(a2600_sp&0xFF));
      lo=A2600PullData(); hi=A2600PullData();
      addr=(lo+(hi<<8))&0xFFFF;
      A2600Read(addr);
      a2600_pc=(addr+1)&0xFFFF;
      a2600_cycles+=6;
      break;
    default:
      a2600_halt_reason=A2600_HALT_UNSUPPORTED;
      a2600_halted=TRUE;
      break;
  }
  if (a2600_wsync_pending) {
    if (a2600_cycles<a2600_wsync_target)
      a2600_cycles=a2600_wsync_target;
    a2600_wsync_pending=FALSE;
  }
  A2600AudioCatchUp(a2600_cycles);
  if (!A2600CPUCycleAt(a2600_cycles))
    A2600RenderSpan(0);
  a2600_cpu_bus_active=0;
}

Bool A2600LoadCartPath(U8 *filename)
{
  CDrv *dv;
  U8 *data;
  I64 size,rom_size,i,crc,tmp;

  if (filename[1]==':') {
    dv=Let2Drv(filename[0],FALSE);
    if (!dv)
      return FALSE;
    if (dv->fs_type!=FSt_REDSEA && dv->fs_type!=FSt_FAT32)
      return FALSE;
  }
  data=NULL;
  try {
    data=FileRead(filename,&size);
  } catch {
    Fs->catch_except=TRUE;
    data=NULL;
  }
  if (!data)
    return FALSE;
  if (size>A2600_ROM_SIZE) {
    Free(data);
    return FALSE;
  }
  if (size!=2048 && size!=4096 && size!=6144 && size!=8192 && size!=8195 &&
        size!=10240 && size!=10495 && size!=12288 && size!=16384 && size!=24576 &&
        size!=A2600_FA2_SIZE && size!=29696 && size!=32768 &&
        size!=65536 && size!=131072 && size!=262144 && size!=524288 &&
        !(size>=A2600_STARPATH_LOAD_SIZE && size%A2600_STARPATH_LOAD_SIZE==0)) {
    Free(data);
    return FALSE;
  }
  rom_size=size;
  // Stella trims common Pitfall II 10495-byte dumps to the 10K DPC image.
  if (rom_size==10495)
    rom_size=10240;

  for (i=0;i<A2600_ROM_SIZE;i++)
    a2600_rom[i]=0;

  if (rom_size==2048) {
    for (i=0;i<A2600_BANK_SIZE;i++)
      a2600_rom[i]=data[i&0x07FF];
  } else if (rom_size==4096) {
    for (i=0;i<A2600_BANK_SIZE;i++)
      a2600_rom[i]=data[i];
  } else {
    for (i=0;i<rom_size;i++)
      a2600_rom[i]=data[i];
  }

  a2600_ext_cart=TRUE;
  a2600_cart_size=rom_size;
  crc=A2600Z26CRC(data,rom_size);
  a2600_cart_crc=crc;
  a2600_display_phosphor=A2600StellaPhosphorCRC(crc);
  a2600_tv_format=A2600StellaTVFormatCRC(crc);
  if (a2600_tv_format==A2600_TV_UNKNOWN)
    a2600_tv_format=A2600_TV_NTSC;
  a2600_phosphor_ready=0;
  A2600ApplyControllerHints(crc);
  A2600ApplyCartControllerSignatures(data,rom_size);
  if (A2600SaveKeyActive())
    A2600SaveKeyLoad(filename);
  a2600_gl_has_init_ram=FALSE;
  a2600_cart_type=A2600DetectCartType(data,rom_size);
  if (a2600_cart_type==A2600_CART_CM)
    A2600CompuMateLoadCassette(filename);
  else
    A2600CompuMateResetCassette;
  if (a2600_cart_type==A2600_CART_FA2) {
    if (size==29696 || size==32768) {
      for (i=0;i<A2600_ROM_SIZE;i++)
        a2600_rom[i]=0;
      for (i=0;i<A2600_FA2_SIZE;i++)
        a2600_rom[i]=data[i+1024];
    } else if (size==24576) {
      for (i=size;i<A2600_FA2_SIZE;i++)
        a2600_rom[i]=0;
    }
    a2600_cart_size=A2600_FA2_SIZE;
    for (i=0;i<256;i++)
      a2600_fa2_flash[i]=0;
  }
  if (a2600_cart_type==A2600_CART_GL && size==6144) {
    for (i=0;i<2048;i++)
      a2600_gl_init_ram[i]=data[4096+i];
    a2600_gl_has_init_ram=TRUE;
  }
  if (a2600_cart_type==A2600_CART_WDSW) {
    for (i=0;i<1024;i++) {
      tmp=a2600_rom[2048+i];
      a2600_rom[2048+i]=a2600_rom[3072+i];
      a2600_rom[3072+i]=tmp;
    }
    for (i=8192;i<size;i++)
      a2600_rom[i]=0;
  }
  if (a2600_cart_type==A2600_CART_STD)
    a2600_cart_super=A2600DetectSuperCart(data,rom_size);
  else if (a2600_cart_type==A2600_CART_EF)
    a2600_cart_super=A2600DetectEFSC(data,size);
  else if (a2600_cart_type==A2600_CART_DF)
    a2600_cart_super=A2600DetectDFSC(data,size);
  else if (a2600_cart_type==A2600_CART_BF)
    a2600_cart_super=A2600DetectBFSC(data,size);
  else
    a2600_cart_super=FALSE;
  A2600CartResetBanks;
  Free(data);
  return TRUE;
}

Bool A2600LoadAutoCartName(U8 *name)
{
  I64 d,j;
  U8 path[40];

  for (d='G';d<='Z';d++) {
    path[0]=d;
    path[1]=':';
    path[2]='/';
    j=0;
    while (name[j] && j<35) {
      path[3+j]=name[j];
      j++;
    }
    path[3+j]=0;
    if (A2600LoadCartPath(path))
      return TRUE;
  }
  return FALSE;
}

U0 A2600LoadROM()
{
  I64 i;

  a2600_ext_cart=FALSE;
  a2600_cart_size=0;
  a2600_cart_crc=0;
  a2600_display_phosphor=FALSE;
  a2600_tv_format=A2600_TV_NTSC;
  a2600_phosphor_ready=0;
  A2600SetControllerDefaults;
  a2600_cart_super=FALSE;
  a2600_cart_type=A2600_CART_STD;
  a2600_bank=0;
  if (A2600LoadAutoCartName("CART.BIN"))
    return;
  if (A2600LoadCartPath("E:/CART.BIN"))
    return;
  if (A2600LoadCartPath("C:/Home/CART.BIN"))
    return;
  if (A2600LoadAutoCartName("SPECT1.BIN"))
    return;
  if (A2600LoadCartPath("E:/SPECT1.BIN"))
    return;
  if (A2600LoadCartPath("C:/Home/SPECT1.BIN"))
    return;

  for (i=0;i<A2600_ROM_SIZE;i++)
    a2600_rom[i]=0xEA; // NOP fill, like a quiet empty cartridge page.

  for (i=0;i<A2600_PROG_SIZE;i++)
    a2600_rom[i]=a2600_prog[i];

  // Reset vector: CPU reads $FFFC/$FFFD, mirrored to 4K cart offsets $FFC/$FFD.
  a2600_rom[0x0FFC]=0x00;
  a2600_rom[0x0FFD]=0xF0;
}

U0 A2600PowerSeed()
{
  I64 seed;

  a2600_power_reset_count++;
  seed=(a2600_cart_crc&0xFFFFFFFF)^(a2600_power_reset_count*0x9E3779B1);
  seed=seed^0xA2600653;
  seed=seed&0xFFFFFFFF;
  if (!seed)
    seed=0x6D2B79F5;
  a2600_power_rng=seed;
}

I64 A2600PowerRand()
{
  if (!a2600_power_rng)
    a2600_power_rng=0x6D2B79F5;
  a2600_power_rng=(a2600_power_rng^((a2600_power_rng<<13)&0xFFFFFFFF))&
        0xFFFFFFFF;
  a2600_power_rng=(a2600_power_rng^(a2600_power_rng>>17))&0xFFFFFFFF;
  a2600_power_rng=(a2600_power_rng^((a2600_power_rng<<5)&0xFFFFFFFF))&
        0xFFFFFFFF;
  return (a2600_power_rng>>8)&0xFF;
}

U0 A2600Reset()
{
  I64 i;

  A2600KidVidClear;
  A2600LoadROM;
  a2600_cycles=0;
  a2600_cpu_bus_active=0;
  a2600_cpu_bus_cycle=0;
  a2600_access_cycle_active=0;
  a2600_access_cycle=0;
  A2600PowerSeed;
  for (i=0;i<A2600_RAM_SIZE;i++)
    a2600_ram[i]=A2600PowerRand();
  for (i=0;i<A2600_SARA_SIZE;i++)
    a2600_sara[i]=A2600PowerRand();
  for (i=0;i<A2600_CART_RAM_SIZE;i++)
    a2600_cart_ram[i]=A2600PowerRand();
  if (a2600_cart_type==A2600_CART_GL && a2600_gl_has_init_ram) {
    for (i=0;i<2048;i++)
      a2600_cart_ram[i]=a2600_gl_init_ram[i];
  }
  for (i=0;i<64;i++)
    a2600_tia[i]=0;

  A2600ClearFB;
  a2600_a=A2600PowerRand();
  a2600_x=A2600PowerRand();
  a2600_y=A2600PowerRand();
  a2600_sp=0xFD;
  a2600_p=(A2600PowerRand()|A2600_F_B|0x20)&0xFF;
  a2600_bus=0xFF;
  a2600_cycles=0;
  a2600_cpu_bus_active=0;
  a2600_cpu_bus_cycle=0;
  a2600_access_cycle_active=0;
  a2600_access_cycle=0;
  a2600_frames=0;
  a2600_visible_y=0;
  a2600_visible_active=FALSE;
  a2600_scanline=0;
  a2600_frame_scanline=0;
  a2600_last_frame_scanlines=0;
  a2600_frame_state=A2600_FM_WAIT_VSYNC_START;
  a2600_frame_line_state=0;
  a2600_frame_vsync_lines=0;
  a2600_wsync_pending=FALSE;
  a2600_wsync_target=0;
  a2600_line_x=0;
  a2600_tia_cycle=0;
  a2600_hmove_blank_x=0;
  a2600_hmove_blank_next=0;
  a2600_hmove_cycle=0;
  a2600_timer_div=1024;
  a2600_timer_expire=(A2600PowerRand()&0xFF)*a2600_timer_div;
  a2600_timer_irq=0;
  a2600_timer_next_irq=a2600_timer_expire+1;
  a2600_pa7_edge_positive=0;
  a2600_pa7_irq=0;
  a2600_pa7_sync1=1;
  a2600_pa7_last=1;
  a2600_swach_dir=0;
  a2600_swbch_dir=0;
  A2600CartResetBanks;
  a2600_p0_x=32;
  a2600_p1_x=96;
  a2600_m0_x=32;
  a2600_m1_x=96;
  a2600_bl_x=80;
  a2600_p0_motion=0;
  a2600_p1_motion=0;
  a2600_m0_motion=0;
  a2600_m1_motion=0;
  a2600_bl_motion=0;
  for (i=0;i<2;i++) {
    a2600_p_dyn_render[i]=0;
    a2600_p_dyn_counter[i]=0;
    a2600_p_dyn_trip[i]=0;
    a2600_p_dyn_sample[i]=0;
    a2600_p_dyn_divider[i]=1;
    a2600_p_dyn_pending[i]=1;
    a2600_p_dyn_change[i]=-1;
    a2600_m_dyn_mask[i]=1;
    a2600_m_dyn_ended[i]=0;
    a2600_m_hmove_active[i]=0;
  }
  a2600_bl_hmove_active=0;
  a2600_bl_dyn_alive=TRUE;
  a2600_m0_confused=0;
  a2600_cosmic_scanline=0;
  a2600_m0_cosmic_graphics=0;
  a2600_grp0_old=0;
  a2600_grp1_old=0;
  a2600_enabl_old=0;
  a2600_pf0_pending=0;
  a2600_pf1_pending=0;
  a2600_pf2_pending=0;
  a2600_pf_reflect_latch=0;
  a2600_pf_reflect_mid_latched=0;
  A2600ClearCollisions;
  a2600_swcha=0xFF;
  a2600_swchb_base=0x3F;
  a2600_swcha_out=0;
  a2600_swchb_out=0;
  a2600_swchb=a2600_swchb_base;
  A2600SaveKeyResetBus;
  A2600MindlinkReset;
  a2600_fire0=0;
  a2600_fire1=0;
  A2600AudioReset;
  Snd;
  a2600_inpt_latch_mode=0;
  a2600_inpt4_latch=0x80;
  a2600_inpt5_latch=0x80;
  a2600_analog_dump=0;
  a2600_analog_charge_start=0;
  a2600_quadtari_dump_cycle=0;
  for (i=0;i<4;i++)
    A2600PaddleSet(i,128);
  a2600_paddle_mode=0;
  a2600_drive0_count=0;
  a2600_drive1_count=0;
  a2600_trakball_mode=0;
  a2600_trakball_port=0;
  a2600_trakball_both=0;
  A2600TrakBallClear;
  a2600_lightgun_mode=0;
  a2600_lightgun_port=0;
  a2600_lightgun_x=80;
  a2600_lightgun_y=96;
  a2600_lightgun_cycle=49;
  a2600_lightgun_line=95;
  a2600_lightgun_wrap=a2600_controller_lightgun_wrap;
  a2600_lightgun_adjust=a2600_controller_lightgun_adjust;
  a2600_lightgun_vadjust=a2600_controller_lightgun_vadjust;
  if (a2600_left_controller==A2600_CTRL_LIGHTGUN ||
        a2600_right_controller==A2600_CTRL_LIGHTGUN) {
    if (a2600_right_controller==A2600_CTRL_LIGHTGUN)
      a2600_lightgun_port=1;
    A2600LightgunAim(a2600_lightgun_x,a2600_lightgun_y);
  }
  a2600_auto_reset=0;
  a2600_joy0_mask=0;
  a2600_joy0_decay=0;
  a2600_joy1_mask=0;
  a2600_joy1_decay=0;
  a2600_joy0_up_decay=0;
  a2600_joy0_down_decay=0;
  a2600_joy0_left_decay=0;
  a2600_joy0_right_decay=0;
  a2600_joy1_up_decay=0;
  a2600_joy1_down_decay=0;
  a2600_joy1_left_decay=0;
  a2600_joy1_right_decay=0;
  a2600_fire0_decay=0;
  a2600_fire1_decay=0;
  a2600_trigger0_decay=0;
  a2600_booster0_decay=0;
  a2600_trigger1_decay=0;
  a2600_booster1_decay=0;
  a2600_reset_decay=0;
  a2600_select_decay=0;
  a2600_steps=0;
  a2600_last_pc=0;
  a2600_last_op=0;
  a2600_halt_reason=A2600_HALT_NONE;
  a2600_last_run_jiffy=-1;
  a2600_vblank=0x02; // first VBLANK clear starts the visible frame.
  a2600_frame_done=FALSE;
  a2600_vsync_frame_mode=FALSE;
  a2600_halted=FALSE;
  a2600_ready=TRUE;

  a2600_pc=A2600Read(0xFFFC)+(A2600Read(0xFFFD)<<8);
  if (a2600_cart_type==A2600_CART_AR && a2600_sc_start)
    a2600_pc=a2600_sc_start;
}

U0 A2600RunFrame()
{
  I64 target=a2600_frames+1,guard=0;

  if (!a2600_ready)
    A2600Reset;

  A2600DrainInputKeys;
  A2600PollInput;
  A2600MindlinkFrame;
  while (!a2600_halted && a2600_frames<target && guard<60000) {
    A2600Step;
    guard++;
    if (!(guard&0xFF)) {
      A2600DrainInputKeys;
      A2600PollInput(FALSE);
    }
  }

  if (guard>=60000) {
    a2600_halt_reason=A2600_HALT_GUARD;
    a2600_halted=TRUE;
  }
}

U0 A2600DrawIt(CTask *task,CDC *dc)
{
  I64 x,y,x2,c,sx,sy,left,top,off,w,h,frames_run,rate,view_h,view_y0,scale;

  if (!a2600_ready)
    A2600Reset;

  A2600DrainInputKeys;
  if (a2600_last_run_jiffy<0) {
    A2600RunFrame;
    a2600_last_run_jiffy=cnts.jiffies;
  } else {
    rate=A2600FrameRate();
    frames_run=0;
    while (cnts.jiffies-a2600_last_run_jiffy>=JIFFY_FREQ/rate &&
          frames_run<4) {
      A2600RunFrame;
      a2600_last_run_jiffy+=JIFFY_FREQ/rate;
      frames_run++;
    }
    if (cnts.jiffies-a2600_last_run_jiffy>JIFFY_FREQ/4)
      a2600_last_run_jiffy=cnts.jiffies;
  }

  view_h=A2600_VIEW_H;
  if (view_h>A2600_FB_H)
    view_h=A2600_FB_H;
  view_y0=A2600_VIEW_Y0;
  if (view_y0<0)
    view_y0=0;
  if (view_y0+view_h>A2600_FB_H)
    view_y0=A2600_FB_H-view_h;
  scale=(task->pix_height-86)/view_h;
  if ((task->pix_width-24)/(A2600_FB_W*2)<scale)
    scale=(task->pix_width-24)/(A2600_FB_W*2);
  if (scale<1)
    scale=1;
  if (scale>3)
    scale=3;
  sy=scale;
  sx=scale*2;
  w=A2600_FB_W*sx;
  h=view_h*sy;
  left=(task->pix_width-w)>>1;
  top=85;

  dc->color=BLACK;
  GrRect(dc,left-10,top-10,w+20,h+20);
  dc->color=LTGRAY;
  GrRect(dc,left-6,top-6,w+12,4);
  GrRect(dc,left-6,top+h+2,w+12,4);
  GrRect(dc,left-6,top-6,4,h+12);
  GrRect(dc,left+w+2,top-6,4,h+12);

  for (y=0;y<view_h;y++) {
    off=(view_y0+y)*A2600_FB_W;
    x=0;
    while (x<A2600_FB_W) {
      c=A2600PhosphorPixel(off+x);
      x2=x+1;
      while (x2<A2600_FB_W && A2600PhosphorPixel(off+x2)==c)
        x2++;
      dc->color=c;
      GrRect(dc,left+x*sx,top+y*sy,(x2-x)*sx,sy);
      x=x2;
    }
  }

  dc->color=YELLOW;
  GrPrint(dc,8,18,"HolyC Atari 2600 proof (z26-style core)");
  dc->color=WHITE;
  GrPrint(dc,8,30,"PC:%04X OP:%02X A:%02X X:%02X Y:%02X P:%02X frames:%d steps:%d",
        a2600_pc,a2600_last_op,a2600_a,a2600_x,a2600_y,a2600_p,
        a2600_frames,a2600_steps);
  if (a2600_halted) {
    dc->color=LTRED;
    if (a2600_halt_reason==A2600_HALT_JAM)
      GrPrint(dc,8,42,"HALT JAM/KIL %02X at %04X",a2600_last_op,a2600_last_pc);
    else if (a2600_halt_reason==A2600_HALT_GUARD)
      GrPrint(dc,8,42,"HALT frame guard");
    else
      GrPrint(dc,8,42,"HALT unsupported %02X at %04X",a2600_last_op,a2600_last_pc);
  } else if (a2600_ext_cart) {
    dc->color=LTGREEN;
    if (a2600_cart_super)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, bank %d, SC RAM)",
            a2600_cart_size,a2600_bank);
    else if (a2600_cart_type==A2600_CART_E0)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, E0 seg %d/%d/%d)",
            a2600_cart_size,a2600_cart_seg0,a2600_cart_seg1,a2600_cart_seg2);
    else if (a2600_cart_type==A2600_CART_3F)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, 3F bank %d)",
            a2600_cart_size,a2600_cart_seg0);
    else if (a2600_cart_type==A2600_CART_3E)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, 3E bank %d ram %d)",
            a2600_cart_size,a2600_cart_seg0,a2600_cart_ram_mode);
    else if (a2600_cart_type==A2600_CART_E7)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, E7 bank %d ram %d)",
            a2600_cart_size,a2600_cart_seg0,a2600_cart_ram_bank);
    else if (a2600_cart_type==A2600_CART_FA)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, FA bank %d)",
            a2600_cart_size,a2600_bank);
    else if (a2600_cart_type==A2600_CART_FA2)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, FA2 bank %d flash %d)",
            a2600_cart_size,a2600_bank,a2600_fa2_flash_busy);
    else if (a2600_cart_type==A2600_CART_FE)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, FE bank %d)",
            a2600_cart_size,a2600_bank);
    else if (a2600_cart_type==A2600_CART_DPC)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, DPC bank %d)",
            a2600_cart_size,a2600_bank);
    else if (a2600_cart_type==A2600_CART_AR)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, Supercharger ctl %02X)",
            a2600_cart_size,a2600_sc_control);
    else if (a2600_cart_type==A2600_CART_F0)
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, F0 bank %d)",
            a2600_cart_size,a2600_bank);
    else
      GrPrint(dc,8,42,"Loaded external CART.BIN/SPECT1.BIN (%d bytes, bank %d)",
            a2600_cart_size,a2600_bank);
	  dc->color=LTGRAY;
    GrPrint(dc,8,54,"TV:%s %dHz PH:%d SW:%02X J0:%02X F0:%d/%d Pad:%d/%d Dr:%d",
          A2600TVName(),A2600FrameRate(),a2600_display_phosphor,
          a2600_swchb,a2600_joy0_mask,a2600_fire0,a2600_fire0_decay,
          a2600_paddle_pos[0],a2600_paddle_pos[1],
          (a2600_drive0_count&0x0F)>>2);
  } else {
    dc->color=LTGREEN;
    GrPrint(dc,8,42,"Embedded 4K ROM: 6507 writes TIA PF/COL/WSYNC registers");
    dc->color=LTGRAY;
    GrPrint(dc,8,54,"TV:%s %dHz PH:%d SW:%02X J0:%02X F0:%d/%d Pad:%d/%d Dr:%d",
          A2600TVName(),A2600FrameRate(),a2600_display_phosphor,
          a2600_swchb,a2600_joy0_mask,a2600_fire0,a2600_fire0_decay,
          a2600_paddle_pos[0],a2600_paddle_pos[1],
          (a2600_drive0_count&0x0F)>>2);
  }
}

U0 Atari2600Proof()
{
  I64 ch,sc,done=FALSE;

  SettingsPush;
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;
  while (ScanKey(&ch,&sc,FALSE)) {
  }
  a2600_quit_requested=FALSE;
  A2600Reset;
  Fs->draw_it=&A2600DrawIt;
  try {
    "HolyC Atari 2600 emulator proof\n";
    "Port slice from z26/Stella-style C architecture: 6507, RIOT RAM, TIA writes, cart hardware.\n";
    "Looks for CART.BIN first, then SPECT1.BIN on G:/..Z:/, E:/, or C:/Home.\n";
          "Arrows move P0; F/SPACE/ENTER fires/jumps P0. IJKL move P1; M fires P1. R/F1 reset/start, U/F2 select, F3/F4 B/W-Color, F5-F8 difficulty, ESC quits.\n";
    while (!done) {
      if (A2600DrainInputKeys() || a2600_quit_requested)
        done=TRUE;
      Sleep(8);
    }
  } catch
    PutExcept;
  DocClear;
  SettingsPop;
}

Atari2600Proof;
