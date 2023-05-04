`timescale 1ps / 1ps

import aimc_lib::*;

//`define RH 1

module calib_ptngen (
  input  logic clk,
  input  logic rst,
  // Calibration Handler Interface
  input  logic         cal_pgen_start,
  input  logic [511:0] param,
  input  logic [31:0]  march_len,
  input  logic [11:0]  pgen_rd_ptr,
  output logic [287:0] pgen_dout,
  output logic         pgen_done,
  // Scheduler Interface
  input  logic         sched_rdy,
  output logic         pgen_pkt_valid,
  output pkt_t         pgen_pkt,
  // Data Handler Interface
  input  logic         intf_pkt_valid,
  input  pkt_t         intf_pkt);
  
  // =================================== Internal Signals ===================================
  // Pattern Generator Memory Signals
  logic         pgen_mem_we;                     // Pattern generator memory write enable
  logic         pgen_mem_ce;                     // Pattern generator memory clock enable
  logic [11:0]  pgen_mem_addr;                   // Pattern generator memory address
  logic [287:0] pgen_mem_din;                    // Pattern generator memory input data
  logic [287:0] pgen_mem_dout;                   // Pattern generator memory output data
  // FSM Signals
  typedef enum logic [5:0] {PGEN_IDLE=0, PGEN_XMC, PGEN_FXMC, PGEN_WAIT} pgen_state_t;
  pgen_state_t pgen_state, pgen_state_nxt;       // FSM state
  logic [15:0] ptn_cnt, ptn_cnt_nxt;             // Counter for counting number of issued packets
  logic [15:0] pgen_wr_ptr, pgen_wr_ptr_nxt;     // Memory write pointer
  pkt_t        pgen_pkt_nxt;                     // Next state for the pgen_pkt
  logic        pgen_pkt_valid_nxt;               // Next state for the pgen_pkt_valid
  logic        pgen_done_nxt;                    // Next state for the pgen_done
  // Parameters
  logic [31:0] P [15:0];                         // An unpacked array of parameters
  logic [5:0]  march_type;                        // March type parameter
  logic [5:0]  data_type;                        // Data type parameter

  logic [3:0] step,step_next; // 0 ~ 7 steps for sub-FSM 
  logic [3:0] pre_step,pre_step_next; // 0 ~ 7 steps for sub-FSM 
  pkt_t       pkt_temp, pkt_temp_next;       
  
  // Full XMATCH pattern Signals
  req_t                      xmc_state_con_type;  // Next State Condition for Full XMC pattern: Reqest Type
  logic [ROW_ADDR_WIDTH-1:0] xmc_state_con_row;   // Next State Condition for Full XMC pattern: Row Address
  logic [COL_ADDR_WIDTH-1:0] xmc_state_con_col;   // Next State Condition for Full XMC pattern: Column Address
  logic                      req_type_swap;       // indicates only changing the request type 

  // Data Check Output Signals
  logic                      dc_wait_done;
  //logic                      dc_timeout;
  logic                      dc_mem_we;  
  logic [11:0]               dc_mem_addr;
  logic [287:0]              dc_mem_din; 


  // Test for Row-Hammering (pause timer)
  logic                      pause_timer_flag;
  logic [31:0]               pause_timer, pause_timer_next;
  `ifdef RH
  logic [19:0]               rh_cnt,rh_cnt_next;
  logic [ROW_ADDR_WIDTH-1:0] rh_targer_row_lo,rh_targer_row_lo_next;
  logic [ROW_ADDR_WIDTH-1:0] rh_targer_row_hi,rh_targer_row_hi_next;
  logic [COL_ADDR_WIDTH-1:0] rh_targe_col,rh_targe_col_next;
  `endif

  // ====================================== Parameters ======================================
  always_comb begin
    P = '{16{0}};
    for (int idx=0; idx<16; idx++) begin
      P[idx] = param[idx*32+:32];
    end
  end

  assign march_type = P[0][5:0];
  assign data_type  = P[1][5:0];

  // ================================ Pattern Generator Memory ==============================
  generate
    if (PTNGEN_EN == "TRUE") begin : ptnGen
      xpm_memory_spram #(
        .ADDR_WIDTH_A        (12),               // Address port width in bits: 1-20 bits
        .AUTO_SLEEP_TIME     (0),                // Number of cycles to auto-sleep: 0 - disable, 3-15 - number of cycles
        .BYTE_WRITE_WIDTH_A  (288),              // Byte width: 8-9; Or word width: 1-4608
        .CASCADE_HEIGHT      (0),                // Cascade hight: 0 - let Vivado choose, 1-64 - sets specific cascade hight
        .ECC_MODE            ("no_ecc"),         // Use ECC: no_ecc, encode_only, decode_only, both_encode_and_decode
        .MEMORY_INIT_FILE    ("none"),           // Memory initialization file: none, my_file.mem
        .MEMORY_INIT_PARAM   ("0"),              // Memory initialization parameter: 0, HEX string
        .MEMORY_OPTIMIZATION ("true"),           // Enable optimization of unused memory in the memory structure: true, false
        .MEMORY_PRIMITIVE    ("ultra"),          // Memory type: auto, block, distributed, ultra
        .MEMORY_SIZE         (4096*288),         // Memory size in bits, e.g. 65563 for a 2kx32 RAM: 2-150994944
        .MESSAGE_CONTROL     (0),                // Enable dynamic message reporting such as collision warnings: 0-1
        .READ_DATA_WIDTH_A   (288),              // Read port width: 1-4608
        .READ_LATENCY_A      (1),                // Read latency: 0-100
        .READ_RESET_VALUE_A  ("0"),              // Reset value of the read port: HEX string
        .RST_MODE_A          ("SYNC"),           // Reset behavior: sync, async
        .SIM_ASSERT_CHK      (1),                // Simulation message reporting: 0-1
        .USE_MEM_INIT        (1),                // Enable memory initialization messages: 0-1
        .WAKEUP_TIME         ("disable_sleep"),  // Dynamic power saving: disable_sleep, use_sleep_pin
        .WRITE_DATA_WIDTH_A  (288),              // Write port width: 1-4608
        .WRITE_MODE_A        ("read_first"))     // Write mode behavior for the output port: read_first, no_change, write_first
      pgen_mem (
        .clka                (clk),
        .rsta                (rst),
        .ena                 (pgen_mem_ce),      // 1-bit in: Memory enable signal
        .wea                 (pgen_mem_we),      // WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH bit in: Write enable for each byte
        .addra               (pgen_mem_addr),
        .dina                (pgen_mem_din),
        .douta               (pgen_mem_dout),
        .dbiterra            (),                 // 1-bit out: Indicates double bit error occurance
        .sbiterra            (),                 // 1-bit out: Indicates dingle bit error occurance
        .injectdbiterra      (0),                // 1-bit in: Single bit error injection
        .injectsbiterra      (0),                // 1-bit in: Double bit error injection
        .regcea              (1),                // 1-bit in: clock enable for the last register on the output data path
        .sleep               (0));               // 1-bit in: Enables dynamic power saving

      assign pgen_dout = pgen_mem_dout;
    end
    else begin
      assign pgen_dout = 0;
    end
  endgenerate


  // ================================ Pattern Generation FSM ================================
  always @(posedge clk, posedge rst)
    if (rst) begin
      pgen_state     <= PGEN_IDLE;
      ptn_cnt        <= 0;
      pgen_pkt       <= 0;
      pgen_pkt_valid <= 0;
      pgen_done      <= 0;
      pgen_wr_ptr    <= 0;
      step           <= 0; // eaech pattern sub-fsm
      pre_step       <= 0;
      `ifdef RH
        rh_cnt         <= 0;
      `endif
      pkt_temp       <= 0;
    end
    else begin
      pgen_state     <= pgen_state_nxt;
      ptn_cnt        <= ptn_cnt_nxt;
      pgen_pkt       <= pgen_pkt_nxt;
      pgen_pkt_valid <= pgen_pkt_valid_nxt;
      pgen_done      <= pgen_done_nxt;
      pgen_wr_ptr    <= pgen_wr_ptr_nxt;
      step           <= step_next;
      pre_step       <= pre_step_next;
      `ifdef RH
      rh_cnt         <= rh_cnt_next;
      `endif
      pkt_temp       <= pkt_temp_next;
    end

  always_comb begin
    // FSM Signals
    pgen_state_nxt     = pgen_state;
    ptn_cnt_nxt        = ptn_cnt;
    pgen_pkt_nxt       = pgen_pkt;
    pkt_temp_next      = pkt_temp;
    pgen_pkt_valid_nxt = 0;
    pgen_done_nxt      = 0;
    step_next          = step;
    pre_step_next      = pre_step;
    `ifdef RH
    rh_cnt_next        = rh_cnt;
    `endif
    // Memory Access Signals
    pgen_mem_ce        = 1;
    pgen_mem_we        = dc_mem_we;    
    pgen_mem_addr      = dc_mem_addr;  
    pgen_mem_din       = dc_mem_din;   
    pgen_wr_ptr_nxt    = dc_mem_addr + pgen_mem_we;


    case (pgen_state)
      // [IDLE State for Reading Pattern Data]
      PGEN_IDLE : begin
        pgen_mem_ce     = 1;                          // Keeping read memory continuously enabled (perhaps need to implement switching for better power efficiency)
        pgen_mem_we     = 0;                          // The user is only allowed to read the data in the PGEN_IDLE state
        pgen_mem_addr   = pgen_rd_ptr;
        pgen_mem_din    = 0;
        pgen_wr_ptr_nxt = 0;
        

        if (cal_pgen_start) begin
          ptn_cnt_nxt        = (march_len == 0) ? 0 : march_len - 1'b1;  // Initializing the counter at one position below the number of packets we want to send; minimum is 1 packet
          pgen_pkt_valid_nxt = 1'b1;
          step_next          = 0;
          `ifdef RH
          rh_cnt_next        = 0;
          `endif
          pre_step_next      = 0;
          case (march_type)
            6'd0    : pgen_state_nxt = PGEN_XMC;
            6'd1    : pgen_state_nxt = PGEN_FXMC;
            default : pgen_done_nxt  = 1'b1;          // If march type is not one of the expected types, simply return "done" status
          endcase

          // Initializing the Packet
          case (march_type)  
          6'd1: begin  
          pgen_pkt_nxt.req_type = WRITE;
          pgen_pkt_nxt.row_addr = P[5][ROW_ADDR_WIDTH-1:0];
          pgen_pkt_nxt.col_addr = P[6][COL_ADDR_WIDTH-1:0];
          pgen_pkt_nxt.bk_addr  = P[4][ROW_ADDR_WIDTH-1:0];            
          end 
          default : begin             
          pgen_pkt_nxt.req_type = WRITE;
          pgen_pkt_nxt.row_addr = 0;
          pgen_pkt_nxt.col_addr = 0;
          pgen_pkt_nxt.bk_addr  = 0;
          end
          endcase

          case (data_type)
            6'd0 : pgen_pkt_nxt.data = {256{1'b0}};
            6'd1 : pgen_pkt_nxt.data = {256{1'b1}};
            6'd2 : pgen_pkt_nxt.data = {{128{1'b0}}, {128{1'b1}}};
            6'd3 : pgen_pkt_nxt.data = {8{32'h0000FFFF}};
            6'd4 : pgen_pkt_nxt.data = {8{32'hAAAA5555}};
            6'd5 : pgen_pkt_nxt.data = {224'd0, 4'd0, pgen_pkt_nxt.bk_addr, 2'd0, pgen_pkt_nxt.row_addr, 2'd0, pgen_pkt_nxt.col_addr};
          endcase
          
          pgen_pkt_nxt.prio  = 0;
        end
      end

      // [X-MARCH Pattern] - Scrolling through rows first, columns second; Bank kept constatnt
      PGEN_XMC : begin
        pgen_pkt_valid_nxt = 1'b1;  // Holding validity flag asserted until all packets are transmitted

        if (sched_rdy) begin
          pgen_pkt_nxt.row_addr = (pgen_pkt.row_addr == 14'd63) ? 14'd0 : (pgen_pkt.row_addr + 1'b1);
          pgen_pkt_nxt.col_addr = (pgen_pkt.row_addr == 14'd63) ? pgen_pkt.col_addr + 1'b1 : pgen_pkt.col_addr;
          ptn_cnt_nxt           = ptn_cnt - 1'b1;

          case (data_type)
            6'd5    : pgen_pkt_nxt.data = {8'd0, pgen_pkt_nxt.bk_addr, 2'd0, pgen_pkt_nxt.row_addr, 2'd0, pgen_pkt_nxt.col_addr};
            default : pgen_pkt_nxt.data = pgen_pkt.data;
          endcase

          if (ptn_cnt == 0) begin
            pgen_state_nxt        = (pgen_pkt.req_type == WRITE) ? PGEN_XMC : PGEN_WAIT;  // Switching to READ or finalizing
            ptn_cnt_nxt           = (pgen_pkt.req_type == WRITE) ? ((march_len == 0) ? 0 : march_len - 1'b1) : 0;
            pgen_pkt_nxt.req_type = READ;
            pgen_pkt_nxt.row_addr = 0;
            pgen_pkt_nxt.col_addr = 0;
            pgen_pkt_nxt.bk_addr  = 0;
          end
        end
      end



      // [Full X/Y-MARCH Pattern] 
      PGEN_FXMC : begin

        pgen_pkt_valid_nxt = (step == 4 || step == 5 || step == 6 || step == 8) ? 1'b0 : 1'b1;
        step_next = step;

        if (sched_rdy) begin
          
          xmc_state_con_type = WRITE;
          xmc_state_con_row  = P[8][ROW_ADDR_WIDTH-1:0];
          xmc_state_con_col  = P[9][COL_ADDR_WIDTH-1:0];

          case(step)
            4: begin 
                 if(dc_wait_done) step_next = 0;
            end
            6: begin 
              
              if(pause_timer_flag) begin 
                if(P[2][3] == 1) begin
                 step_next = pre_step;
                 pgen_pkt_nxt = pkt_temp;
                end
                `ifdef RH 
                else begin 
                 step_next = 7;       
                end
                `endif
              end
              
            end
            `ifdef RH
            7: begin 
              if(rh_cnt == P[11][19:0]) begin 
                //pgen_pkt_nxt = pkt_temp;
                pgen_pkt_nxt.row_addr = P[8][ROW_ADDR_WIDTH-1:0];
                pgen_pkt_nxt.col_addr = P[9][COL_ADDR_WIDTH-1:0];                
                step_next = 8;
              end
              else begin 
                if(rh_cnt[0] == 0) begin 
                  pgen_pkt_nxt.row_addr = rh_targer_row_hi;
                  pgen_pkt_nxt.col_addr = rh_targe_col;                                  
                end
                else begin 
                  pgen_pkt_nxt.row_addr = rh_targer_row_lo;
                  pgen_pkt_nxt.col_addr = rh_targe_col;                                                    
                end
                rh_cnt_next = rh_cnt + 1;
              end
            end
            `endif
            8: begin 
            if(pause_timer_flag) step_next = 2; 
            end
            0,1,2,3 : begin if(pgen_pkt_valid && pgen_pkt_valid_nxt) begin 
                `ifdef RH
                rh_cnt_next = 0;
                `endif
                if(step == 3) xmc_state_con_type = READ;
                if(step == 2) begin 
                  xmc_state_con_row  = P[5][ROW_ADDR_WIDTH-1:0];
                  xmc_state_con_col  = P[6][COL_ADDR_WIDTH-1:0];
                end            
                // sub-FSM (step) transition according to some conditions 
                if(pgen_pkt.req_type == xmc_state_con_type && xmc_state_con_row == pgen_pkt.row_addr && xmc_state_con_col == pgen_pkt.col_addr) begin 
                  step_next = step + 1;
                  case(step)
                  `ifdef RH 1: if(P[2][2] == 1) step_next = 6; `endif
                  3: if(pgen_pkt.bk_addr == P[7][BK_ADDR_WIDTH-1:0]) step_next = 5;
                  endcase

                  pgen_pkt_nxt.req_type  = (step == 3) ? WRITE : READ;
                  pgen_pkt_nxt.bk_addr   = (step == 3 && step_next != 5) ? pgen_pkt.bk_addr + 1 : pgen_pkt.bk_addr;
                  pgen_pkt_nxt.row_addr  = (step == 0 || step == 2 || step == 3) ? P[5][ROW_ADDR_WIDTH-1:0] : `ifdef RH (P[2][2] == 1) ? rh_targer_row_lo : `endif P[8][ROW_ADDR_WIDTH-1:0];
                  pgen_pkt_nxt.col_addr  = (step == 0 || step == 2 || step == 3) ? P[6][COL_ADDR_WIDTH-1:0] : `ifdef RH (P[2][2] == 1) ? rh_targe_col     : `endif P[9][COL_ADDR_WIDTH-1:0];

                  if(step != step_next) pgen_pkt_nxt.data = (step == 0 || step == 1) ? ~pgen_pkt.data : pgen_pkt.data;
                 
                 pkt_temp_next = pgen_pkt_nxt;
                  if(P[2][3] == 1 && step != 3) begin 
                    pre_step_next = step_next;
                    step_next = 6;
                  end
                  
                end
      
                if(step == step_next) begin // Not sub-FSM transition and generation new request by incresing/decreseing adress or swaping request type. 
                  req_type_swap = 0;
                  if(pgen_pkt.req_type == READ) 
                    if(step == 1 || step == 2) req_type_swap = 1;
    
                  if(req_type_swap)  begin 
                    pgen_pkt_nxt.req_type = WRITE;
                  end
                  else begin 
                    if(step == 2) begin 
                      pgen_pkt_nxt.row_addr = (P[3][0] == 1'b0) ? ((pgen_pkt.row_addr == P[5][ROW_ADDR_WIDTH-1:0]) ? P[8][ROW_ADDR_WIDTH-1:0]   : (pgen_pkt.row_addr - 1'b1)) : 
                                                                  ((pgen_pkt.col_addr == P[6][COL_ADDR_WIDTH-1:0]) ? (pgen_pkt.row_addr - 1'b1) :  pgen_pkt.row_addr)         ; 
                      pgen_pkt_nxt.col_addr = (P[3][0] == 1'b0) ? ((pgen_pkt.row_addr == P[5][ROW_ADDR_WIDTH-1:0]) ? pgen_pkt.col_addr - 1'b1   :  pgen_pkt.col_addr)         :                                                        
                                                                  ((pgen_pkt.col_addr == P[6][COL_ADDR_WIDTH-1:0]) ? P[9][COL_ADDR_WIDTH-1:0]   : (pgen_pkt.col_addr - 1'b1) );
                    end
                    else begin 
                      pgen_pkt_nxt.row_addr = (P[3][0] == 1'b0) ?  ((pgen_pkt.row_addr == P[8][ROW_ADDR_WIDTH-1:0]) ? P[5][ROW_ADDR_WIDTH-1:0]   : (pgen_pkt.row_addr + 1'b1)):
                                                                   ((pgen_pkt.col_addr == P[9][COL_ADDR_WIDTH-1:0]) ? (pgen_pkt.row_addr + 1'b1) :  pgen_pkt.row_addr        );
                      pgen_pkt_nxt.col_addr = (P[3][0] == 1'b0) ?  ((pgen_pkt.row_addr == P[8][ROW_ADDR_WIDTH-1:0]) ? pgen_pkt.col_addr + 1'b1 :    pgen_pkt.col_addr)        :                                                             
                                                                   ((pgen_pkt.col_addr == P[9][COL_ADDR_WIDTH-1:0]) ? P[6][COL_ADDR_WIDTH-1:0]   : (pgen_pkt.col_addr + 1'b1));

                    end
                    //pgen_pkt_nxt.bk_addr   = pgen_pkt.bk_addr; 
                    pgen_pkt_nxt.req_type  = (step == 0) ? WRITE: READ;                           
                  end

                end
  
                case (data_type)
                  6'd5    : pgen_pkt_nxt.data = (step == 1 ) ? ~{8'd0, pgen_pkt_nxt.bk_addr, 2'd0, pgen_pkt_nxt.row_addr, 2'd0, pgen_pkt_nxt.col_addr}: 
                                                                {8'd0, pgen_pkt_nxt.bk_addr, 2'd0, pgen_pkt_nxt.row_addr, 2'd0, pgen_pkt_nxt.col_addr};
                  default : pgen_pkt_nxt.data = pgen_pkt_nxt.data;
                endcase                
              end
            end
          endcase
        end
                       
        //pgen_pkt_nxt.prio  = 0;  
        if((dc_wait_done && step == 5)/* || dc_timeout*/) pgen_state_nxt = PGEN_WAIT;

      end      

      // [Gathering READ Responses] - Waiting until all read responses are stored in the memory
      PGEN_WAIT : begin

        case (march_type)
        6'd1: begin
                pgen_state_nxt = PGEN_IDLE;            
                pgen_done_nxt  = 1'b1;
              end
        default : begin             
        if (pgen_wr_ptr_nxt == march_len) begin
          pgen_state_nxt = PGEN_IDLE;
          pgen_done_nxt  = 1'b1;
        end
        end
        endcase        
      end
    endcase
  end

  // ==================================== Initialization ====================================
  initial begin
    // Memory Signals
    pgen_wr_ptr = 0;
    // FSM Signals
    pgen_state     = PGEN_IDLE;
    ptn_cnt        = 0;
    pgen_pkt       = 0;
    pgen_pkt_valid = 0;
    pgen_done      = 0;
  end

  // ====================== Row Hammer Address Generation  =====================


 always @(posedge clk, posedge rst) begin
  if(rst) begin 
    pause_timer_flag <= 1'b0;
    pause_timer      <= 0;
    `ifdef RH
    rh_targer_row_hi <= 0;
    rh_targer_row_lo <= 0;
    rh_targe_col     <= 0;
    `endif    
  end
  else begin 
    pause_timer_flag <= (pause_timer == 0) ? 1'b1 : 1'b0;
    pause_timer      <= pause_timer_next;
    `ifdef RH
    rh_targer_row_hi <= rh_targer_row_hi_next;
    rh_targer_row_lo <= rh_targer_row_lo_next;
    rh_targe_col     <= rh_targe_col_next;;
    `endif
  end
 end

// pause timer 1 -> 4 ns
// pause timer 250 -> 1us 
// pause timer 40,000 -> 16us
// pause timer 40,000,000 -> 16 ms
 always_comb begin
     pause_timer_next = pause_timer;
     case(step)
     6,8 :pause_timer_next = (pause_timer==0) ? 0 : pause_timer - 1;
     default: pause_timer_next = (P[2][3] == 0) ? 2048 : P[12]; // default is 2048
     //default: pause_timer_next = 2048;
     endcase
     `ifdef RH
     case(pgen_state)
       PGEN_IDLE: begin
         rh_targer_row_hi_next = P[10][ROW_ADDR_WIDTH-1:0] + 2; 
         rh_targer_row_lo_next = P[10][ROW_ADDR_WIDTH-1:0] - 2;
         rh_targe_col_next     = P[9][COL_ADDR_WIDTH-1:0]>>1;
       end
       default: begin
         rh_targer_row_hi_next = rh_targer_row_hi;
         rh_targer_row_lo_next = rh_targer_row_lo;
         rh_targe_col_next     = rh_targe_col;
       end
     endcase
     `endif
 end



  // ====================== Expected Data Generation and Error Checker  =====================

  pkt_t intf_pkt_d;
  logic intf_pkt_valid_d;
  
  always @(posedge clk) begin
    intf_pkt_d       <= intf_pkt;
    intf_pkt_valid_d <= intf_pkt_valid;
  end

data_checker u_data_checker(
  //common signals
  .clk,
  .rst,
  //setting paramter signals
  .in_param(P),
  .march_type(march_type),
  .data_type,

  //Control Signal
  .cal_pgen_start,
  .sched_rdy,

  .intf_pkt(intf_pkt_d),
  .intf_pkt_valid(intf_pkt_valid_d && !(step == 7 || step == 8)),
  .resp_rh_pkt_valid(intf_pkt_valid_d && (step == 7 || step == 8)),

  .dc_wait_done,
  //.dc_timeout,
  .dc_mem_we,  
  .dc_mem_addr,
  .dc_mem_din,

  .gen_pkt_valid(pgen_pkt_valid && sched_rdy && !(step == 7)),
  .gen_pkt_type(pgen_pkt.req_type)
  );

  function pkt_t set_packet_address;
    input req_t                  in_req;
    input [BK_ADDR_WIDTH-1   :0] in_bk;
    input [ROW_ADDR_WIDTH-1  :0] in_row;
    input [COL_ADDR_WIDTH-1  :0] in_col;  
    input [1:0]                  in_prio;

    set_packet_address.req_type  = in_req;      
    set_packet_address.bk_addr   = in_bk;
    set_packet_address.row_addr  = in_row;
    set_packet_address.col_addr  = in_col;    
    set_packet_address.prio      = in_prio;    

  endfunction
  

endmodule
