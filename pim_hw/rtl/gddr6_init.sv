`timescale 1ps / 1ps

import aimc_lib::*;

module gddr6_init (
  input  logic clk,
  input  logic rst,
  output logic init_done,
  // Command Handler Interface
  output logic init_ck_en,
  output logic init_wck_en,
  output pkt_t init_pkt,
  output cmd_t init_cmd,
  output logic init_pkt_valid,
  input  logic intf_rdy,
  // PHY Interface
  input  logic phy_rdy,
  output logic edc_tri,
  output logic [7:0] init_edc [1:0],
  output logic [7:0] init_cke_n,
  // DRAM Interface
  output logic RESET_n);
  
  // ================================ Local Signals ===================================
  // DRAM Interface Variables
  logic RESET_n_r1;                                // Register used to delay RESET_n by one additional clock cycle due to all other signals also being delayed in XIPHY
  logic reset_n_nxt;
  logic [7:0] cke_n_nxt;
  // Command Handler Interface Variable
  logic init_done_nxt, init_ck_en_nxt, init_wck_en_nxt;
  pkt_t init_pkt_nxt;
  cmd_t init_cmd_nxt;
  logic init_pkt_valid_nxt;
  // Internal Variables
  enum logic [4:0] {IDLE=0, RESET, INIT_CONF, INIT_CKE, ISSUE_REF, CAT,
  INIT_MR0, INIT_MR1, INIT_MR2, INIT_MR3, INIT_MR4, INIT_MR5, INIT_MR6, INIT_MR7, 
  INIT_MR8, INIT_MR9, INIT_MR10, INIT_MR11, INIT_MR12, INIT_MR13, INIT_MR14, INIT_MR15} stage, stage_nxt;
  logic [1:0] step, step_nxt;                      // General use counter for sequentially performing steps in each FSM state
  logic [1:0] mrs_step, mrs_step_nxt;              // Step counter specifically used in issue_mrs() task
  int unsigned wait_cnt, wait_cnt_nxt;
  logic init_done_r0, init_done_r1, init_done_r2;  // Register chain that the implementation tool can use to mitigate high fan-out
  logic wait_done;
  logic mrs_done;
  logic ref_cnt, ref_cnt_nxt;
  // EDC Variables
  logic edc_tri_nxt;
  logic [7:0] edc_ser_nxt [1:0];

  // ============================= Registers and Counters =============================
  // Register chain for "init_done"
  always @(posedge clk, posedge rst)
    if (rst) begin
      init_done_r1 <= 0;
      init_done_r2 <= 0;
      init_done    <= 0;
    end
    else begin
      init_done_r1 <= init_done_r0;
      init_done_r2 <= init_done_r1;
      init_done    <= init_done_r2;
    end

  // DRAM RESET_n Register
  always @(posedge clk, posedge rst)
    if (rst) RESET_n <= 1;
    else     RESET_n <= RESET_n_r1;      // Delaying RESET_n one additional clock cycle since all signals are delayed by 1 CK at prog_delay in XIPHY

  always @(posedge clk, posedge rst)
    if (rst) RESET_n_r1 <= 1;
    else     RESET_n_r1 <= reset_n_nxt;

  // PHY Interface Output Registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      edc_tri     <= 1;
      init_edc[1] <= 8'hFF;
      init_edc[0] <= 8'hFF;
      init_cke_n  <= 8'hFF;
    end
    else begin
      edc_tri     <= edc_tri_nxt;
      init_edc[1] <= edc_ser_nxt[1];
      init_edc[0] <= edc_ser_nxt[0];
      init_cke_n  <= cke_n_nxt;
    end

  // Command Handler Interface Output Registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      init_done_r0   <= 0;
      init_pkt       <= 0;
      init_cmd       <= NOP1;
      init_pkt_valid <= 0;
      init_ck_en     <= 0;
      init_wck_en    <= 0;
    end
    else begin
      init_done_r0   <= init_done_nxt;
      init_pkt       <= init_pkt_nxt;
      init_cmd       <= init_cmd_nxt;
      init_pkt_valid <= init_pkt_valid_nxt;
      init_ck_en     <= init_ck_en_nxt;
      init_wck_en    <= init_wck_en_nxt;
    end

  // Internal Registers
  always @(posedge clk, posedge rst)
    if (rst) begin
      stage    <= RESET;
      step     <= 0;
      mrs_step <= 0;
    end
    else begin
      stage    <= stage_nxt;
      step     <= step_nxt;
      mrs_step <= mrs_step_nxt;
    end

  // Delay Counter
  always @(posedge clk, posedge rst)
    if (rst) wait_cnt <= 0;
    else     wait_cnt <= wait_cnt_nxt;
  assign wait_done = (wait_cnt == 1);

  // Refresh Counter
  always @(posedge clk, posedge rst)
    if (rst) ref_cnt <= 0;
    else     ref_cnt <= ref_cnt_nxt;

  // =========================== GDDR6 Initialization FSM =============================
  always_comb begin
    // DRAM Interface
    reset_n_nxt        = RESET_n_r1;
    // PHY Interface
    edc_tri_nxt        = edc_tri;
    edc_ser_nxt[1]     = init_edc[1];
    edc_ser_nxt[0]     = init_edc[0];
    cke_n_nxt          = init_cke_n;
    // Command Handler Interface
    init_done_nxt      = init_done_r0;
    init_pkt_nxt       = init_pkt;
    init_cmd_nxt       = init_cmd;
    init_pkt_valid_nxt = init_pkt_valid;
    init_ck_en_nxt     = init_ck_en;
    init_wck_en_nxt    = init_wck_en;
    // Internal Signals
    stage_nxt          = stage;
    step_nxt           = step;
    mrs_step_nxt       = mrs_step;
    wait_cnt_nxt       = (wait_cnt == 0) ? 0 : wait_cnt - 1'b1;
    ref_cnt_nxt        = ref_cnt;
    mrs_done           = 0;

    case (stage)
      IDLE : begin
        // No Special Actions
      end

      RESET : begin
        if (phy_rdy)
          if (INIT_BYPASS == "TRUE") begin
            stage_nxt          = IDLE;
            init_done_nxt      = 1;
            init_ck_en_nxt     = 1;
            init_wck_en_nxt    = 1;
            cke_n_nxt          = 0;
          end
          else begin
            stage_nxt          = INIT_CONF;
            init_cmd_nxt       = CONF;
            init_pkt_valid_nxt = 1;
          end
      end

      // Issue Reset and Set System Configuration
      INIT_CONF : begin
        case (step)
          // Asserting RESET_n for tINIT1
          0 : begin              
            step_nxt       = 1;
            reset_n_nxt    = 0;
            `ifdef XILINX_SIMULATOR
            wait_cnt_nxt   = 1*ck_adj(tUS);
            `else
            wait_cnt_nxt   = 200*ck_adj(tUS);
            `endif
          end
          // Setting system configuration using CA and EDC buses
          1 : begin              
            if (wait_done) begin
              edc_tri_nxt  = 0;  // Driving EDC bus from controller
              step_nxt     = 2;
              wait_cnt_nxt = 0.1*ck_adj(tUS);//8;
            end
          end
          // Maintaining CA state for tATH (10 ns) after RESET_n is deasserted
          2 : begin              
            if (wait_done) begin
              reset_n_nxt  = 1;
              step_nxt     = 3;
              wait_cnt_nxt = 0.1*ck_adj(tUS);//8;
            end
          end
          3 : begin
            if (wait_done) begin
              init_pkt_valid_nxt = 0;
              edc_tri_nxt  = 1;
              step_nxt     = 0;
              stage_nxt    = INIT_CKE;
            end
          end
        endcase
      end

      // Set Address and Command Termination
      INIT_CKE : begin
        case (step)
          0 : begin                       // Asserting CKE_n and waiting for tINIT2
            step_nxt         = 1;
            cke_n_nxt        = 0;
            `ifdef XILINX_SIMULATOR
            wait_cnt_nxt   = 1*ck_adj(tUS);
            `else
            wait_cnt_nxt   = 1000*ck_adj(tUS);
            `endif
          end
          1 : begin                       // Enabling CK_t/CK_c and waiting for tINIT3
            if (wait_done) begin
              step_nxt       = 2;
              init_ck_en_nxt = 1;
              wait_cnt_nxt   = 100;       // Waiting for tINIT3 after enabling the CK
            end
          end
          2 : begin
            if (wait_done) begin
              stage_nxt      = INIT_MR10; // MR10 contains information about WCK Termination, need to set it first
              step_nxt       = 0;
            end
          end
        endcase
      end

      // Perform Command Address Training
      CAT : begin
        /* Skipping CAT */
      end

      // Set MR10: WCK_Termination, WCK_Ratio, WCK2CK, WCK_Inv_B1, WCK_Inv_B0, VREFC_Offset
      INIT_MR10 : begin
        issue_mrs(.MR(4'hA), .A({2'b00, 1'b0, 1'b0, 2'b00, 2'b00, 4'b0000}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) begin
          stage_nxt = INIT_MR0;
          init_wck_en_nxt = 1; // Enabling WCK after setting corresponding termination values
        end
      end

      // Set MR0: WR, TM, RLmrs, WLmrs
      INIT_MR0 : begin
        issue_mrs(.MR(4'h0), .A({4'b0000, 1'b0, RLmr0, WLmr0}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR1;
      end

      // Set MR1: PLL_Reset, CABI, WDBI, RDBI, PLL_DLL, Cal_Upd, PLL_DLL_Range, Data_Termination, Driver_Strength
      INIT_MR1 : begin
        issue_mrs(.MR(4'h1), .A({1'b0, CABImr1, WDBImr1, RDBImr1, 1'b0, 1'b1, 2'b00, 2'b00, 2'b00}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR2;
      end

      // Set MR2: EDC_HR, CADT_SRF, RDQS, RDC_Mode, Self_Refresh, OCD_Pullup_Driver_Offset, OCD_Pulldown_Driver_Offset
      INIT_MR2 : begin
        issue_mrs(.MR(4'h2), .A({1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 3'b000, 3'b000}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR3;
      end

      // Set MR3: Bank_Groups, WR_Scaling, Info, CA_Termination_Offset, DQ_WCK_Termination_Offset
      INIT_MR3 : begin
        issue_mrs(.MR(4'h3), .A({BGmr3, 2'b00, 2'b00, 3'b000, 3'b000}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR4;
      end

      // Set MR4: EDC_Inv, WR_CRC, RD_CRC, CRC_Read_Latency, CRC_Write_Latency, EDC_Hold_Pattern
      INIT_MR4 : begin
        issue_mrs(.MR(4'h4), .A({EDC_Inv, WCRCmr4, RCRCmr4, CRCRLmr4, CRCWLmr4, EDC_Hold}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR5;
      end

      // Set MR5: RAS, PLL_DLL_Bandwidth, LP3, LP2, PL1
      INIT_MR5 : begin
        issue_mrs(.MR(4'h5), .A({6'b000001, 3'b000, 1'b0, 1'b0, 1'b0}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR6;
      end

      // Set MR6: Pin_Sub_Address, VREFD_Level
      INIT_MR6 : begin
        issue_mrs(.MR(4'h6), .A({5'b00000, 7'b0101010}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR7;
      end

      // Set MR7: DCC, VDD_Range, Half_VREFD, Half_VREFC, DQ_PreA, Auto_Sync, LF_Mode, PLL_DelC, Hibernate, WCK_AP
      INIT_MR7 : begin
        issue_mrs(.MR(4'h7), .A({2'b00, 2'b00, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR8;
      end

      // Set MR8: CK_Termination, WR_EHF, RL_EHF, REFpb, CK_AC, EDC_HiZ, CA_TO, CAH_Termination, CAL_Termination
      INIT_MR8 : begin
        issue_mrs(.MR(4'h8), .A({2'b00, 1'b0, RLmr8, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, 2'b00}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR9;
      end

      // Set MR9: Pin_Sub_Address, -, Decision_Feedback_Equalization
      INIT_MR9 : begin
        issue_mrs(.MR(4'h9), .A({5'b00000, 3'b000, 4'b0000}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR11;
      end

      // Set MR11: PASR_Row_Segment_Mask, PASR_2_Bank_Mask
      INIT_MR11 : begin
        issue_mrs(.MR(4'hB), .A({4'b0000, 8'b0000_0000}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR12;
      end

      // Set MR12: -, PRBS, P2BR_Addr, VDDQ_OFF
      INIT_MR12 : begin
        issue_mrs(.MR(4'hC), .A({9'b0_0000_0000, 1'b0, 1'b0, 1'b0}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR13;
      end

      // Set MR13: NDM, AFM, -, ReLU_Max, Broadcast
      INIT_MR13 : begin
        issue_mrs(.MR(4'hD), .A({1'b0, cfr_mode_init.AFM, 4'b0000, cfr_mode_init.RELU_MAX, cfr_mode_init.BK_BCAST}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR14;
      end

      // Set MR14: -, EWMUL_BG, -, Thread
      INIT_MR14 : begin
        issue_mrs(.MR(4'hE), .A({3'b000, cfr_mode_init.EWMUL_BG, 7'b000_0000, 1'b0}), .tDEL(cfr_time_init.tMRD));
        if (mrs_done) stage_nxt = INIT_MR15;
      end

      // Set MR15: Leaky_ReLU, Leaky_ReLU_Page, CADT, MRE
      INIT_MR15 : begin
        issue_mrs(.MR(4'hF), .A({6'b00_0000, 2'b00, 2'b00, 2'b00}), .tDEL(cfr_time_init.tMOD));
        if (mrs_done) stage_nxt = ISSUE_REF;
      end

      // Issue two REFRESH Commands
      ISSUE_REF : begin
        case (step)
          0 : begin
            init_cmd_nxt = REFAB;
            if (intf_rdy) begin
              init_pkt_valid_nxt = 1;
              step_nxt           = 1;
              wait_cnt_nxt       = (cfr_time_init.tRFCab > 1) ? cfr_time_init.tRFCab - 1 : 1;  // Resulting delay will be at least 2 clock cycles
            end
          end
          1 : begin
            init_pkt_valid_nxt = 0;
            if (wait_done) begin
              step_nxt    = 0;
              ref_cnt_nxt = ~ref_cnt;
              if (ref_cnt) begin
                stage_nxt     = IDLE;
                init_done_nxt = 1;
              end
            end
          end
        endcase // step
      end

    endcase // stage
  end

  // ================================= Local Tasks ====================================
  task issue_mrs;
    input logic [3:0]  MR;
    input logic [11:0] A;
    input shortint tDEL;    // Time to wait after issuing an MRS command

    begin
      init_pkt_valid_nxt = 0;
      case (mrs_step)
        0 : begin
          init_cmd_nxt          = MRS;
          init_pkt_nxt.bk_addr  = MR;
          init_pkt_nxt.row_addr = A;
          if (intf_rdy) begin
            init_pkt_valid_nxt  = 1;
            mrs_step_nxt        = 1;
            if (ck_adj(tDEL) == 1) begin
              mrs_done     = 1;
              mrs_step_nxt = 0;
            end
            else
              wait_cnt_nxt = ck_adj(tDEL) - 1; // "-1" is needed because of FSM implementation method; If tDEL == 1, the abofe "if" condition is used
          end
        end
        1 : begin
          if (wait_done) begin
            mrs_done     = 1;
            mrs_step_nxt = 0;
          end
        end
      endcase
    end
  endtask

  function automatic logic [31:0] ck_adj;
    input logic [31:0] t;
    begin
      if (GLOBAL_CLK == "CK_DIV2") ck_adj = (t >> 1) + t[0];  // Rounding up
      else                         ck_adj = t;
    end
  endfunction

  // ================================== Initialization ================================
  initial begin
    // DRAM Interface Output Registers
    RESET_n_r1     = 1;
    RESET_n        = 1;
    // PHY Interface Output Registers
    edc_tri        = 1;
    init_edc[1]    = 8'hFF;
    init_edc[0]    = 8'hFF;
    init_cke_n     = 8'hFF;
    // Command Handler Interface Output Registers
    init_done_r0   = 0;
    init_done_r1   = 0;
    init_done_r2   = 0;
    init_done      = 0;
    init_pkt       = 0;
    init_cmd       = NOP1;
    init_pkt_valid = 0;
    init_ck_en     = 0;
    init_wck_en    = 0;
    // Internal Registers
    stage          = IDLE;
    step           = 0;
    wait_cnt       = 0;
    ref_cnt        = 0;
  end

 //debug
//  (* keep = "true", mark_debug = "true" *) reg               debug_phy_rdy;
//  (* keep = "true", mark_debug = "true" *) reg               debug_mrs_done;

//    always @(posedge clk, posedge rst)
//    if (rst) begin
//                        debug_phy_rdy    <= 'b0;
//                        debug_mrs_done   <= 'b0;
//    end
//    else begin
//                        debug_phy_rdy    <= phy_rdy ;
//                        debug_mrs_done   <= mrs_done;
//    end

endmodule
