module data_checker (
  //common signals
  input  logic         clk,
  input  logic         rst,
  //setting paramter signals
  input  logic [31:0]  in_param [15:0],
  input  logic [5:0]   march_type,
  input  logic [5:0]   data_type,

  //Control Signal
  input  logic         cal_pgen_start,
  input  logic         sched_rdy,

  input  pkt_t         intf_pkt,
  input  logic         intf_pkt_valid,
  input  logic         resp_rh_pkt_valid,

  output logic         dc_wait_done,
  //output logic         dc_timeout,

  output logic         dc_mem_we,  
  output logic [11:0]  dc_mem_addr,
  output logic [287:0] dc_mem_din,
  
  input logic          gen_pkt_valid,
  input req_t          gen_pkt_type);


  typedef enum logic [5:0] {DC_IDLE=0, DC_XMC, DC_DONE} dc_state_t; //  xmc pattern generator FSM
  logic [3:0] step,step_next,step_cp;            // 0 ~ 7 step (for sub-FSM of main-FSM)

  

// ================================ Expected Data Generation  ===============================
/*
pkt_t intf_pkt_tmp;
integer cnt_num;


always @(posedge clk) begin
  if(cnt_num == 20) cnt_num <= 0;
  else begin 
    if(intf_pkt_valid && intf_pkt.req_type == READ) cnt_num <= cnt_num + 1;  
  end
end

  always_comb begin
    intf_pkt_tmp = intf_pkt;
    if(cnt_num == 0 && intf_pkt_valid) begin
      intf_pkt_tmp.data = $random;
    end
    
  end
  initial begin
    cnt_num = 0;
  end
*/
  dc_state_t dc_exp_dgen_state, dc_exp_dgen_state_next;
  logic [255:0] dc_base_data,dc_base_data_next;
  logic [255:0] dc_gen_exp_data_cmp,dc_gen_exp_data_cmp_next;
  logic         dc_wait_done_next;
  logic         intf_pkt_valid_d;
  pkt_t         intf_pkt_d;

  logic         dc_mem_we_next; 
  logic [11:0]  dc_mem_addr_next;
  logic [287:0] dc_mem_din_next;

  logic [31:0]  cnt_gen_pkt,cnt_gen_pkt_next;
  logic [31:0]  cnt_gen_read_pkt,cnt_gen_read_pkt_next;                

  logic [31:0]  cnt_resp_pkt,cnt_resp_pkt_next;
  logic [31:0]  cnt_resp_read_pkt,cnt_resp_read_pkt_next;

  logic [31:0]  cnt_err_pkt,cnt_err_pkt_next; 

  logic cmp_result;

  logic [15:0] time_out_cnt,time_out_cnt_next;
  logic timeout_flag;

  logic [31:0] timeout_signal, timeout_signal_next;

  //logic dc_timeout_next;
  

  localparam TIMEOUT = 32768;
  
  always @(posedge clk, posedge rst)
    if (rst) begin    
      dc_exp_dgen_state      <= DC_IDLE;
      dc_base_data           <= 0;
      dc_gen_exp_data_cmp    <= 0;
      step                   <= 0;
      step_cp                <= 0;
      dc_wait_done           <= 0;

      intf_pkt_d             <= 0;
      intf_pkt_valid_d       <= 0;
      dc_mem_we              <= 0; 
      dc_mem_addr            <= 0;
      dc_mem_din             <= 0;      

      cnt_gen_pkt            <= 0;
      cnt_gen_read_pkt       <= 0;
      cnt_resp_pkt           <= 0;
      cnt_resp_read_pkt      <= 0;
      cnt_err_pkt            <= 0;

      timeout_signal         <= 0;
      //dc_timeout             <= 0;

    end
    else begin
      // generation expected data fsm and data
      dc_exp_dgen_state      <= dc_exp_dgen_state_next;
      dc_base_data           <= dc_base_data_next;
      dc_gen_exp_data_cmp    <= dc_gen_exp_data_cmp_next;
      step                   <= step_next;
      step_cp                <= step;
      dc_wait_done           <= dc_wait_done_next;
  
      // error checker signal 
      intf_pkt_d             <= intf_pkt;
      intf_pkt_valid_d       <= intf_pkt_valid;      
      dc_mem_we              <= dc_mem_we_next;
      dc_mem_addr            <= dc_mem_addr_next;
      dc_mem_din             <= dc_mem_din_next;  

      cnt_gen_pkt            <= cnt_gen_pkt_next;
      cnt_gen_read_pkt       <= cnt_gen_read_pkt_next;
      cnt_resp_pkt           <= cnt_resp_pkt_next;
      cnt_resp_read_pkt      <= cnt_resp_read_pkt_next;
      cnt_err_pkt            <= cnt_err_pkt_next;

      timeout_signal         <= timeout_signal_next;
      //dc_timeout             <= dc_timeout_next;
    end

always_comb begin
    // FSM Signals
    dc_exp_dgen_state_next    = dc_exp_dgen_state;
    // Expected data 
    dc_base_data_next         = dc_base_data;
    dc_gen_exp_data_cmp_next  = dc_gen_exp_data_cmp;
    // sub-FSM 
    step_next                 = step;
    // Data Generation and Error check done signal 
    dc_wait_done_next         = 0;
    timeout_signal_next       = timeout_signal;
   // dc_timeout_next           = dc_timeout;

    // in_param[2][0] 
    // 0: all valid packet store 
    // 1: store only error packet (expected data != intf_pkt.data)
    // in_param[2][3]
    // 0: normal mode
    // 1: report packet info 
    cmp_result = (dc_gen_exp_data_cmp == intf_pkt_d.data) ? 1'b1 : 1'b0;

    case (march_type)
      6'd1    : begin 
        dc_mem_we_next   = (intf_pkt_valid_d && intf_pkt_d.req_type == READ) ? ((in_param[2][0] == 0) ? 1'b1 : ((cmp_result) ? 1'b0: 1'b1)): 1'b0;
        dc_mem_din_next  = {1'b1,step_cp[2:0], intf_pkt_d.bk_addr, intf_pkt_d.row_addr, 2'd0, intf_pkt_d.col_addr, 2'd0, intf_pkt_d.data};          
      end
      default : begin 
        dc_mem_we_next   = intf_pkt_valid_d & (intf_pkt_d.req_type == READ);
        dc_mem_din_next  = {4'd0, intf_pkt_d.bk_addr, intf_pkt_d.row_addr, 2'd0, intf_pkt_d.col_addr, 2'd0, intf_pkt_d.data};
      end
    endcase

    //dc_mem_we_next   = (intf_pkt_valid_d && intf_pkt_d.req_type == READ) ? ((in_param[2][0] == 0) ? 1'b1 : ((cmp_result) ? 1'b0: 1'b1)): 1'b0;
    //dc_mem_din_next  = {1'b1,step_cp[2:0], intf_pkt_d.bk_addr, intf_pkt_d.row_addr, 2'd0, intf_pkt_d.col_addr, 2'd0, intf_pkt_d.data};  

    dc_mem_addr_next = dc_mem_addr + dc_mem_we_next;
 
    cnt_gen_pkt_next       = cnt_gen_pkt;
    cnt_gen_read_pkt_next  = cnt_gen_read_pkt;
    cnt_resp_pkt_next      = cnt_resp_pkt;
    cnt_resp_read_pkt_next = cnt_resp_read_pkt;
    cnt_err_pkt_next       = cnt_err_pkt;
    // generation and resp packet counter
    if(gen_pkt_valid) begin 
      cnt_gen_pkt_next =  cnt_gen_pkt + 1;
      if(gen_pkt_type == READ) cnt_gen_read_pkt_next =  cnt_gen_read_pkt + 1;
    end
    if(intf_pkt_valid_d) begin 
      cnt_resp_pkt_next = cnt_resp_pkt + 1;
      if(intf_pkt_d.req_type == READ) begin 
        cnt_resp_read_pkt_next =  cnt_resp_read_pkt + 1;
        if (~cmp_result) cnt_err_pkt_next = cnt_err_pkt + 1;   
      end
    end
    case (dc_exp_dgen_state)
      // [IDLE State for Expected Data Generation]
      DC_IDLE : begin

        if (cal_pgen_start) begin          
          step_next = 0;
          cnt_gen_pkt_next       = 0;
          cnt_gen_read_pkt_next  = 0;
          cnt_resp_pkt_next      = 0;
          cnt_resp_read_pkt_next = 0;     
          cnt_err_pkt_next       = 0;     
          timeout_signal_next    = 0;
          //dc_timeout_next        = 0;
          if(in_param[2][1] == 0) dc_mem_addr_next = -1;
          else begin 
            dc_mem_addr_next = 0;
            dc_mem_we_next  = 1'b1;
            dc_mem_din_next = 0;  
          end

          case (march_type)
            6'd1    : dc_exp_dgen_state_next  = DC_XMC;
            default : dc_exp_dgen_state_next  = DC_IDLE;          
          endcase

          case (data_type)
            6'd0 : dc_base_data_next = {256{1'b0}};
            6'd1 : dc_base_data_next = {256{1'b1}};
            6'd2 : dc_base_data_next = {{128{1'b0}}, {128{1'b1}}};
            6'd3 : dc_base_data_next = {8{32'h0000FFFF}};
            6'd4 : dc_base_data_next = {8{32'hAAAA5555}};
            6'd5 : dc_base_data_next = {224'd0, 4'd0, in_param[4][BK_ADDR_WIDTH-1:0] , 2'd0, in_param[5][ROW_ADDR_WIDTH-1:0], 2'd0, in_param[6][COL_ADDR_WIDTH-1:0]};
          endcase
        end        
      end
  
      DC_XMC: begin 
        dc_wait_done_next = 0;
        if(step == 6) dc_exp_dgen_state_next = DC_DONE;
        case(step) 
          0,1,3 : if(intf_pkt_valid && intf_pkt.row_addr == in_param[8][ROW_ADDR_WIDTH-1:0] && intf_pkt.col_addr == in_param[9][COL_ADDR_WIDTH-1:0]) begin 
                    step_next = step + 1;
                    case(step)
                    1: if(intf_pkt.req_type != WRITE)                         step_next = 1; 
                    3: if(intf_pkt.bk_addr != in_param[7][BK_ADDR_WIDTH-1:0]) begin 
                       step_next = 0; 
                       dc_wait_done_next = 1;
                    end
                    endcase
                  end
          2: if(intf_pkt_valid && intf_pkt.row_addr == in_param[5][ROW_ADDR_WIDTH-1:0] && intf_pkt.col_addr == in_param[6][COL_ADDR_WIDTH-1:0] && intf_pkt.req_type == WRITE) step_next = 3; 
          4: step_next = 5;
          5: step_next = 6;
          6: step_next = step;
        endcase

        if(intf_pkt_valid && intf_pkt.req_type == READ) begin 
          case (data_type)
            6'd5    : dc_gen_exp_data_cmp_next = (step == 2) ? ~{8'd0, intf_pkt.bk_addr, 2'd0, intf_pkt.row_addr, 2'd0, intf_pkt.col_addr} : {8'd0, intf_pkt.bk_addr, 2'd0, intf_pkt.row_addr, 2'd0, intf_pkt.col_addr};
            default : dc_gen_exp_data_cmp_next = (step == 2) ? ~dc_base_data : dc_base_data;
          endcase     
        end
        /*
        if(timeout_flag) begin 
          dc_timeout_next = 1;
          dc_exp_dgen_state_next = DC_DONE;
          timeout_signal_next = 32'hf0f0f0f0;
        end
        */
      end

      DC_DONE : begin
          dc_exp_dgen_state_next = DC_IDLE;
          dc_wait_done_next      = 1;
          if(in_param[2][1] == 1) begin
            dc_mem_we_next   = 1;
            dc_mem_din_next  = {32'hffffffff,
                                32'h00000000,
                                32'hffffffff,
                                32'h00000000,
                                //4'hf,3'b000,in_param[2][2],4'hf,3'b000,in_param[2][1],4'hf,3'b000,in_param[2][0],12'hfff,
                                //timeout_signal,
                                cnt_err_pkt,
                                cnt_resp_read_pkt,
                                cnt_resp_pkt,
                                cnt_gen_read_pkt,
                                cnt_gen_pkt};
            dc_mem_addr_next = 0;         
          end
      end

    endcase
end

 /*
 always @(posedge clk) begin
  time_out_cnt <= time_out_cnt_next;
  timeout_flag <= (time_out_cnt > TIMEOUT) ? 1'b1 : 1'b0;
 end

 always_comb begin
   case(dc_exp_dgen_state)
   DC_XMC: begin 
     if(intf_pkt_valid || resp_rh_pkt_valid) time_out_cnt_next = 0;
     else time_out_cnt_next = time_out_cnt + 1;
   end
   default: time_out_cnt_next = 0;
   endcase
 end
 */
endmodule
