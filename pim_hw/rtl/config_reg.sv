`timescale 1ps / 1ps

import aimc_lib::*;

module config_reg (
  input  logic clk,
  input  logic rst,
  input  logic cfr_we,
  input  logic cfr_re,
  input  logic [CFR_ADDR_WIDTH-1:0]    cfr_addr,
  input  logic [DATA_WIDTH/8-1:0]      cfr_mask,
  input  logic [DATA_WIDTH-1:0]        cfr_din,
  output logic [DATA_WIDTH-1:0]        cfr_dout,
  output logic [$bits(cfr_mode_t)-1:0] cfr_mode_p,
  output logic [$bits(cfr_time_t)-1:0] cfr_time_p,
  output logic [$bits(cfr_refr_t)-1:0] cfr_refr_p,
  output logic [$bits(cfr_schd_t)-1:0] cfr_schd_p,
  output logic [$bits(cfr_adma_t)-1:0] cfr_adma_p);

  // ============================== Signal Declarations =============================
  logic [DATA_WIDTH-1:0] cfr_dout_nxt;
  cfr_mode_t cfr_mode, cfr_mode_nxt;    // Mode Register parameters
  cfr_time_t cfr_time, cfr_time_nxt;    // DRAM timing parameters
  cfr_refr_t cfr_refr, cfr_refr_nxt;    // DRAM refresh parameters
  cfr_schd_t cfr_schd, cfr_schd_nxt;    // Scheduler policies and parameters
  cfr_adma_t cfr_adma, cfr_adma_nxt;    // AiM DMA parameters

  // ================================ Output Signals ================================
  assign cfr_mode_p = cfr_mode;         // Using packed signals as outputs to avoid large number of ports (one per each parameter)
  assign cfr_time_p = cfr_time;
  assign cfr_refr_p = cfr_refr;
  assign cfr_schd_p = cfr_schd;
  assign cfr_adma_p = cfr_adma;

  // =============================== CFR WRITE Access ===============================
  // Assigning internal registers
  always @(posedge clk, posedge rst)
    if (rst) begin 
      cfr_mode <= cfr_mode_init;
      cfr_time <= cfr_time_init;
      cfr_refr <= cfr_refr_init;
      cfr_schd <= cfr_schd_init;
      cfr_adma <= cfr_adma_init;
    end
    else if (cfr_we) begin
      cfr_mode <= cfr_mode_nxt;
      cfr_time <= cfr_time_nxt;
      cfr_refr <= cfr_refr_nxt;
      cfr_schd <= cfr_schd_nxt;
      cfr_adma <= cfr_adma_nxt;
    end

  always_comb begin
    cfr_mode_nxt = cfr_mode;
    cfr_time_nxt = cfr_time;
    cfr_refr_nxt = cfr_refr;
    cfr_schd_nxt = cfr_schd;
    cfr_adma_nxt = cfr_adma;

    case (cfr_addr)
      // Mode Register CFR
      'h000 : begin
        if (cfr_mask[4*0]) cfr_mode_nxt.WL          = cfr_din[32*0+:32];  // Checking mask for only the first byte out of four (32-bit parameters)
        if (cfr_mask[4*1]) cfr_mode_nxt.RL          = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_mode_nxt.CRCWL       = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_mode_nxt.CRCRL       = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_mode_nxt.BK_BCAST    = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_mode_nxt.RELU_MAX    = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_mode_nxt.EWMUL_BG    = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_mode_nxt.AFM         = cfr_din[32*7+:32];
      end
      // DRAM Timing CFR
      'h008 : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tCCD        = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tRC         = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tRAS        = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tRCDRD      = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tRCDWR      = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_time_nxt.tRP         = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_time_nxt.tPPD        = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_time_nxt.tRTP        = cfr_din[32*7+:32];
      end
      'h009 : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tWR         = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tRRD        = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tWTR        = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tRTW        = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tMRD        = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_time_nxt.tMOD        = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_time_nxt.tRREFD      = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_time_nxt.tRFCpb      = cfr_din[32*7+:32];
      end
      'h00A : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tRFCab      = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tREFIpb     = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tREFIab     = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tKO         = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tWRIDON     = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_time_nxt.tRCDRDL     = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_time_nxt.tRCDWRL     = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_time_nxt.tMACD       = cfr_din[32*7+:32];
      end
      'h00B : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tAFD        = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tEWMD       = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tEED        = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tRDCPD      = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tNDMRD      = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_time_nxt.tNDMWR      = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_time_nxt.tWRGBD      = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_time_nxt.tWRGBX      = cfr_din[32*7+:32];
      end
      'h00C : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tWRBIASD    = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tWRBIASX    = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tRDMACD     = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tRDMACX     = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tRDAFD      = cfr_din[32*4+:32];
        if (cfr_mask[4*5]) cfr_time_nxt.tRDAFX      = cfr_din[32*5+:32];
        if (cfr_mask[4*6]) cfr_time_nxt.tWCK2MRS    = cfr_din[32*6+:32];
        if (cfr_mask[4*7]) cfr_time_nxt.tMRSTWCK    = cfr_din[32*7+:32];
      end
      'h00D : begin
        if (cfr_mask[4*0]) cfr_time_nxt.tWCK2TR     = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_time_nxt.tLTLTR      = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_time_nxt.tRCDRTR     = cfr_din[32*2+:32];
        if (cfr_mask[4*3]) cfr_time_nxt.tRCDWTR     = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_time_nxt.tWTRTR      = cfr_din[32*4+:32];
      end
      // Refresh CFR
      'h010 : begin
        if (cfr_mask[4*0]) cfr_refr_nxt.TEMP_RD_PER = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_refr_nxt.REFAB_PER   = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_refr_nxt.REF_POLICY  = ref_policy_t'(cfr_din[32*2+:32]);
        if (cfr_mask[4*3]) cfr_refr_nxt.MTEMP_THR   = cfr_din[32*3+:32];
        if (cfr_mask[4*4]) cfr_refr_nxt.HTEMP_THR   = cfr_din[32*4+:32];
      end
      // Scheduler CFR
      'h018 : begin
        if (cfr_mask[4*0]) cfr_schd_nxt.EDC_EN      = cfr_din[32*0+:32];
        if (cfr_mask[4*1]) cfr_schd_nxt.LOOP_EN     = cfr_din[32*1+:32];
        if (cfr_mask[4*2]) cfr_schd_nxt.ROW_POLICY  = row_policy_t'(cfr_din[32*2+:32]);
        if (cfr_mask[4*3]) cfr_schd_nxt.EXH_THR     = cfr_din[32*3+:32];
      end
      // DMA CFR
      'h020 : begin
        if (cfr_mask[4*0]) cfr_adma_nxt.ADDR_MAP    = addr_map_t'(cfr_din[32*0+:32]);
      end
    endcase
  end

  // ================================ CFR READ Access ===============================
  always @(posedge clk, posedge rst)
    if      (rst)    cfr_dout <= 0;
    else if (cfr_re) cfr_dout <= cfr_dout_nxt;

  // NOTE : CFR MUST BE ADDRESSED USING 32 BYTE ALIGNMENT
  always_comb begin
    cfr_dout_nxt = {DATA_WIDTH{1'b0}};
    case (cfr_addr)
      // Mode Register CFR
      'h000 : begin
        cfr_dout_nxt[32*0+:32] = cfr_mode.WL;
        cfr_dout_nxt[32*1+:32] = cfr_mode.RL;
        cfr_dout_nxt[32*2+:32] = cfr_mode.CRCWL;
        cfr_dout_nxt[32*3+:32] = cfr_mode.CRCRL;
        cfr_dout_nxt[32*4+:32] = cfr_mode.BK_BCAST;
        cfr_dout_nxt[32*5+:32] = cfr_mode.RELU_MAX;
        cfr_dout_nxt[32*6+:32] = cfr_mode.EWMUL_BG;
        cfr_dout_nxt[32*7+:32] = cfr_mode.AFM;
      end
      // DRAM Timing CFR
      'h008 : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tCCD;
        cfr_dout_nxt[32*1+:32] = cfr_time.tRC;
        cfr_dout_nxt[32*2+:32] = cfr_time.tRAS;
        cfr_dout_nxt[32*3+:32] = cfr_time.tRCDRD;
        cfr_dout_nxt[32*4+:32] = cfr_time.tRCDWR;
        cfr_dout_nxt[32*5+:32] = cfr_time.tRP;
        cfr_dout_nxt[32*6+:32] = cfr_time.tPPD;
        cfr_dout_nxt[32*7+:32] = cfr_time.tRTP;
      end
      'h009 : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tWR;
        cfr_dout_nxt[32*1+:32] = cfr_time.tRRD;
        cfr_dout_nxt[32*2+:32] = cfr_time.tWTR;
        cfr_dout_nxt[32*3+:32] = cfr_time.tRTW;
        cfr_dout_nxt[32*4+:32] = cfr_time.tMRD;
        cfr_dout_nxt[32*5+:32] = cfr_time.tMOD;
        cfr_dout_nxt[32*6+:32] = cfr_time.tRREFD;
        cfr_dout_nxt[32*7+:32] = cfr_time.tRFCpb;
      end
      'h00A : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tRFCab;
        cfr_dout_nxt[32*1+:32] = cfr_time.tREFIpb;
        cfr_dout_nxt[32*2+:32] = cfr_time.tREFIab;
        cfr_dout_nxt[32*3+:32] = cfr_time.tKO;
        cfr_dout_nxt[32*4+:32] = cfr_time.tWRIDON;
        cfr_dout_nxt[32*5+:32] = cfr_time.tRCDRDL;
        cfr_dout_nxt[32*6+:32] = cfr_time.tRCDWRL;
        cfr_dout_nxt[32*7+:32] = cfr_time.tMACD;
      end
      'h00B : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tAFD;
        cfr_dout_nxt[32*1+:32] = cfr_time.tEWMD;
        cfr_dout_nxt[32*2+:32] = cfr_time.tEED;
        cfr_dout_nxt[32*3+:32] = cfr_time.tRDCPD;
        cfr_dout_nxt[32*4+:32] = cfr_time.tNDMRD;
        cfr_dout_nxt[32*5+:32] = cfr_time.tNDMWR;
        cfr_dout_nxt[32*6+:32] = cfr_time.tWRGBD;
        cfr_dout_nxt[32*7+:32] = cfr_time.tWRGBX;
      end
      'h00C : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tWRBIASD;
        cfr_dout_nxt[32*1+:32] = cfr_time.tWRBIASX;
        cfr_dout_nxt[32*2+:32] = cfr_time.tRDMACD;
        cfr_dout_nxt[32*3+:32] = cfr_time.tRDMACX;
        cfr_dout_nxt[32*4+:32] = cfr_time.tRDAFD;
        cfr_dout_nxt[32*5+:32] = cfr_time.tRDAFX;
        cfr_dout_nxt[32*6+:32] = cfr_time.tWCK2MRS;
        cfr_dout_nxt[32*7+:32] = cfr_time.tMRSTWCK;
      end
      'h00D : begin
        cfr_dout_nxt[32*0+:32] = cfr_time.tWCK2TR;
        cfr_dout_nxt[32*1+:32] = cfr_time.tLTLTR;
        cfr_dout_nxt[32*2+:32] = cfr_time.tRCDRTR;
        cfr_dout_nxt[32*3+:32] = cfr_time.tRCDWTR;
        cfr_dout_nxt[32*4+:32] = cfr_time.tWTRTR;
      end
      // Refresh CFR
      'h010 : begin
        cfr_dout_nxt[32*0+:32] = cfr_refr.TEMP_RD_PER;
        cfr_dout_nxt[32*1+:32] = cfr_refr.REFAB_PER;
        cfr_dout_nxt[32*2+:32] = cfr_refr.REF_POLICY;
        cfr_dout_nxt[32*3+:32] = cfr_refr.MTEMP_THR;
        cfr_dout_nxt[32*4+:32] = cfr_refr.HTEMP_THR;
      end
      // Scheduler CFR
      'h018 : begin
        cfr_dout_nxt[32*0+:32] = cfr_schd.EDC_EN;
        cfr_dout_nxt[32*1+:32] = cfr_schd.LOOP_EN;
        cfr_dout_nxt[32*2+:32] = cfr_schd.ROW_POLICY;
        cfr_dout_nxt[32*3+:32] = cfr_schd.EXH_THR;
      end
      // DMA CFR
      'h020 : begin
        cfr_dout_nxt[32*0+:32] = cfr_adma.ADDR_MAP;
      end
    endcase
  end

  // ================================ Initialization ================================
  initial begin
    cfr_dout = 0;
    cfr_mode = cfr_mode_init;
    cfr_time = cfr_time_init;
    cfr_refr = cfr_refr_init;
    cfr_schd = cfr_schd_init;
    cfr_adma = cfr_adma_init;
  end

endmodule
