localparam IMM_S = 14 - 1;
localparam IMM_E = 0;

localparam SRC_REG_ID_S = IMM_S + 6;
localparam SRC_REG_ID_E = IMM_S + 1;

localparam DST_REG_ID_S = SRC_REG_ID_S + 6;
localparam DST_REG_ID_E = SRC_REG_ID_S + 1;

localparam OPCODE_S = DST_REG_ID_S + 6;
localparam OPCODE_E = DST_REG_ID_S + 1;

localparam NOP      = 6'b00_0000; // 0 
localparam CLR_ACC  = 6'b00_0001; // 1 
localparam CLR_ALL  = 6'b00_1111; // 15 0xf 
localparam MOV      = 6'b01_0000; // 16 0x10 
localparam LD       = 6'b01_0010; // 18 0x12
localparam ST       = 6'b01_0011; // 19 0x13 
localparam GET      = 6'b01_0100; // 20 0x14 
localparam PUT      = 6'b01_0101; // 21 0x15
localparam SHL      = 6'b01_1000; // 24 0x18
localparam DUP      = 6'b01_1001; // 25 0x19 
localparam SHUF     = 6'b01_1100; // 28 0x1C 
localparam ADD      = 6'b10_0000; // 32 0x20
localparam SUB      = 6'b10_0001; // 33 0x21
localparam MUL      = 6'b10_0110; // 38 0x26 
localparam MAC      = 6'b10_0100; // 36 0x24 
localparam NORM     = 6'b10_0101; // 37 0x25 
localparam BNE_A    = 6'b10_1000; // 40 0x28 
localparam BNE_B    = 6'b10_1001; // 41 0x29
localparam JNZ      = 6'b10_1010; // 42 0x2A

//MAC_CLR
//localparam MAC_CLR  = 6'b11_1111; //63 0x3f

localparam VECA0    = 6'b0000_00; // 0 
localparam VECA1    = 6'b0000_01; // 1
localparam VECA2    = 6'b0000_10; // 2
localparam VECA3    = 6'b0000_11; // 3
localparam VECB0    = 6'b0001_00; // 4
localparam VECB1    = 6'b0001_01; // 5
localparam VECB2    = 6'b0001_10; // 6
localparam VECB3    = 6'b0001_11; // 7
localparam ACCO0    = 6'b0010_00; // 8
localparam ACCO1    = 6'b0010_01; // 9 
localparam ACCO2    = 6'b0010_10; // 10
localparam ACCO3    = 6'b0010_11; // 11
localparam COMM0    = 6'b0011_00; // 12
localparam COMM1    = 6'b0011_01; // 13
localparam ACCI0    = 6'b0100_00; // 14
localparam ACCI1    = 6'b0100_01; // 15
localparam ACCI2    = 6'b0100_10; // 16


localparam BLANK    = 6'b0000_00; // 0 