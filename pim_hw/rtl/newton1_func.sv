package newton1_func;
  parameter EXP_MAX = 255;
  parameter EXP_MIN = -25;

  typedef struct packed {               // fp16_t : Brain Float type
    logic sign;                         // sign 
    logic [7:0] exp;                    // exponent
    logic [7:0] man;                    // mantissa with hidden bit
    bit   ZERO, INF, NAN, NORM, DENORM; // flags
  } bf16_t;

  typedef struct packed {               // fp32_t : IEEE754 FP32 type
    logic sign;                         // sign 
    logic [7:0]  exp;                   // exponent
    logic [23:0] man;                   // mantissa with hidden bit
    bit   ZERO, INF, NAN, NORM, DENORM; // flags
  } fp32_t;

  typedef struct packed {               // mul_t : data type used for transferring BF16_MUL result to ADDER_TREE
    logic sign;                         // sign 
    logic signed [9:0]  exp;            // signed exponent
    logic        [15:0] man;            // mantissa with hidden bit
    bit   ZERO, PINF, NINF, NAN, NORM;  // flags
  } mul_t;

  typedef struct packed {               // latch_t : data type used for MAC latches
    logic signed [9:0]  exp;            // signed exponent (denormal BIAS mantissas are normalized by using negative exponents)
    logic signed [24:0] man;            // mantissa with hidden bit + signed
    bit ZERO, PINF, NINF, NAN, NORM;    // flags
  } latch_t;

  typedef struct packed {
    bit ZERO, PINF, NINF, NAN, NORM;
  } flags_t;

  // =================================================================================================================
  //                                               BF16 TO LATCH_T CONVERTER  
  // =================================================================================================================
  task automatic bf16_to_latch;
    input  logic [15:0] a_bf16;
    output latch_t      b_latch;

    bf16_t a;
    logic [3:0]  ms1_idx;
    logic [24:0] b_man_norm;

    begin
      a.sign   = a_bf16[15];
      a.exp    = a_bf16[14:7];
      a.man    = (a_bf16[14:7] == 0) ? {1'b0, a_bf16[6:0]} : {1'b1, a_bf16[6:0]}; // for denormal numbers, hidden bit = 0

      a.ZERO   = (a.exp == 0)       & (a.man[6:0] == 0);
      a.DENORM = (a.exp == 0)       & (a.man[6:0] != 0);
      a.NORM   = (a.exp != 0)       & (a.exp      != EXP_MAX);
      a.INF    = (a.exp == EXP_MAX) & (a.man[6:0] == 0);
      a.NAN    = (a.exp == EXP_MAX) & (a.man[6:0] != 0);

      a.exp    = (a_bf16[14:7] == 0) ? 1 : a_bf16[14:7];

      b_man_norm  = {a.man, 16'd0};           // extending mantissa to 24 bits to match the latch_t type
      b_latch.exp = {2'd0, a.exp};            // extending exponent to match 10-bit signed format

      // ------------------------- Modified by KNS -------------------------
      // Remove Normalization, because circuit doesn't have enough area to 
      // support this fucntion, and at the next stage we have same function.
      //--------------------------------------------------------------------
      // // Normalization  (pushing most significant "1" to the hidden bit position)
      // ms1_idx = 8;                            // index of the most significant "1" in mantissa
      // for (integer i=0; i<8; i++) begin
      //  if(a.man[i])
      //    ms1_idx = i;
      // end

      // if (ms1_idx < 7) begin                  // mantissa left-shift (e.g. mantissa 0.0011111 -> 1.1111100)
      //  b_man_norm  = a.man << (7 - ms1_idx);
      //  b_latch.exp = ms1_idx - 6;
      // end 

      // 2's Compliment (converting mantissa to signed format)
      b_latch.man = a.sign ? (~b_man_norm + 1'b1) : b_man_norm;

      // Output Flags
      b_latch.ZERO = a.ZERO;
      b_latch.PINF = a.INF & ~a.sign;
      b_latch.NINF = a.INF & a.sign;
      b_latch.NAN  = a.NAN;
      b_latch.NORM = a.NORM | a.DENORM;
    end
  endtask

  // =================================================================================================================
  //                                                 BF16 MULTIPLIER  
  // =================================================================================================================
  task automatic mul_bf16;
    input  logic [15:0] a_bf16, b_bf16;      // BF16 inputs
    output logic [15:0] c_bf16;              // BF16 output
    output mul_t        c_tmp;               // FP25 output (1-bit sign, 8-bit signed exp, 16-bit mantissa with hidden bits)
    // ---------- Internal Signals ----------
    bf16_t a, b, c;
    bit    in_ZERO, in_INF, in_NAN, in_NORM;
    
    logic [3:0]  ms1_idx;                    // index of the most significant "1"
    logic [31:0] c_fp32, c_bf16_tmp;         // temporary FP values before rounding to BF16 format
    logic [15:0] round_bias;
    bit          inf_tmp;                    // helper variable

    logic signed [8:0]  c_tmp_exp_norm;
    logic        [15:0] c_tmp_man_norm;
    logic        [7:0]  c_tmp_exp_denorm;
    logic        [15:0] c_tmp_man_denorm;

    bit s_bit_norm, s_bit_denorm;
    // -------- Internal Signals End --------

    begin
      a.sign = a_bf16[15];
      a.exp  = a_bf16[14:7];
      a.man  = (a_bf16[14:7] == 0) ? {1'b0, a_bf16[6:0]} : {1'b1, a_bf16[6:0]}; // for denormal numbers, hidden bit = 0

      b.sign = b_bf16[15];
      b.exp  = b_bf16[14:7];
      b.man  = (b_bf16[14:7] == 0) ? {1'b0, b_bf16[6:0]} : {1'b1, b_bf16[6:0]}; // for denrmal numbers, hidden bit = 0

      // ------------------------------------------------ INPUT FLAGS ------------------------------------------------
      a.ZERO   = (a.exp == 0)       & (a.man[6:0] == 0);
      a.DENORM = (a.exp == 0)       & (a.man[6:0] != 0);
      a.NORM   = (a.exp != 0)       & (a.exp      != EXP_MAX);
      a.INF    = (a.exp == EXP_MAX) & (a.man[6:0] == 0);
      a.NAN    = (a.exp == EXP_MAX) & (a.man[6:0] != 0);

      b.ZERO   = (b.exp == 0)       & (b.man[6:0] == 0);
      b.DENORM = (b.exp == 0)       & (b.man[6:0] != 0);
      b.NORM   = (b.exp != 0)       & (b.exp      != EXP_MAX);
      b.INF    = (b.exp == EXP_MAX) & (b.man[6:0] == 0);
      b.NAN    = (b.exp == EXP_MAX) & (b.man[6:0] != 0);

      in_ZERO  = (a.ZERO & (b.ZERO|b.NORM|b.DENORM)) | (b.ZERO & (a.ZERO|a.NORM|a.DENORM)) | (a.DENORM & b.DENORM);
      in_NORM  = (a.NORM & b.NORM) | (a.NORM & b.DENORM) | (a.DENORM & b.NORM);
      in_INF   = (a.INF & b.INF) | (b.INF & (a.NORM|a.DENORM)) | (a.INF & (b.NORM|b.DENORM));
      in_NAN   = a.NAN | b.NAN | (a.ZERO & b.INF) | (a.INF & b.ZERO);


      a.exp  = (a_bf16[14:7] == 0) ? 1 : a_bf16[14:7];
      b.exp  = (b_bf16[14:7] == 0) ? 1 : b_bf16[14:7];

      // ---------------------------------------------------- MUL ----------------------------------------------------
      c_tmp.sign = a.sign ^ b.sign;               // 1-bit sign
      c_tmp.exp  = a.exp  + b.exp - 8'd127;       // 10-bit signed exponent
      c_tmp.man  = a.man  * b.man;                // 16-bit unsigned fixed-point mantissa (11.11111111111111)

      // -------------------------------------------------- FP26 OUT --------------------------------------------------
      inf_tmp    = (in_INF | ($signed(c_tmp.exp) >= EXP_MAX) | (c_tmp.exp == 10'd254 & c_tmp.man[15])) & ~in_NAN;

      c_tmp.ZERO = in_ZERO | ($signed(c_tmp.exp) <= EXP_MIN);
      c_tmp.PINF = ~c_tmp.sign & inf_tmp;
      c_tmp.NINF = c_tmp.sign & inf_tmp;
      c_tmp.NAN  = in_NAN;
      c_tmp.NORM = ~c_tmp.NAN & ~c_tmp.PINF & ~c_tmp.NINF & ~c_tmp.ZERO;

      if (c_tmp.ZERO) begin
        c_tmp.exp = 0;
        c_tmp.man = 0;
      end
      else if (c_tmp.PINF | c_tmp.NINF) begin
        c_tmp.exp = 8'hFF;
        c_tmp.man = 0;
      end
      else if (c_tmp.NAN) begin
        c_tmp.exp = 8'hFF;
        c_tmp.man = 16'h8000;
      end

      // ----------------------------------------------- NORMALIZATION -----------------------------------------------
      ms1_idx = 0;                                // index of the most significant "1" in mantissa
      for (integer i=0; i<16; i++) begin
        if(c_tmp.man[i])
          ms1_idx = i;
      end

      // Normalization  (pushing most significant "1" to the hidden bit position)
      if (ms1_idx > 14) begin                    // mantissa right-shift (e.g. mantssa 11.00111111111111 -> 01.10011111111111)
        c_tmp_man_norm = c_tmp.man >> (ms1_idx - 14);
        c_tmp_exp_norm = c_tmp.exp + (ms1_idx - 14);
        s_bit_norm     = c_tmp.man[0];            // sticky bit
      end
      else begin                                  // mantissa left-shift (e.g. mantissa 00.00111111111111 -> 01.11111111111000)
        c_tmp_man_norm = c_tmp.man << (14 - ms1_idx);
        c_tmp_exp_norm = c_tmp.exp - (14 - ms1_idx);
        s_bit_norm     = |(c_tmp.man & ((1 << (14 - ms1_idx)) - 1));
      end 

      // Denormalization (if exponent is negative, denormalizing mantissa again to make exponent positive)
      if ($signed(c_tmp_exp_norm) < 1) begin
        c_tmp_exp_denorm = 0;
        c_tmp_man_denorm = (c_tmp_man_norm >> (1 - c_tmp_exp_norm));
        s_bit_denorm     = (|(c_tmp_man_norm & ((1 << (1 - c_tmp_exp_norm)) - 1))) | s_bit_norm;

      end
      else begin
        c_tmp_exp_denorm = c_tmp_exp_norm;
        c_tmp_man_denorm = c_tmp_man_norm;
        s_bit_denorm     = s_bit_norm;
      end

      // -------------------------------------------------- ROUNDING -------------------------------------------------
      c_fp32 = {c_tmp.sign, c_tmp_exp_denorm[7:0], c_tmp_man_denorm[13:0], 9'd0}; // constructing 32-bit floating point result

      round_bias = 16'h7FFF + c_fp32[16];
      c_bf16_tmp = c_fp32 + round_bias + s_bit_denorm;

      c.sign = c_bf16_tmp[31];
      c.exp  = c_bf16_tmp[30:23];
      c.man  = {c_tmp_man_denorm[14], c_bf16_tmp[22:16]};

      // ----------------------------------------------- OUTPUT FLAGS ------------------------------------------------
      c.ZERO = c_tmp.ZERO | ($signed(c_tmp_exp_norm) <= -9); 
      c.INF  = c_tmp.NAN ? 0 : (c_tmp.PINF | c_tmp.NINF | ($signed(c_tmp_exp_norm) >= EXP_MAX));
      c.NAN  = c_tmp.NAN;

      if (c.NAN) begin
        c.sign = 1'b0;
        c.exp  = 8'hFF;
        c.man  = 8'h40;
      end
      else if (c.ZERO) begin
        c.sign = 1'b0;
        c.exp  = 0;
        c.man  = 0;
      end
      else if (c.INF) begin
        c.exp  = 8'hFF;
        c.man  = 0;
      end

      c_bf16 = {c.sign, c.exp, c.man[6:0]};
    end
  endtask
  // =================================================================================================================
  //                                                 BF16 MAC ACCUMULATOR
  // =================================================================================================================
  task automatic mac_accum;
    // input  logic   [255:0] w, v;            // weight and vector data corresponding to a single DRAM column (256 bits -> 16 BF16 values)
    input  logic   [15:0] w [15:0];         // a single burst of bf16 values
    input  logic   [15:0] v [15:0];
    input  latch_t latch_curr;              // latch output data (to be summed with adder tree's output)
    output latch_t latch_next;              // latch input data (to be stored in the latch)

    // ---------- Internal Signals ----------
    logic [15:0] mul_o_bf16 [15:0];        // BF16 multiplier output (unused in this module)
    mul_t        mul_o [15:0];

    logic signed [8:0]  mul_exp_max;
    logic        [8:0]  dexp;              // difference between the max and each of the exponents (this variable is reused inside the for loop)
    logic        [24:0] mul_man_shifted;   // shifted mantissa for each of the multipliers (this variable is reused inside the for loop)

    logic signed [25:0] add1_i [15:0];
    logic signed [26:0] add1_o [7:0];
    logic signed [27:0] add2_o [3:0];
    logic signed [28:0] add3_o [1:0];
    logic signed [29:0] add4_o;

    flags_t add1_flags [7:0];
    flags_t add2_flags [3:0];
    flags_t add3_flags [1:0];
    flags_t add4_flags;

    logic signed [8:0]  accum_exp_max;
    logic signed [30:0] latch_man_shifted, add_o_shifted;
    logic signed [30:0] accum_man;
    bit                 accum_man_sign;

    logic        [5:0]  ms1_idx;
    logic signed [9:0]  accum_exp_norm;
    logic signed [30:0] accum_man_norm;

    flags_t latch_flags_tmp;
    // -------- Internal Signals End --------

    begin
      // ------------------------------------------------ MULTIPLIERS ------------------------------------------------
      for (integer i=0; i<16; i++) begin
        mul_bf16 (
          // .a_bf16 (w[16*(15-i) +: 16]),    // ! NOTE ! "Most significant" input part is passed to the "least significant" multiplier
          // .b_bf16 (v[16*(15-i) +: 16]),
          .a_bf16 (w[15-i]),               // ! NOTE ! "Most significant" input part is passed to the "least significant" multiplier
          .b_bf16 (v[15-i]),
          .c_bf16 (mul_o_bf16[i]),
          .c_tmp  (mul_o[i]));
      end

      // ------------------------------------------------- ADDER TREE ------------------------------------------------
      // Finding the largest exponent for equalizing all exponents to this value
      mul_exp_max = 0;                     // ! NOTE ! mul_exp_max is not allowed to fall below "0"
      for (integer i=0; i<16; i++)
        if ($signed(mul_o[i].exp) > $signed(mul_exp_max)) mul_exp_max = mul_o[i].exp;

      // Shifting mantissas to match the max exponent
      for (integer i=0; i<16; i++) begin
        dexp            = mul_exp_max - mul_o[i].exp;
        mul_man_shifted = {1'b0, mul_o[i].man, 9'd0} >> dexp;                          // adding 9 LSB for keeping accuracy
        add1_i[i]       = mul_o[i].sign ? (~mul_man_shifted + 1'b1) : mul_man_shifted; // converting to signed (2's compliment)
      end

      // Adder Stage 1
      for (integer i=0; i<8; i++) begin
        add1_o[i]          = add1_i[i*2] + add1_i[i*2+1];
        add1_flags[i].ZERO = mul_o[i*2].ZERO & mul_o[i*2+1].ZERO;
        add1_flags[i].NAN  = mul_o[i*2].NAN | mul_o[i*2+1].NAN | (mul_o[i*2].PINF & mul_o[i*2+1].NINF) | (mul_o[i*2].NINF & mul_o[i*2+1].PINF);
        add1_flags[i].PINF = ~add1_flags[i].NAN & ((mul_o[i*2].PINF & ~mul_o[i*2+1].NAN) | (~mul_o[i*2].NAN & mul_o[i*2+1].PINF));
        add1_flags[i].NINF = ~add1_flags[i].NAN & ((mul_o[i*2].NINF & ~mul_o[i*2+1].NAN) | (~mul_o[i*2].NAN & mul_o[i*2+1].NINF));
        add1_flags[i].NORM = ~(add1_flags[i].ZERO | add1_flags[i].PINF | add1_flags[i].NINF | add1_flags[i].NAN);
      end

      // Adder Stage 2
      for (integer i=0; i<4; i++) begin
        add2_o[i]          = add1_o[i*2] + add1_o[i*2+1];
        add2_flags[i].ZERO = add1_flags[i*2].ZERO & add1_flags[i*2+1].ZERO;
        add2_flags[i].NAN  = add1_flags[i*2].NAN | add1_flags[i*2+1].NAN | (add1_flags[i*2].PINF & add1_flags[i*2+1].NINF) | (add1_flags[i*2].NINF & add1_flags[i*2+1].PINF);
        add2_flags[i].PINF = ~add2_flags[i].NAN & ((add1_flags[i*2].PINF & ~add1_flags[i*2+1].NAN) | (~add1_flags[i*2].NAN & add1_flags[i*2+1].PINF));
        add2_flags[i].NINF = ~add2_flags[i].NAN & ((add1_flags[i*2].NINF & ~add1_flags[i*2+1].NAN) | (~add1_flags[i*2].NAN & add1_flags[i*2+1].NINF));
        add2_flags[i].NORM = ~(add2_flags[i].ZERO | add2_flags[i].PINF | add2_flags[i].NINF | add2_flags[i].NAN);
      end
      // Adder Stage 3
      for (integer i=0; i<2; i++) begin
        add3_o[i]          = add2_o[i*2] + add2_o[i*2+1];
        add3_flags[i].ZERO = add2_flags[i*2].ZERO & add2_flags[i*2+1].ZERO;
        add3_flags[i].NAN  = add2_flags[i*2].NAN | add2_flags[i*2+1].NAN | (add2_flags[i*2].PINF & add2_flags[i*2+1].NINF) | (add2_flags[i*2].NINF & add2_flags[i*2+1].PINF);
        add3_flags[i].PINF = ~add3_flags[i].NAN & ((add2_flags[i*2].PINF & ~add2_flags[i*2+1].NAN) | (~add2_flags[i*2].NAN & add2_flags[i*2+1].PINF));
        add3_flags[i].NINF = ~add3_flags[i].NAN & ((add2_flags[i*2].NINF & ~add2_flags[i*2+1].NAN) | (~add2_flags[i*2].NAN & add2_flags[i*2+1].NINF));
        add3_flags[i].NORM = ~(add3_flags[i].ZERO | add3_flags[i].PINF | add3_flags[i].NINF | add3_flags[i].NAN);
      end
      // Adder Stage 4
      add4_o          = add3_o[0] + add3_o[1];
      add4_flags.ZERO = add3_flags[0].ZERO & add3_flags[1].ZERO;
      add4_flags.NAN  = add3_flags[0].NAN | add3_flags[1].NAN | (add3_flags[0].PINF & add3_flags[1].NINF) | (add3_flags[0].NINF & add3_flags[1].PINF);
      add4_flags.PINF = ~add4_flags.NAN & ((add3_flags[0].PINF & ~add3_flags[1].NAN) | (~add3_flags[0].NAN & add3_flags[1].PINF));
      add4_flags.NINF = ~add4_flags.NAN & ((add3_flags[0].NINF & ~add3_flags[1].NAN) | (~add3_flags[0].NAN & add3_flags[1].NINF));
      add4_flags.NORM = ~(add4_flags.ZERO | add4_flags.PINF | add4_flags.NINF | add4_flags.NAN);

      // ------------------------------------------------ ACCUMULATION -----------------------------------------------
      // Equalizing exponents and shifting mantissas
      if ($signed(latch_curr.exp) > $signed(mul_exp_max)) begin
        accum_exp_max     = latch_curr.exp;
        dexp              = latch_curr.exp - mul_exp_max;
        latch_man_shifted = latch_curr.man;
        add_o_shifted     = ($signed(dexp) <= 29) ? (add4_o >>> dexp) : 0;
      end
      else begin
        accum_exp_max     = mul_exp_max;
        dexp              = mul_exp_max - latch_curr.exp;
        latch_man_shifted = ($signed(dexp) <= 24) ? (latch_curr.man >>> dexp) : 0;
        add_o_shifted     = add4_o;
      end

      // Accumulator's Adder
      accum_man = latch_man_shifted + add_o_shifted;      // 31-bit signed-extended sum of shifted signed mantissas

      // Normalization
      accum_man_sign = ($signed(accum_man) < 0);

      ms1_idx = 31;                                       // index of the most significant "1"
      for (integer i=0; i<30; i++) begin
        if(accum_man[i] == ~accum_man_sign) ms1_idx = i;  // in case of negative value, search for most significant "0" instead of "1"
      end

      if (ms1_idx == 31) begin
        accum_exp_norm = accum_exp_max;
        accum_man_norm = accum_man;
      end
      else if (ms1_idx >= 23) begin
        accum_exp_norm = accum_exp_max + (ms1_idx - 23);
        accum_man_norm = accum_man >>> (ms1_idx - 23);
      end
      else begin
        accum_exp_norm = accum_exp_max - (23 - ms1_idx);
        accum_man_norm = accum_man <<< (23 - ms1_idx);
      end

      // Flags
      latch_flags_tmp.NAN  = latch_curr.NAN | add4_flags.NAN | (latch_curr.PINF & add4_flags.NINF) | (latch_curr.NINF & add4_flags.PINF);
      latch_flags_tmp.PINF = ~latch_flags_tmp.NAN & ((latch_curr.PINF & ~add4_flags.NAN) | (~latch_curr.NAN & add4_flags.PINF));
      latch_flags_tmp.NINF = ~latch_flags_tmp.NAN & ((latch_curr.NINF & ~add4_flags.NAN) | (~latch_curr.NAN & add4_flags.NINF));
      latch_flags_tmp.ZERO = (latch_curr.ZERO & add4_flags.ZERO) | (latch_flags_tmp.NORM & (accum_man == 0)); 
      latch_flags_tmp.NORM = ~latch_flags_tmp.NAN & ~latch_flags_tmp.PINF & ~latch_flags_tmp.NINF & ~latch_flags_tmp.ZERO;

      latch_next.NAN  = latch_flags_tmp.NAN;
      latch_next.PINF = latch_flags_tmp.PINF | (~latch_flags_tmp.NAN & latch_flags_tmp.NORM & ($signed(accum_man_norm) > 0) & ($signed(accum_exp_norm) >= EXP_MAX));
      latch_next.NINF = latch_flags_tmp.NINF | (~latch_flags_tmp.NAN & latch_flags_tmp.NORM & ($signed(accum_man_norm) < 0) & ($signed(accum_exp_norm) >= EXP_MAX));
      latch_next.ZERO = latch_flags_tmp.ZERO;
      latch_next.NORM = ~latch_next.ZERO & ~latch_next.PINF & ~latch_next.NINF & ~latch_next.NAN;

      // Latch input
      latch_next.exp  = (latch_next.NINF | latch_next.PINF | latch_next.NAN) ? 10'd255 : (latch_next.ZERO ? 0 : accum_exp_norm);
      latch_next.man  = (latch_next.NINF | latch_next.PINF | latch_next.ZERO) ? 0 : (latch_next.NAN ? 1 : accum_man_norm[24:0]); // 25-bit signed mantissa
    end
  endtask
  // =================================================================================================================
  //                                              BF16 MAC OUTPUT ADDER
  // =================================================================================================================
  task automatic mac_final_add;
    input latch_t latch_l, latch_r;
    output logic  [31:0] mac_fp32;      
    output logic  [15:0] mac_bf16;

    // ---------- Internal Signals ----------
    logic signed [8:0]  latch_l_exp_den, latch_r_exp_den;

    logic signed [8:0]  mac_exp_max;
    logic        [8:0]  dexp_l, dexp_r;
    logic signed [25:0] latch_l_man_shifted, latch_r_man_shifted;

    logic signed [25:0] mac_man_s;
    logic        [25:0] mac_man_u;
    bit                 mac_man_sign;

    logic signed [8:0]  mac_exp_norm;
    logic        [25:0] mac_man_norm;

    logic [5:0]  ms1_read_idx;

    logic [7:0]  mac_exp_denorm;
    logic [25:0] mac_man_denorm;

    flags_t mac_flags_tmp;
    flags_t mac_flags;

    bit          mac_sign;
    logic [7:0]  mac_exp;
    logic [22:0] mac_man_fp32;
    logic [15:0] round_bias;

    logic [31:0] mac_bf16_tmp;
    // -------- Internal Signals End --------

    begin
      // Checking both latches for denormal values
      latch_l_exp_den = (($signed(latch_l.exp) <= 0) & latch_l.NORM) ? 1 : latch_l.exp;
      latch_r_exp_den = (($signed(latch_r.exp) <= 0) & latch_r.NORM) ? 1 : latch_r.exp;
      // Equalizing exponents and shifting mantissas
      mac_exp_max         = ($signed(latch_l_exp_den) > $signed(latch_r_exp_den)) ? latch_l_exp_den : latch_r_exp_den;
      dexp_l              = mac_exp_max - $signed(latch_l.exp);
      dexp_r              = mac_exp_max - $signed(latch_r.exp);
      latch_l_man_shifted = (dexp_l <= 24) ? (latch_l.man >>> dexp_l) : 0;
      latch_r_man_shifted = (dexp_r <= 24) ? (latch_r.man >>> dexp_r) : 0;

      // Final addition
      mac_man_s    = latch_l_man_shifted + latch_r_man_shifted; // 26-bit signed result
      mac_man_sign = ($signed(mac_man_s) < 0);
      mac_man_u    = mac_man_sign ? (~mac_man_s + 1'b1) : mac_man_s;

      // Normalization
      ms1_read_idx = 31;                                        // index of the most significant "1"
      for (integer i=0; i<25; i++) begin
        if(mac_man_u[i]) ms1_read_idx = i;
      end

      if (ms1_read_idx == 31) begin
        mac_exp_norm = 0;
        mac_man_norm = 0;
      end
      else if (ms1_read_idx >= 23) begin
        mac_exp_norm = mac_exp_max + (ms1_read_idx - 23);
        mac_man_norm = mac_man_u >>> (ms1_read_idx - 23);
      end
      else begin
        mac_exp_norm = mac_exp_max - (23 - ms1_read_idx);
        mac_man_norm = mac_man_u <<< (23 - ms1_read_idx);
      end

      // Denormalization (if final exponent is negative)
      if ($signed(mac_exp_norm) <= 0) begin
        mac_exp_denorm = 0;
        mac_man_denorm = mac_man_norm >>> (1 - mac_exp_norm);
      end
      else begin
        mac_exp_denorm = mac_exp_norm[7:0];
        mac_man_denorm = mac_man_norm;
      end

      // Flags
      mac_flags_tmp.NAN  = latch_l.NAN | latch_r.NAN | (latch_l.PINF & latch_r.NINF) | (latch_l.NINF & latch_r.PINF);
      mac_flags_tmp.PINF = ~mac_flags_tmp.NAN & ((latch_l.PINF & ~latch_r.NAN) | (~latch_l.NAN & latch_r.PINF));
      mac_flags_tmp.NINF = ~mac_flags_tmp.NAN & ((latch_l.NINF & ~latch_r.NAN) | (~latch_l.NAN & latch_r.NINF));
      mac_flags_tmp.NORM = ~((latch_l.ZERO & latch_r.ZERO) | mac_flags_tmp.PINF | mac_flags_tmp.NINF | mac_flags_tmp.NAN);
      mac_flags_tmp.ZERO = (latch_l.ZERO & latch_r.ZERO) | (mac_flags_tmp.NORM & (mac_man_s == 0));

      mac_flags.NAN  = mac_flags_tmp.NAN;
      mac_flags.PINF = mac_flags_tmp.PINF | (~mac_flags_tmp.NAN & mac_flags_tmp.NORM & ~mac_man_sign & (mac_exp_denorm >= EXP_MAX));
      mac_flags.NINF = mac_flags_tmp.NINF | (~mac_flags_tmp.NAN & mac_flags_tmp.NORM & mac_man_sign &  (mac_exp_denorm >= EXP_MAX));
      mac_flags.ZERO = mac_flags_tmp.ZERO | (mac_flags_tmp.NORM & ($signed(mac_exp_norm) <= -8));
      mac_flags.NORM = mac_flags_tmp.NORM & ~mac_flags.PINF & ~mac_flags.NINF & ~mac_flags.ZERO;

      // Rounding to BF16 output
      mac_sign     =  ~mac_flags.NAN & (mac_man_sign | mac_flags.NINF) & ~mac_flags.PINF & ~mac_flags.ZERO;
      mac_exp      = (mac_flags.NINF | mac_flags.PINF | mac_flags.NAN) ? 8'd255 : (mac_flags.ZERO ? 0 : mac_exp_denorm);
      mac_man_fp32 = (mac_flags.NINF | mac_flags.PINF | mac_flags.ZERO) ? 0 : (mac_flags.NAN ? 1 : mac_man_denorm[22:0]); // 23-bit unsigned mantissa without hidden bit

      round_bias   = 16'h7FFF + mac_man_fp32[16];

      mac_fp32     = {mac_sign, mac_exp, mac_man_fp32};        // rounding bias removed from the final FP32 result as instructed by Mungyu Son (2020.12.15)
      mac_bf16_tmp = {mac_sign, mac_exp, mac_man_fp32} + round_bias;        

      if (mac_flags.NAN) begin
        mac_fp32    [22:0] = 23'b100_0000_0000_0000_0000_0000; // complying with the circuit design
        mac_bf16_tmp[22:0] = 23'b100_0000_0000_0000_0000_0000;
      end

      mac_bf16 = mac_bf16_tmp[31:16];
    end
  endtask

  // =================================================================================================================
  //                                             FP32 TO FIX24 CONVERTER
  // =================================================================================================================
  task automatic fp32_to_fix24;
    input  logic [31:0] x_fp32;
    output logic [23:0] y_fix24;

    // ---------- Internal Signals ----------
    logic        fp32_sign;
    logic [7:0]  fp32_exp;
    logic [23:0] fp32_man;

    fp32_t x;

    bit          shift_dir;
    logic [7:0]  shift_val;
    logic [31:0] x_man_shifted;

    bit F_bit, R_bit, S_bit;
    bit round;

    flags_t y_flags;
    // -------- Internal Signals End --------

    begin
      x.sign = x_fp32[31];
      x.exp  = (x_fp32[30:23] == 0) ? 8'h01 : x_fp32[30:23];
      x.man  = (x_fp32[30:23] == 0) ? {1'b0, x_fp32[22:0]} : {1'b1, x_fp32[22:0]}; // for denormal numbers, hidden bit = 0

      // ---------------------------------------------- MANTISSA SHIFT -----------------------------------------------
      shift_dir = x.exp < 8'd127;                  // 0 - left-shift, 1 - right-shift

      if (shift_dir) begin
        shift_val     = 8'd127 - x.exp;
        x_man_shifted = (x.man >> shift_val) >> 6; // only right-shifting for 6 bits (not 7), since we still need the LSB for F_bit
      end
      else begin
        shift_val     = x.exp - 8'd127;
        x_man_shifted = (x.man << shift_val) >> 6;
      end

      // ------------------------------------------------- ROUNDING --------------------------------------------------
      F_bit = x_man_shifted[1];
      R_bit = x_man_shifted[0];
      S_bit = shift_dir ? |(((x.man << 1) >> shift_val) & 7'd127) : |(x.man & ((1 << (6 - shift_val)) - 1));

      round = (R_bit & (S_bit | F_bit)) ^ x.sign;

      y_fix24 = (x.sign ? ~(x_man_shifted >> 1) : (x_man_shifted >> 1)) + round; // right-shifting mantissa for one final bit (to make 7 bits total)

      // -------------------------------------------------- OUTPUT ---------------------------------------------------
      y_flags.PINF  = (shift_dir ? 0 : (shift_val > 6)) & ~x.sign;
      y_flags.NINF  = (shift_dir ? 0 : (shift_val > 6)) & x.sign;
      y_flags.ZERO = shift_dir ? (shift_val > 16) : 0;
      y_flags.NORM = ~(y_flags.PINF | y_flags.NINF | y_flags.ZERO);

      if (y_flags.PINF)
        y_fix24 = 24'h7FFFFF;
      else if (y_flags.NINF)
        y_fix24 = 24'h800001;
      else if (y_flags.ZERO)
        y_fix24 = 0;
    end
  endtask

  // =================================================================================================================
  //                                                  LEAKY RELU
  // =================================================================================================================
  task automatic leaky_relu;
    input  logic [15:0] x_bf16;        // MAC output in BF16 format
    input  logic [23:0]  x_fix24;      // MAC output in FIX24 format
    input  logic [2:0]  relu_max_mr;   // Positive ReLU saturation value (set in MR13)
    input  logic [15:0] leak_slope_mr; // Negative ReLU slope in BF16 format (set using MR15)
    input  logic [2:0]  AFM;           // Activation Function Mode (MR13)
    output logic [15:0] y_bf16;        // ReLU value

    // ---------- Internal Signals ----------
    mul_t c_tmp;                       // mul_bf16 task has a c_tmp outut (used for mac) that is unused in this task, but has to be assigned a variable
    logic [15:0] y_bf16_tmp;           // temp values outputted from the multiplier; required for overwriting it's sign with "0", in case of "negative zero" output
    logic [7:0]  x_fix24_int;          // integer part of the passed 24-bit fixed-poiint value
    // -------- Internal Signals End --------

    begin
      x_fix24_int = x_fix24[23:16];

      // -------------------------------------------------- X < 0 ----------------------------------------------------
      if (x_bf16[15] == 1) begin
        if (AFM == 3'b011) begin       // Leaky ReLU
          mul_bf16(
            .a_bf16(x_bf16),
            .b_bf16(leak_slope_mr),
            .c_bf16(y_bf16_tmp),
            .c_tmp(c_tmp));

          y_bf16     = y_bf16_tmp;
          y_bf16[15] = c_tmp.ZERO ? 1'b0 : y_bf16_tmp[15];
        end
        else if (AFM == 3'b010) begin  // ReLU
          y_bf16 = 0;
        end
        else begin                     // ERROR
          $display("ERROR: Unexpected AFM value while executing ReLU.");
          $finish;
        end
      end

      // -------------------------------------------------- X >= 0 ---------------------------------------------------
      else begin
        y_bf16[15] = 0;
        // ReLU reaches saturation (! NOTE ! SATURATION IS NOT USED FOR LEAKY RELU)
        if ((relu_max_mr != 0) && (AFM == 3'b010) && ($signed(x_fix24_int) >= $unsigned(relu_max_mr))) begin
          case (relu_max_mr)
            3'd1 : begin
              y_bf16[14:7] = 8'd127;
              y_bf16[6:0]  = 7'd0;
            end
            3'd2 : begin
              y_bf16[14:7] = 8'd128;
              y_bf16[6:0]  = 7'd0;
            end
            3'd3 : begin
              y_bf16[14:7] = 8'd128;
              y_bf16[6:0]  = 7'd64;
            end
            3'd4 : begin
              y_bf16[14:7] = 8'd129;
              y_bf16[6:0]  = 7'd0;
            end
            3'd5 : begin
              y_bf16[14:7] = 8'd129;
              y_bf16[6:0]  = 7'd32;
            end
            3'd6 : begin
              y_bf16[14:7] = 8'd129;
              y_bf16[6:0]  = 7'd64;
            end
            3'd7 : begin
              y_bf16[14:7] = 8'd129;
              y_bf16[6:0]  = 7'd96;
            end
            default : begin
              $display("Invalid relu_max_mr");
              $finish;
            end
          endcase
        end
        // ReLU doesn't reach saturation
        else begin
          y_bf16[14:7] = x_bf16[14:7];
          y_bf16[6:0]  = x_bf16[6:0];
        end
      end
    end
  endtask

  // =================================================================================================================
  //                                                  INTERPOLATION
  // =================================================================================================================
  task automatic lut_interpol;
    input  logic [23:0] x_fix24;         // x value (24-bit signed fixed-point)
    input  logic [15:0] x_bf16;          // x value (BF16)
    input  logic [15:0] y_bf16;          // y = f(a) (BF16)
    input  logic [15:0] dy_bf16;         // dy = y(a+da) - y(a) (BF16)
    input  logic [2:0]  AFM;             // Activation Function Mode (MR13)
    output logic [15:0] z_bf16;          // Interpolated output (BF16)

    // ---------- Internal Signals ----------
    bf16_t y, dy, z;
    logic        [10:0] dx;

    logic        [18:0] man_mul;

    logic signed [8:0]  dexp;
    logic        [23:0] y_man_shifted;
    logic        [23:0] man_mul_shifted;
    logic        [7:0]  exp_norm;        // normalized exponent (after mantissa shift)

    logic signed [25:0] man_mul_signed;  // signed 2's comp (24-bit values + 2-bit sign extension)
    logic signed [25:0] y_man_signed;    // signed 2's comp (24-bit values + 2-bit sign extension)
    logic signed [25:0] man_sum_signed;  // 26-bit sum of two sign-extended values
    logic               man_sum_sign;    // addition result sign
    logic        [25:0] man_sum;         // unsigned addition result (reversed from 2's comp. format)
    logic        [4:0]  ms1_idx;         // index of the most significant "1" in man_add    
    logic        [25:0] man_sum_norm;    // normalized man_add (most significant "1" shifted to bit [23])

    bit F_bit, R_bit, S_bit;
    bit round;
    bit z_ovf;
    // -------- Internal Signals End --------

    begin
      dx = x_fix24[10:0];                                           // 0 0000000.0000011111111111 - mask for constructing dx from x_fix24

      y.sign  = y_bf16[15];
      y.exp   = y_bf16[14:7];
      y.man   = {(AFM == 3'd0)|(x_fix24[23:11] != 0), y_bf16[6:0]}; // hidden bit is zero only when AF is not sigmoid and a == 0

      dy.sign = dy_bf16[15];
      dy.exp  = dy_bf16[14:7];
      dy.man  = {1'b1, dy_bf16[6:0]};                               // denormal values are not used for dy, so hidden bit is always "1"

      // ------------------------------------------------ MULTIPLIER -------------------------------------------------
      /*
      man_mul = (x-a)/da * (y(a+da) - y(a))    - intended operation

      dx = 0.00000XXXXXXXXXXXb                 - taken from fixed-point input
      da = 0.000001b                           - defined by the system design

      dx -> dx/da = 0.XXXXXXXXXXXb (not creating a new variable here for convenience)

      Since integer bit for dx is always 0, we simply don't add it and use dx in man_mul with no changes. 
      */
      man_mul = dx * dy.man;
      
      // ---------------------------------------------- MANTISSA SHIFT -----------------------------------------------
      dexp = y.exp - dy.exp;

      if ($signed(dexp) >= 0) begin
        man_mul_shifted = {man_mul[18:0], 5'd0} >> dexp; // adding 5 LSB to produce a 24-bit signal
        y_man_shifted   = {y.man, 16'd0};                 // adding 16 LSB to produce a 24-bit signal
      end
      else begin
        man_mul_shifted = {man_mul[18:0], 5'd0};
        y_man_shifted   = {y.man, 16'd0} >> (-dexp);
      end

      // --------------------------------------------------- ADDER ---------------------------------------------------
      man_mul_signed = {dy.sign ? (~man_mul_shifted + 1'b1) : man_mul_shifted}; // 2's compl. and sign ext.
      y_man_signed   = {y.sign  ? (~y_man_shifted   + 1'b1) : y_man_shifted};   // 2's compl. and sign ext.

      if (man_mul_signed[23:0] == 0)
        dy.sign = 0;

      man_mul_signed[25:24] = {dy.sign, dy.sign};
      y_man_signed  [25:24] = {y.sign, y.sign};

      man_sum_signed = y_man_signed + man_mul_signed;

      // Restoring {sign, unsigned_val} format from 2's comp. format
      man_sum_sign   = $signed(man_sum_signed) < 0;
      man_sum        = man_sum_sign ? (~man_sum_signed + 1'b1) : man_sum_signed;

      // ----------------------------------------------- NORMALIZATION -----------------------------------------------
      ms1_idx = 0;                       // index of the most significant "1"
      for (integer i=0; i<26; i++) begin
        if(man_sum[i]) ms1_idx = i;
      end

      if (ms1_idx >= 23) begin
        man_sum_norm = man_sum >> (ms1_idx - 23);
        exp_norm     = (($signed(dexp) >= 0) ? y.exp : dy.exp) + (ms1_idx - 23);
      end
      else begin
        man_sum_norm = man_sum << (23 - ms1_idx);
        exp_norm     = (($signed(dexp) >= 0) ? y.exp : dy.exp) - (23 - ms1_idx);
      end

      if (man_sum == 0) begin
        exp_norm     = 0;
        man_sum_norm = 0;
      end

      // ------------------------------------------------- ROUNDING --------------------------------------------------
      // If NaN
      if (x_bf16[14:7] == EXP_MAX && x_bf16[6:0] != 0) begin
        z.sign = 1'h0;
        z.exp  = 8'hFF;
        z.man  = 7'h40;
      end

      // If not NaN
      else begin
        F_bit = man_sum_norm[16];
        R_bit = man_sum_norm[15];
        S_bit = |(man_sum_norm[14:0]);

        round = R_bit & (S_bit | F_bit);

        z_ovf = &(man_sum_norm[23:16]) & round; // overflow: mantissa 1.1111111 + round 0.0000001 -> 10.0000000

        z.sign = man_sum_sign;
        z.man  = z_ovf ? ((man_sum_norm[23:16] + round) >> 1) : (man_sum_norm[23:16] + round);

        /*                                  ! NOTE ! 
        Normally, exponent overflow check would have to be performed after "exp_norm + z_ovf".
        However, under normal operation, such overflow never occurs, therefore this is ommited 
        for the time being. */
        z.exp  = exp_norm + z_ovf;

        if ($signed(x_fix24) < -524288) begin  // negative saturation (x < -8.00...)
          if (AFM == 3'd1) begin               // tanh
            z.sign = 1;
            z.exp  = 8'h7F;
            z.man  = 0;
          end
          else begin                           // sigmoid, gelu
            z.sign = 0;
            z.exp  = 0;
            z.man  = 0;
          end
        end

        else if ($signed(x_fix24) >= 524288) begin // positive saturation (x >= 8.00...)
          if (AFM == 3'd4) begin               // gelu
            z.sign = x_bf16[15];
            z.exp  = x_bf16[14:7];
            z.man  = x_bf16[6:0];
          end
          else begin                           // sigmoid, tanh
            z.sign = 0;
            z.exp  = 8'h7F;
            z.man  = 0;
          end
        end
      end

      z_bf16 = {z.sign, z.exp, z.man[6:0]};
    end
  endtask

endpackage

