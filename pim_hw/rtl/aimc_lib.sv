`timescale 1ps / 1ps

package aimc_lib;
  // ========================================================================================================
  //                                             SYSTEM DEFINITIONS
  // ========================================================================================================
  //
  //            !!! USER MUST DEFINE THE SYSTEM HERE !!!
  //
  // `define N1ZYNQ_CONFIG     // Custom Solid Meca Newton1 Board with ZU19EG SoC
  // `define VCU118_CONFIG     // Xilinx UltraScale+ Virtex VCU118 Evaluation Board
  // `define ZCU102_CONFIG     // Xilinx UltraScale+ Zynq MSoC ZCU102 Evaluation Board
   `define VCK190_CONFIG     // Xilinx Versal VCK190 Evaluation Board
  //
  //            !!! USER MUST DEFINE THE SYSTEM HERE !!!
  //

`define SUPPORT_INDIRECT_ADDRESSING



  // NOTE: BELOW DEFINITIONS ARE AUTOMATIC AND SHOULD NOT BE TOUCHED
  // Combined definition for Versal and UltraScale+ devices
  `ifdef N1ZYNQ_CONFIG
    `define ULTRASCALE_CONFIG
  `elsif VCU118_CONFIG
    `define ULTRASCALE_CONFIG
  `elsif ZCU102_CONFIG
    `define ULTRASCALE_CONFIG
  `elsif VCK190_CONFIG
    `define VERSAL_CONFIG
  `endif

  // Combined definition for FMC configuraitons
  `ifdef VCU118_CONFIG
    `define FMC_CONFIG
  `elsif ZCU102_CONFIG
    `define FMC_CONFIG
  `elsif VCK190_CONFIG
    `define FMC_CONFIG
  `endif

  // ========================================================================================================
  //                                              SYSTEM CLOCKS
  // ========================================================================================================
  // Definitions for input clock speed
  `ifdef N1ZYNQ_CONFIG
    `define CLKIN_300MHZ
  `elsif VCU118_CONFIG
    `define CLKIN_250MHZ
  `elsif ZCU102_CONFIG
    `define CLKIN_300MHZ
  `elsif VCK190_CONFIG
    `define CLKIN_200MHZ
  `endif
  
  parameter string GLOBAL_CLK = "CK_DIV2";    // System-to-DRAM clock ratio: "CK_DIV1" (CLK = DRAM CK), "CK_DIV2" (CLK = 1/2 DRAM CK)
  parameter string INTF_SPEED = "3_4_Gbps";   // GDDR6 interface speed: "2_0_Gbps" ... "3_8_Gbps"; Not all speeds are supported for all system configurations -- check below!

  // MMCM Parameters (Global Infrastructure)
  // !!! MMCM VCO frequency must be in the range [800; 1600] MHz for UltraScale+ and [2160; 4320] MHz for Versal !!!
  `ifdef ULTRASCALE_CONFIG
    `ifdef CLKIN_250MHZ
  parameter real CLKIN_PERIOD_MMCM  = 4.000;
  parameter int  CLKFBOUT_MULT_MMCM = INTF_SPEED == "2_0_Gbps" ? 4  : INTF_SPEED == "2_4_Gbps" ? 6  : 0;
  parameter int  CLKDIV_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 4  : INTF_SPEED == "2_4_Gbps" ? 5  : 0;
  parameter int  CLK100_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 10 : INTF_SPEED == "2_4_Gbps" ? 15 : 0;
    `elsif CLKIN_300MHZ
  parameter real CLKIN_PERIOD_MMCM  = 3.333;
  parameter int  CLKFBOUT_MULT_MMCM = INTF_SPEED == "2_0_Gbps" ? 5  : INTF_SPEED == "2_4_Gbps" ? 4  : 0;
  parameter int  CLKDIV_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 6  : INTF_SPEED == "2_4_Gbps" ? 4  : 0;
  parameter int  CLK100_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 15 : INTF_SPEED == "2_4_Gbps" ? 12 : 0;
    `endif
  `elsif VERSAL_CONFIG
    `ifdef CLKIN_200MHZ
  parameter real CLKIN_PERIOD_MMCM  = 5.000;
  parameter int  CLKFBOUT_MULT_MMCM = INTF_SPEED == "2_0_Gbps" ? 15 : INTF_SPEED == "2_2_Gbps" ? 11 : INTF_SPEED == "2_4_Gbps" ? 12 : INTF_SPEED == "2_6_Gbps" ? 13 : INTF_SPEED == "2_8_Gbps" ? 14 : 
                                      INTF_SPEED == "3_0_Gbps" ? 15 : INTF_SPEED == "3_2_Gbps" ? 16 : INTF_SPEED == "3_4_Gbps" ? 17 : INTF_SPEED == "3_6_Gbps" ? 18 : INTF_SPEED == "3_8_Gbps" ? 19 : 0;
  parameter int  CLKDIV_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 12 : 8;
  parameter int  CLK100_DIVIDE_MMCM = INTF_SPEED == "2_0_Gbps" ? 30 : INTF_SPEED == "2_2_Gbps" ? 22 : INTF_SPEED == "2_4_Gbps" ? 24 : INTF_SPEED == "2_6_Gbps" ? 26 : INTF_SPEED == "2_8_Gbps" ? 28 : 
                                      INTF_SPEED == "3_0_Gbps" ? 30 : INTF_SPEED == "3_2_Gbps" ? 32 : INTF_SPEED == "3_4_Gbps" ? 34 : INTF_SPEED == "3_6_Gbps" ? 36 : INTF_SPEED == "3_8_Gbps" ? 38 : 0;
    `endif
  `endif
  parameter int  DIVCLK_DIVIDE_MMCM = 1;
  parameter int  CLKRX_DIVIDE_MMCM  = CLKDIV_DIVIDE_MMCM/2;
  parameter int  CLKRIU_DIVIDE_MMCM = CLKDIV_DIVIDE_MMCM*2;
  // Derivative Parameters
  parameter real tCLKDIV            = CLKIN_PERIOD_MMCM*DIVCLK_DIVIDE_MMCM*CLKDIV_DIVIDE_MMCM/CLKFBOUT_MULT_MMCM;
  parameter int  SYS_CLK_SPEED      = $ceil(1000.0/tCLKDIV);                            // System clock speed in MHz
  parameter shortint unsigned tUS   = $ceil(1000.0/tCLKDIV);                            // Number of controller clock cycles in one microsecond

  // PLL4E/XPLL Parameters (PHY)
  // !!! PLL VCO frequency must be in the range [750; 1500] MHz for UltraScale+ and [2160; 4320] MHz for Versal !!!
  parameter real CLKIN_PERIOD_PLL   = tCLKDIV;                                          // Using clk_div as PLL4E/XPLL input clock
  parameter int  DIVCLK_DIVIDE_PLL  = 1;
  `ifdef ULTRASCALE_CONFIG
  parameter int       CLKFBOUT_MULT_PLL    = 4;                                         // Must keep VCO in [750; 1500] MHz range
  parameter string    CLKOUTPHY_MODE_PLL   = "VCO_2X";                                  // PLLE4's CLKOUTPHY ratio to VCO: "VCO", "HALF_VCO", "VCO_2X"; only used for UltraScale+
  parameter shortreal REFCLK_FREQ          = (1000.0/tCLKDIV)*(CLKFBOUT_MULT_PLL/DIVCLK_DIVIDE_PLL)*((CLKOUTPHY_MODE_PLL=="VCO_2X")? 2:(CLKOUTPHY_MODE_PLL=="VCO")? 1:0.5);
  `elsif VERSAL_CONFIG
  parameter int       CLKFBOUT_MULT_PLL    = INTF_SPEED == "2_0_Gbps" ? 16 : 8;          // Must keep VCO in [2160; 4320] MHz range
  parameter string    CLKOUTPHY_DIVIDE_PLL = CLKFBOUT_MULT_PLL == 16 ? "DIV2" : "DIV1";  // XPLL's CLKOUTPHY ratio to VCO: "DIV1", "DIV2", "DIV4", "DIV8", "DIV16"; only used for Versal
  parameter shortreal REFCLK_FREQ          = (1000.0/tCLKDIV)*(CLKFBOUT_MULT_PLL/DIVCLK_DIVIDE_PLL)*((CLKOUTPHY_DIVIDE_PLL=="DIV2")? 0.5:(CLKOUTPHY_DIVIDE_PLL=="DIV1")? 1:0);
  `endif

  // ========================================================================================================
  //                                           DIAGNOSTIC MONITOR
  // ========================================================================================================
  parameter string UTIL_MON_EN    = "FALSE";      // Generate a CA Utilization Monitor: "TRUE", "FALSE"
  parameter string LATENCY_MON_EN = "FALSE";      // Generate a Latency Monitor in AiM DMA: "TRUE", "FASLE"
  parameter string DIAG_MON_EN    = (UTIL_MON_EN == "TRUE" || LATENCY_MON_EN == "TRUE") ? "TRUE" : "FALSE";  // Generate an FX3 controller for reporting diagnostic data

  parameter int FX3_WIDTH    = 8;                 // FX3 FIFO interface width
  parameter int FX3_WR_DEPTH = 64;                // FX3 controller's entry FIFO (FPGA->FX3) size in units of FX3_WIDTH
  parameter int FX3_RD_DEPTH = 16;                // FX3 controller's exit FIFO (FX3->FPGA) size in units of FX3_WIDTH

  parameter int AVG_SHIFT    = 22;                // Averaging shift (values are read out every 2**AVG_SHIFT clock cycles)
  
  /* -----------------------------------------------------------------------------------
    AVG_SHIFT | READ_OUT_PER (125 MHz) | READ_OUT_PER (150 MHz) | READ_OUT_PER (250 MHz)
    ------------------------------------------------------------------------------------
    18        | 2.097 ms               | 1.748 ms               | 1.049 ms
    19        | 4.194 ms               | 3.495 ms               | 2.097 ms
    20        | 8.389 ms               | 6.991 ms               | 4.194 ms
    21        | 16.778 ms              | 13.981 ms              | 8.389 ms
    22        | 33.554 ms              | 27.962 ms              | 16.778 ms
    23        | 67.109 ms              | 55.924 ms              | 33.554 ms
    24        | 134.218 ms             | 111.848 ms             | 67.109 ms
    25        | 268.436 ms (MAX value) | 223.696 ms (MAX value) | 134.218 ms (MAX value)
    ------------------------------------------------------------------------------------ */

  // ========================================================================================================
  //                                             AIM CONFIGURATION
  // ========================================================================================================
  `ifdef N1ZYNQ_CONFIG
  parameter int CH_NUM = 8;                       // Supported number of ch. for Solid Meca board is 2-8
  `elsif VCU118_CONFIG
  parameter int CH_NUM = 2;                       // Supported number of ch. for VCU118 board is 2-4; CH0-1 HPC1, CH2-3 HSCP
  `elsif ZCU102_CONFIG
  parameter int CH_NUM = 3;                       // Supported number of ch. for ZCU102 board is 2-3; CH0-1 HPC0, CH2 HPC1
  `elsif VCK190_CONFIG
  parameter int CH_NUM = 3;                       // Supported number of ch. for VCK190 board is 2-3; CH0-1 FMC1, CH2 FMC2
  `endif
  parameter int CH_ADDR_WIDTH  = $clog2(CH_NUM);  // Channel address width
  parameter int BK_ADDR_WIDTH  = 4;               // Bank address width (16 banks)
  parameter int ROW_ADDR_WIDTH = 14;              // Row address width (14k rows)
  parameter int COL_ADDR_WIDTH = 6;               // Column address width (64 columns, 32 bytes per column)
  parameter int DATA_WIDTH     = 256;             // Data access width (32 bytes)
  parameter int MASK_WIDTH     = 16;              // Data mask width (double-byte mask)

  parameter int BL = 2;                           // Burst Length

  // ========================================================================================================
  //                                             DMA CONFIGURATION
  // ========================================================================================================
  // ! WARNING ! DON'T CHANGE OPERATION ORDER IN AIM_OP_T TYPE (IT REPRESENTS OPCODE)
  typedef enum logic [4:0] {ISR_WR_SBK=0,   ISR_WR_HBK=1, ISR_WR_GPR=2,    ISR_WR_GB=3,     ISR_WR_BIAS=4,  ISR_WR_AFLUT=5,
                            ISR_RD_MAC=6,   ISR_RD_AF=7,  ISR_COPY_BKGB=8, ISR_COPY_GBBK=9, ISR_MAC_SBK=10, ISR_MAC_HBK=11, 
                            ISR_MAC_ABK=12, ISR_AF=13,    ISR_EWMUL=14,    ISR_EWADD=15,    ISR_RD_SBK=16,  ISR_DBG=17} aim_op_t;

  typedef enum logic [1:0] {DRAM_RANGE=0, GPR_RANGE, CFR_RANGE, ISR_RANGE} addr_range_t;

  parameter string RISCV_DMA = "FALSE";           // Implement DMA in RISC-V: "TRUE", "FASLE"

  // DMA Debugger parameters
  parameter string DMA_DEBUG_EN = "FALSE";         // Enable DMA debugger module: "TRUE", "FALSE"
  parameter int DBG_ADDR_WIDTH = 12;              // Debugger memory address width (12-bit address corresponds to full UltraRAM size, 4096 rows x 72 bits)

  `ifdef N1ZYNQ_CONFIG
  parameter string GPR_STYLE = "QDRII";           // Memory for GPR implementation: "QDRII", "BLOCK"
  `elsif FMC_CONFIG
  parameter string GPR_STYLE = "BLOCK";           // ! WARNING ! QDR II+ memory is not available on VCU118 or ZCU102 boards
  `endif

  parameter [4:0]  EWADD_NUM  = 2;                // Number of parallel adders in EWADD module (supported values: 2, 4, 8, 16)

  parameter [31:0] GPR_ADDR_0 = 32'h00204000;     // Start address for GPR range
  parameter [31:0] GPR_ADDR_1 = (GPR_STYLE == "QDRII") ? 32'h00A03FFF : 32'h00283FFF;  // End address for GPR range
  parameter [31:0] CFR_ADDR_0 = 32'h00200000;     // Start address for CFR range
  parameter [31:0] CFR_ADDR_1 = 32'h00203FFF;     // End address for CFR range
  parameter [31:0] ISR_ADDR_0 = 32'h00000000;     // Start address for ISR range
  parameter [31:0] ISR_ADDR_1 = 32'h001FFFFF;     // End address for ISR range

  parameter int GPR_ADDR_WIDTH = (GPR_STYLE == "QDRII") ? 18 : 14;  // QDRII GPR is 8 MB (262,144 rows x 32 bytes), BLOCK GPR is 512 KB register (16384 rows x 32 bytes)
  parameter int CFR_ADDR_WIDTH = 9;

  typedef enum logic [1:0] {RoChBaCo=0, RoCoBaCh, ChRoBaCo, ChRoCoBa} addr_map_t;

  // ========================================================================================================
  //                                          INTERCONNECT CONFIGURATION
  // ========================================================================================================
  parameter int RP_SHIFT_SIZE = 8;                // Size of a single response pointer shifter (WARNING : TO CHANGE THIS PARAMETER, NEED TO MODIFY resp_ptr MODULE)
  parameter int RP_SHIFT_NUM  = 4;                // Number of response pointer shifters
  parameter int BCAST_PIPE_LENGTH = RP_SHIFT_SIZE*RP_SHIFT_NUM;  // Number of broadcast packets allowed in-flight 

  // ========================================================================================================
  //                                          AIM CONTROLLER CONFIGURATION
  // ========================================================================================================
  parameter string INIT_BYPASS  = "FALSE";        // Bypass memory initialization routine: "TRUE", "FALSE"
  `ifdef XILINX_SIMULATOR
  parameter string CALIB_BYPASS = "TRUE";         // The controller is defaulted to correct timing in behavioral simulations
  `else
  parameter string CALIB_BYPASS = "FALSE";        // Bypass memory training routine: "TRUE", "FALSE"
  `endif
  parameter string PTNGEN_EN    = "FALSE";        // Add MCS-controlled pattern generator to Calibration Handler: "TRUE", "FALSE"

  // Scheduling hardware architecture
  parameter string SCHED_STYLE  = GLOBAL_CLK == "CK_DIV1" ? "FRFCFS" /*"FIFO"*/ : "FIFO";  // Scheduling style: "FRFCFS" (requires GLOBAL_CLK="CK_DIV1"), "FIFO"

  // Packet priority levels
  parameter int PRIO = 4;                         // Number of packet priority levels used in the controller (WARNING: This parameter has a significant effect on the resources and timing)
  parameter int REF_PRIO = PRIO - 1;              // Priority assigned to all refresh packets (should be the highest priority)

  // FR-FCFS Row Arbiter parameters
  parameter int ROWARB_DEPTH      = 256;          // Number of memory slots used in the Row Arbiter for buffering the packets
  parameter int NUM_RAQ           = 32;           // Number of pointer queues to be generated in the Row Arbiter (each queue handles a single {prio, bk, row} value); MUST BE POWER OF 2!
  parameter int RAQ_DEPTH_DEFAULT = 8;            // Row Arbiter's pointer queue depth (default value)
  parameter int RAQ_DEPTH_RETRY   = 8;            // Separate depth parameter for EDC retry queue (can be used instead of default)

  // ========================================================================================================
  //                                PROGRAMMABLE PARAMETERS (CONFIGURATION REGISTER)
  // ========================================================================================================
  parameter string CONFIG_TIMING = "FALSE";       // Use CFR-configurable DRAM timings: "TRUE", "FALSE"

  typedef logic [5:0] dram_time_t;                // Data type for encoding DRAM timings in clock cycles
  typedef enum logic {FRFCFS=0, FIFO=1} row_policy_t;
  typedef enum logic [1:0] {POL_REFAB=0, POL_REFPB=1, POL_NOREF=2} ref_policy_t;

  real tCK = tCLKDIV;                             // CK_t/CK_n clock period in "ns"
  function automatic logic [31:0] ns2ck;          // Function for converting timing values given in "ns" to DRAM clock cycles (CK_t/CK_c)
    input real t_ns;
    begin 
      ns2ck = $ceil(t_ns/tCK);                    // At least once CK delay is mendatory (1 CK delay means next command is outputted at the next CK)
    end
  endfunction

  typedef struct packed {
    logic [4:0] WL;
    logic [4:0] RL;
    logic [4:0] CRCWL;
    logic [4:0] CRCRL;
    logic BK_BCAST;
    logic [2:0] RELU_MAX;
    logic EWMUL_BG;
    logic [2:0] AFM;
  } cfr_mode_t;

  typedef struct packed {
    // Normal Command Timings
    dram_time_t tCCD;
    dram_time_t tRC;
    dram_time_t tRAS;
    dram_time_t tRCDRD;
    dram_time_t tRCDWR;
    dram_time_t tRP;
    dram_time_t tPPD;
    dram_time_t tRTP;
    dram_time_t tWR;
    dram_time_t tRRD;
    dram_time_t tWTR;
    dram_time_t tRTW;
    dram_time_t tMRD;
    dram_time_t tMOD;
    // Refresh Timings
    dram_time_t tRREFD;
    logic [15:0] tRFCpb;
    logic [15:0] tRFCab;
    logic [15:0] tREFIpb;
    logic [15:0] tREFIab;
    dram_time_t tKO;
    dram_time_t tWRIDON;
    // AiM Command Timings
    dram_time_t tRCDRDL;
    dram_time_t tRCDWRL;
    dram_time_t tMACD;
    dram_time_t tAFD;
    dram_time_t tEWMD;
    dram_time_t tEED;
    dram_time_t tRDCPD;
    dram_time_t tNDMRD;
    dram_time_t tNDMWR;
    dram_time_t tWRGBD;
    dram_time_t tWRGBX;
    dram_time_t tWRBIASD;
    dram_time_t tWRBIASX;
    dram_time_t tRDMACD;
    dram_time_t tRDMACX;
    dram_time_t tRDAFD;
    dram_time_t tRDAFX;
    // WCK2CK Training Timings
    dram_time_t tWCK2MRS;
    dram_time_t tMRSTWCK;
    dram_time_t tWCK2TR;
    // Read/Write Training Timings
    dram_time_t tLTLTR;
    dram_time_t tRCDRTR;
    dram_time_t tRCDWTR;
    dram_time_t tWTRTR;
  } cfr_time_t;

  typedef struct packed {
    logic [31:0] TEMP_RD_PER;
    logic [31:0] REFAB_PER;
    ref_policy_t REF_POLICY;
    logic [6:0] MTEMP_THR;
    logic [6:0] HTEMP_THR;
  } cfr_refr_t;

  typedef struct packed {
    logic EDC_EN;
    logic LOOP_EN;
    row_policy_t ROW_POLICY;
    logic [5:0] EXH_THR;
  } cfr_schd_t;

  typedef struct packed {
    addr_map_t ADDR_MAP;
  } cfr_adma_t;

  // ================= [DEFAULT: MODE REGISTER] =================
  parameter int WL_MIN      = 5;
  parameter int WL_MAX      = 8;                // Write Latency         (supported values: 5 - 8)
  parameter int RL_MAX      = 20;               // Read Latency          (supported values: 9 - 36)
  parameter int CRCWL_MAX   = 16;               // CRC Latency for Write (supported values: 10 - 16)
  parameter int CRCRL_MAX   = 4;                // CRC Latency for Read  (supported values: 2 - 4 (CRCRL = 1 is not supported by the controller))
  parameter int tWRIDON_MAX = 8;                // Temperature Read Timing

  cfr_mode_t cfr_mode_init = '{
    WL          : 5,
    RL          : 9,
    CRCWL       : 10,
    CRCRL       : 2,
    BK_BCAST    : 1,
    RELU_MAX    : 0,
    EWMUL_BG    : 0,
    AFM         : 0
  };

  // ================== [DEFAULT: DRAM TIMINGS] =================
  cfr_time_t cfr_time_init = '{
    // Normal Command Timings (values in Brackets are given in "ns")
    tCCD        : 2,
    tRC         : ns2ck(43),
    tRAS        : ns2ck(28),
    tRCDRD      : ns2ck(15),
    tRCDWR      : ns2ck(12),
    tRP         : ns2ck(15),
    tPPD        : ns2ck(1),
    tRTP        : ns2ck(3),
    tWR         : (ns2ck(15) < 4) ? 4 : ns2ck(15),
    tRRD        : 2,
    tWTR        : ns2ck(tCK*2 + 5),
    tRTW        : cfr_mode_init.RL + 2 - cfr_mode_init.WL + 2 + cfr_mode_init.CRCRL,
    tMRD        : 4,
    tMOD        : 8,
    // Refresh and Power-up Timings
    tRREFD      : 8,
    tRFCpb      : ns2ck(120),
    tRFCab      : ns2ck(120),
    tREFIpb     : ns2ck(1900/16),//max(ns2ck(1900/16), tRFCpb),  // Making sure that tRFCpb passes between two REFPB sequences
    tREFIab     : ns2ck(1900),
    tKO         : 1 + ns2ck(12),
    tWRIDON     : ns2ck(11) + 2,
    // AiM Timings
    tRCDRDL     : ns2ck(18),
    tRCDWRL     : ns2ck(15),
    tMACD       : ns2ck(17),
    tAFD        : ns2ck(27),
    tEWMD       : ns2ck(15),
    tEED        : 2,
    tRDCPD      : cfr_mode_init.RL,
    tNDMRD      : ns2ck(15),
    tNDMWR      : ns2ck(15),
    tWRGBD      : 2,
    tWRGBX      : cfr_mode_init.WL + 3 + ns2ck(5),
    tWRBIASD    : 2,
    tWRBIASX    : cfr_mode_init.WL + 2 + ns2ck(6),
    tRDMACD     : 4,
    tRDMACX     : cfr_mode_init.RL + cfr_mode_init.CRCRL,
    tRDAFD      : 4,
    tRDAFX      : cfr_mode_init.RL + cfr_mode_init.CRCRL,
    // WCK2CK Training Timings
    tWCK2MRS    : ns2ck(3),
    tMRSTWCK    : ns2ck(10),
    tWCK2TR     : 10,
    // Read/Write Training Timings
    tLTLTR      : 6,                              // Values below 4*tCK are invalid (see JEDEC Page 34). Values below 2*tCK will cause incorrect calibration behavior
    tRCDRTR     : ns2ck(18),
    tRCDWTR     : ns2ck(10),
    tWTRTR      : cfr_mode_init.WL + 2 + ns2ck(5)
  };

  // ==================== [DEFAULT: REFRESH] ====================
  cfr_refr_t cfr_refr_init = '{
    TEMP_RD_PER : ns2ck(200000000),               // Period for reading out temperature data in tCK (200 ms)
    REFAB_PER   : ns2ck(1000000),                 // Period for forcing REFAB in tCK (1 ms in JEDEC)
    REF_POLICY  : POL_REFAB,
    MTEMP_THR   : 90,
    HTEMP_THR   : 110
  };

  // =================== [DEFAULT: SCHEDULER] ===================
  cfr_schd_t cfr_schd_init = '{
    EDC_EN      : 0,
    LOOP_EN     : 0,
    ROW_POLICY  : FRFCFS,                         // Row Arbitration Policy: "FIFO", "FRFCFS"
    EXH_THR     : 32                              // Exhaustion threshold for Pointer Queues in FRFCFS Arbiter. Must be in the range of 1-63
  };

  // ==================== [DEFAULT: AIM DMA] ====================
  cfr_adma_t cfr_adma_init = '{
    //ADDR_MAP    : ChRoBaCo
    ADDR_MAP    : ChRoCoBa
  };

  // ========================================================================================================
  //                                         INITIAL MODE REGISTER VALUES
  // ========================================================================================================
  // MR0
  logic [3:0] RLmr0    = (cfr_mode_init.RL > 20) ? (cfr_mode_init.RL - 21) : (cfr_mode_init.RL - 5);  // Read Latency (RL) [3:0]
  logic [2:0] WLmr0    = (cfr_mode_init.WL == 8) ? 0 : cfr_mode_init.WL;                              // Write Latency (WL)
  // MR1
  logic       CABImr1  = 1;                       // Enable CABI (0: On, 1: Off)
  logic       WDBImr1  = 1;                       // Enable Write DBI (0: On, 1: Off)
  logic       RDBImr1  = 1;                       // Enable Read DBI (0: On, 1: Off)
  // MR3
  logic [1:0] BGmr3    = 2'b00;                   // Bank Group (00: OFF, 11: ON)
  // MR4
  logic       EDC_Inv  = 0;                       // Invert EDC1 hold pattern
  logic       WCRCmr4  = 0;                       // Enable CRC for WRITE operations (0: On, 1: Off)
  logic       RCRCmr4  = 0;                       // Enable CRC for READ oeprations (0: On, 1: Off)
  logic [1:0] CRCRLmr4 = (cfr_mode_init.CRCRL == 4) ? 0 : cfr_mode_init.CRCRL;                                 // CRC Read Latency (CRCRL)
  logic [2:0] CRCWLmr4 = (cfr_mode_init.CRCWL > 14) ? (cfr_mode_init.CRCWL - 15) : (cfr_mode_init.CRCWL - 7);  // CRC Write Latency (CRCWL)
  logic [3:0] EDC_Hold = 4'b0000;                 // EDC Hold Pattern
  // MR8
  logic       RLmr8    = (cfr_mode_init.RL > 20) ? 1 : 0;  // Read Latency (RL) [4]

  // ========================================================================================================
  //                                          MEMORY PACKET STRUCTURES
  // ========================================================================================================
  // ! WARNING ! DON'T CHANGE COMMAND AND REQUEST ORDER IN REQ_T OR CMD_T TYPES
  typedef enum logic [4:0] {NONE=0, READ, READ_SBK, WRITE, WRITE_ABK, WRITE_AF, WRITE_GB,     // Non-loopable requests
                            WRITE_BIAS, TR_READ, TR_WRITE, READ_MAC, READ_AF, DO_MRS, DO_AF,  // Non-loopable requests
                            DO_MACSB, DO_MACAB, DO_RDCP, DO_WRCP, DO_EWMUL} req_t;            // Loopable requests (one request scrolls through many columns)

  typedef enum logic [5:0] {NOP1=0, WCK2CK, MRS_TEMP, ACT, PREPB, PREAB, REFPB, REFAB, LDFF,  // Internal or auxiliary commands (no ack to row arbiter)
                            WRTR, RDTR, CAT, CONF, ACT4, ACT16, ACTAF4, ACTAF16, NDME, NDMX,  // Internal or auxiliary commands (no ack to row arbiter)
                            MRS, RD, WOM, WDM, MACSB, MAC4B, MACAB, AF, WRBK, RDCP, WRCP,     // Data access commands (require ack to row arbiter)
                            WRGB, WRBIAS, RDMAC, RDAF, EWMUL} cmd_t;                          // Data access commands (require ack to row arbiter)

  typedef enum logic [2:0] {DRAM_RD=0, DRAMSBK_RD, MACREG_RD, AFREG_RD, DMAREG_RD} rd_t;      // Read type required for distinguishing between different read requests in Ordering Engine
  
  // Ordering Engine internal packet type
  typedef struct packed {
    rd_t                       rd_type;
    logic [$clog2(CH_NUM)-1:0] ch_addr; 
    logic [BK_ADDR_WIDTH-1:0]  bk_addr;    
    logic [ROW_ADDR_WIDTH-1:0] row_addr;
    logic [COL_ADDR_WIDTH-1:0] col_addr;
  } orde_pkt_t;

  // Memory transaction packet type
  typedef struct packed {
    logic                      marker;            // Marker flag used for flagging packets for latency calculation
    logic                      bcast;             // Broadcasted packet flag
    logic [$clog2(PRIO)-1:0]   prio;
    req_t                      req_type;
    logic [BK_ADDR_WIDTH-1:0]  bk_addr;
    logic [ROW_ADDR_WIDTH-1:0] row_addr;
    logic [COL_ADDR_WIDTH-1:0] col_addr;
    logic [MASK_WIDTH-1:0]     mask;              // Data mask used with WDM (2-byte masking) commands
    logic [DATA_WIDTH-1:0]     data;
  } pkt_t;

  // Packet meta-data type used in the Scheduler (uses a pointer to the data instead of the data)
  typedef struct packed {
    logic                            marker;
    logic                            bcast;
    logic [$clog2(PRIO)-1:0]         prio;
    req_t                            req_type;
    logic [BK_ADDR_WIDTH-1:0]        bk_addr;
    logic [ROW_ADDR_WIDTH-1:0]       row_addr;
    logic [COL_ADDR_WIDTH-1:0]       col_addr;
    logic [$clog2(ROWARB_DEPTH)-1:0] data_ptr;
  } pkt_meta_t;

  // ========================================================================================================
  //                                                AUXILIARY
  // ========================================================================================================
  // function automatic shortint unsigned max;
  //   input shortint unsigned a, b;
  //   begin
  //     max = (a > b) ? a : b;
  //   end
  // endfunction

endpackage
