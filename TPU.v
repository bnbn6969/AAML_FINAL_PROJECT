
module TPU(
    clk,
    rst_n,

    in_valid,
    K,
    M,
    N,
    input_offset,
    busy,

    A_wr_en,
    A_index,
    A_data_in,
    A_data_out,

    B_wr_en,
    B_index,
    B_data_in,
    B_data_out,

    C_wr_en,
    C_index,
    C_data_in,
    C_data_out
);


input clk;
input rst_n;
input            in_valid;
input [10:0]      K;//
input [10:0]      M;//
input [10:0]      N;//
input [31:0]      input_offset;
output  reg      busy;

output    reg       A_wr_en;
output reg [14:0]    A_index;//
output reg [31:0]    A_data_in;
input  [31:0]    A_data_out;

output    reg       B_wr_en;
output reg [14:0]    B_index;//
output reg [31:0]    B_data_in;
input  [31:0]    B_data_out;

output     reg      C_wr_en;
output reg [14:0]    C_index;//
output reg [127:0]   C_data_in;
input  [127:0]   C_data_out;



//* Implement your design here
parameter IDLE = 0;
parameter WORK = 1;

reg [2:0] cs, ns;
reg [10:0] K_reg, M_reg, N_reg;//
reg [7:0] A_0_0, A_0_1, A_0_2, A_0_3;
reg [7:0] A_1_0, A_1_1, A_1_2, A_1_3;
reg [7:0] A_2_0, A_2_1, A_2_2, A_2_3;
reg [7:0] A_3_0, A_3_1, A_3_2, A_3_3;
reg [7:0] B_0_0, B_0_1, B_0_2, B_0_3;
reg [7:0] B_1_0, B_1_1, B_1_2, B_1_3;
reg [7:0] B_2_0, B_2_1, B_2_2, B_2_3;
reg [7:0] B_3_0, B_3_1, B_3_2, B_3_3;
wire [31:0] C_0_0, C_0_1, C_0_2, C_0_3;
wire [31:0] C_1_0, C_1_1, C_1_2, C_1_3;
wire [31:0] C_2_0, C_2_1, C_2_2, C_2_3;
wire [31:0] C_3_0, C_3_1, C_3_2, C_3_3;

wire [8:0] A_col_in_4 = K_reg[10:2];//
wire [1:0] A_col_residual = K_reg[1:0];
wire [8:0] A_row_in_4 = M_reg[10:2];//
wire [1:0] A_row_residual = M_reg[1:0];
wire A_have_row_residual = ( A_row_residual != 0 );
wire [21:0] A_max = K_reg * (A_row_in_4 + A_have_row_residual);//

wire [8:0] B_row_in_4 = K_reg[10:2];//
wire [1:0] B_row_residual = K_reg[1:0];
wire [8:0] B_col_in_4 = N_reg[10:2];//
wire [1:0] B_col_residual = N_reg[1:0];
wire B_have_col_residual = ( B_col_residual != 0 );
wire [21:0] B_max = K_reg *( B_col_in_4 + B_have_col_residual );//

wire [8:0] C_row_in_4 = M_reg[10:2];//
wire [1:0] C_row_residual = M_reg[1:0];
wire [8:0] C_col_in_4 = N_reg[10:2];//
wire [1:0] C_col_residual = N_reg[1:0];
wire C_have_col_residual = (C_col_residual != 0);
wire [21:0] C_max = M_reg * (C_col_in_4 + C_have_col_residual);//

reg [23:0] A_col_0, A_col_1, A_col_2, A_col_3;
reg [23:0] B_row_0, B_row_1, B_row_2, B_row_3;

reg PE_re_0_0, PE_re_0_1, PE_re_0_2, PE_re_0_3;
reg PE_re_1_0, PE_re_1_1, PE_re_1_2, PE_re_1_3;
reg PE_re_2_0, PE_re_2_1, PE_re_2_2, PE_re_2_3;
reg PE_re_3_0, PE_re_3_1, PE_re_3_2, PE_re_3_3;

reg [10:0] count_C, count_C_delay;//
reg [10:0] count_AB;//

reg [2:0] count, count_to_stop_C;
reg [10:0] add_1_every_K_reg_A;//
reg [10:0] add_1_every_K_reg_B;//

reg [21:0] count_for_busy;//

reg jump_line;

//FSM
always@( posedge clk or negedge rst_n ) begin
    if(!rst_n ) begin
        cs <= IDLE;
    end else begin
        cs <= ns;
    end
end

always@(*) begin
    case(cs)
        IDLE: begin
            ns = (in_valid)? WORK : IDLE;
        end
        WORK: begin
            ns = (C_index == C_max)? IDLE : WORK;
        end
        default: begin
            ns = IDLE;
        end
    endcase
end

always@(posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        PE_re_0_0 <= 0; PE_re_0_1 <= 0; PE_re_0_2 <= 0; PE_re_0_3 <= 0;
        PE_re_1_0 <= 0; PE_re_1_1 <= 0; PE_re_1_2 <= 0; PE_re_1_3 <= 0;
        PE_re_2_0 <= 0; PE_re_2_1 <= 0; PE_re_2_2 <= 0; PE_re_2_3 <= 0;
        PE_re_3_0 <= 0; PE_re_3_1 <= 0; PE_re_3_2 <= 0; PE_re_3_3 <= 0;
    end else begin
        if( cs == IDLE && ns == WORK ) begin
            PE_re_0_0 <= 1; PE_re_0_1 <= 1; PE_re_0_2 <= 1; PE_re_0_3 <= 1;
            PE_re_1_0 <= 1; PE_re_1_1 <= 1; PE_re_1_2 <= 1; PE_re_1_3 <= 1;
            PE_re_2_0 <= 1; PE_re_2_1 <= 1; PE_re_2_2 <= 1; PE_re_2_3 <= 1;
            PE_re_3_0 <= 1; PE_re_3_1 <= 1; PE_re_3_2 <= 1; PE_re_3_3 <= 1;
        end else if( cs == WORK ) begin
            if( count == 4 ) begin
                PE_re_0_0 <= 1; PE_re_1_0 <= 1; PE_re_2_0 <= 1; PE_re_3_0 <= 1;
            end else begin
                PE_re_0_0 <= 0; PE_re_1_0 <= 0; PE_re_2_0 <= 0; PE_re_3_0 <= 0;
            end
            PE_re_0_1 <= PE_re_0_0; PE_re_0_2 <= PE_re_0_1; PE_re_0_3 <= PE_re_0_2;
            PE_re_1_1 <= PE_re_1_0; PE_re_1_2 <= PE_re_1_1; PE_re_1_3 <= PE_re_1_2;
            PE_re_2_1 <= PE_re_2_0; PE_re_2_2 <= PE_re_2_1; PE_re_2_3 <= PE_re_2_2;
            PE_re_3_1 <= PE_re_3_0; PE_re_3_2 <= PE_re_3_1; PE_re_3_3 <= PE_re_3_2;
        end else begin
            PE_re_0_0 <= 0; PE_re_0_1 <= 0; PE_re_0_2 <= 0; PE_re_0_3 <= 0;
            PE_re_1_0 <= 0; PE_re_1_1 <= 0; PE_re_1_2 <= 0; PE_re_1_3 <= 0;
            PE_re_2_0 <= 0; PE_re_2_1 <= 0; PE_re_2_2 <= 0; PE_re_2_3 <= 0;
            PE_re_3_0 <= 0; PE_re_3_1 <= 0; PE_re_3_2 <= 0; PE_re_3_3 <= 0;
        end
    end
end

//counter for every K_reg A
always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        add_1_every_K_reg_A <= 0;
    end else if( cs == WORK ) begin
        if( A_index == (A_max - 1) ) begin
            add_1_every_K_reg_A <= 0;
        end else if( A_index == ( (1 + add_1_every_K_reg_A )*K_reg - 1 ) ) begin
            add_1_every_K_reg_A <= add_1_every_K_reg_A + 1;
        end else begin
            add_1_every_K_reg_A <= add_1_every_K_reg_A;
        end
    end else begin
        add_1_every_K_reg_A <= 0;
    end
end

//counter for every K_reg B
always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        add_1_every_K_reg_B <= 0;
    end else if( cs == WORK ) begin
        if(  A_index == (A_max - 1) ) begin
            add_1_every_K_reg_B <= add_1_every_K_reg_B + 1;
        end else begin
            add_1_every_K_reg_B <= add_1_every_K_reg_B;
        end
    end else begin
        add_1_every_K_reg_B <= 0;
    end
end

//count
always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        count <= 0;
    end else if( cs == WORK  ) begin
        if( A_index == ( (1 + add_1_every_K_reg_A )*K_reg - 1 ) ) begin
            count <= count + 1;
        end else begin
            if( count == 4 ) begin
                count <= 0;
            end else if( count != 0 ) begin
                count <= count + 1;
            end else begin
                count <= 0;
            end
        end
    end else begin
        count <= 0;
    end
end

//count for stop C
always@(posedge clk or negedge rst_n ) begin
    if(!rst_n ) begin
        count_to_stop_C <= 0;
    end else if( cs == WORK ) begin
        if( count_C_delay == ( K_reg + 3 ) ) begin
            count_to_stop_C <= count_to_stop_C + 1;
        end else begin
            if( count_to_stop_C == 4 ) begin
                count_to_stop_C <= 0;
            end else if( count_to_stop_C != 0 ) begin
                count_to_stop_C <= count_to_stop_C + 1;
            end else begin
                count_to_stop_C <= 0;
            end
        end
    end else begin
        count_to_stop_C <= 0;
    end
end

//count_C
always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        count_C <= 0;
    end else if( cs == WORK ) begin
        if( count_C < ( K_reg + 4 ) ) begin
            count_C <= count_C + 1;
        end else if( count_to_stop_C == 4 ) begin
            count_C <= 5;
        end
    end else begin
        count_C <= 0;
    end
end

/*always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        jump_line <= 0;
    end else begin
        if( jump_line == 0 && count_to_stop_C == 1 )
    end
end*/

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        count_AB <= 0;
    end else if( cs == WORK ) begin
        if( count_AB < ( K_reg + 3 ) ) begin
            count_AB <= count_AB + 1;
        end else if( ( (1 + add_1_every_K_reg_A )*K_reg - 1 ) < A_max ) begin
            count_AB <= 0;
        end
    end else begin
        count_AB <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        count_C_delay <= 0;
    end else begin
        count_C_delay <= count_C;
    end
end

//matrix size
always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        K_reg <= 0;
        M_reg <= 0;
        N_reg <= 0;
    end else if(in_valid) begin
        K_reg <= K;
        M_reg <= M;
        N_reg <= N;
    end
end

//for busy
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        busy <= 0;
    end else if( in_valid ) begin
        busy <= 1;
    end else if( busy == 1 && C_max == C_index ) begin
        busy <= 0;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        count_for_busy <= 0;
    end else begin
        count_for_busy <= count_for_busy + 1;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        A_wr_en <= 0;
        B_wr_en <= 0;
    end else begin

    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        C_wr_en <= 0;
    end else if( count_C == ( K_reg + 4 ) ) begin
        C_wr_en <= 1;
    end else begin
        C_wr_en <= 0;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        A_index <= 0;
    end else begin
        if( cs == IDLE ) begin
            A_index <= 0;
        end else if( A_index < A_max && count == 0 ) begin
            A_index <= A_index + 1;
        end else if( A_index == A_max && count == 4 ) begin
            A_index <= 0;
        end
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        B_index <= 0;
    end else begin
        if( cs == IDLE ) begin
            B_index <= 0;
        end else if( B_index < B_max && count == 0 ) begin
            B_index <= B_index + 1;
        end else begin
            B_index <= add_1_every_K_reg_B * K_reg;
        end
    end
end

always@(posedge clk or negedge rst_n ) begin
    if(!rst_n ) begin
        C_index <= 0;
    end else if( cs == WORK ) begin
        if( C_index < C_max ) begin
            if( K_reg == 4 && add_1_every_K_reg_A == 1 && add_1_every_K_reg_B != 0 && A_have_row_residual && count_to_stop_C == 4 ) begin
                C_index <= C_index - 3 + A_row_residual;
            end else if( K_reg != 4 && add_1_every_K_reg_A == 0 && add_1_every_K_reg_B != 0 && A_have_row_residual && count_to_stop_C == 4) begin
                C_index <= C_index - 3 + A_row_residual;
            end else if( count_to_stop_C != 0 ) begin
                C_index <= C_index + 1;
            end
        end else begin
            C_index <= C_index;
        end
    end else begin
        C_index <= 0;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        A_data_in <= 0;
        B_data_in <= 0;
    end else begin

    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        C_data_in <= 0;
    end else if( count_C == (K_reg + 4) ) begin
        case(count_to_stop_C[1:0]) 
            0: begin
                C_data_in <= {C_0_0, C_1_0, C_2_0, C_3_0};
            end
            1: begin
                C_data_in <= {C_0_1, C_1_1, C_2_1, C_3_1};
            end
            2: begin
                C_data_in <= {C_0_2, C_1_2, C_2_2, C_3_2};
            end
            3: begin
                C_data_in <= {C_0_3, C_1_3, C_2_3, C_3_3};
            end
            default: begin
                C_data_in <= 0;
            end
        endcase
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        A_0_0 <= 0;
        A_col_0 <= 0;
    end else if( cs == WORK && ( count_AB < K_reg ) ) begin
        A_0_0 <= A_data_out[31:24];
    end else begin
        A_0_0 <= 0;
        A_col_0 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
       A_0_1 <= 0;
       A_col_1 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 1) ) ) begin
        A_0_1 <= A_col_1[23:16];
        A_col_1[23:16] <= A_data_out[23:16];
    end else begin
        A_0_1 <= 0;
        A_col_1 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
       A_0_2 <= 0;
       A_col_2 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 2) ) ) begin
        A_0_2 <= A_col_2[23:16];
        A_col_2[23:8] <= {A_col_2[15:8], A_data_out[15:8]};
    end else begin
        A_0_2 <= 0;
        A_col_2 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
       A_0_3 <= 0;
       A_col_3 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 3) ) ) begin
        A_0_3 <= A_col_3[23:16];
        A_col_3 <= {A_col_3[15:0], A_data_out[7:0]};
    end else begin
        A_0_3 <= 0;
        A_col_3 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        B_0_0 <= 0;
        B_row_0 <= 0;
    end else if( cs == WORK && ( count_AB < K_reg ) ) begin
        B_0_0 <= B_data_out[31:24];
    end else begin
    	B_0_0 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        B_1_0 <= 0;
        B_row_1 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 1) ) ) begin
        B_1_0 <= B_row_1[23:16];
        B_row_1[23:16] <= B_data_out[23:16];
    end else begin
    	B_1_0 <= 0;
        B_row_1 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        B_2_0 <= 0;
        B_row_2 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 2) ) ) begin
        B_2_0 <= B_row_2[23:16];
        B_row_2[23:8] <= {B_row_2[15:8], B_data_out[15:8]};
    end else begin
    	B_2_0 <= 0;
        B_row_2 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        B_3_0 <= 0;
        B_row_3 <= 0;
    end else if( cs == WORK && ( count_AB < (K_reg + 3) ) ) begin
        B_3_0 <= B_row_3[23:16];
        B_row_3 <= {B_row_3[15:0], B_data_out[7:0]};
    end else begin
    	B_3_0 <= 0;
        B_row_3 <= 0;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        A_1_0 <= 0; A_1_1 <= 0; A_1_2 <= 0; A_1_3 <= 0;
        A_2_0 <= 0; A_2_1 <= 0; A_2_2 <= 0; A_2_3 <= 0;
        A_3_0 <= 0; A_3_1 <= 0; A_3_2 <= 0; A_3_3 <= 0;
    end else begin
        A_1_0 <= A_0_0; A_1_1 <= A_0_1; A_1_2 <= A_0_2; A_1_3 <= A_0_3;
        A_2_0 <= A_1_0; A_2_1 <= A_1_1; A_2_2 <= A_1_2; A_2_3 <= A_1_3;
        A_3_0 <= A_2_0; A_3_1 <= A_2_1; A_3_2 <= A_2_2; A_3_3 <= A_2_3;
    end
end

always@(posedge clk or negedge rst_n ) begin
    if( !rst_n ) begin
        B_0_1 <= 0; B_0_2 <= 0; B_0_3 <= 0;
        B_1_1 <= 0; B_1_2 <= 0; B_1_3 <= 0;
        B_2_1 <= 0; B_2_2 <= 0; B_2_3 <= 0;
        B_3_1 <= 0; B_3_2 <= 0; B_3_3 <= 0;
    end else begin
        B_0_1 <= B_0_0; B_0_2 <= B_0_1; B_0_3 <= B_0_2;
        B_1_1 <= B_1_0; B_1_2 <= B_1_1; B_1_3 <= B_1_2;
        B_2_1 <= B_2_0; B_2_2 <= B_2_1; B_2_3 <= B_2_2;
        B_3_1 <= B_3_0; B_3_2 <= B_3_1; B_3_3 <= B_3_2;
    end
end

PE pe0_0 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_0_0),
    .A(A_0_0),
    .B(B_0_0),
    .C(C_0_0),
    .offset(input_offset)
);

PE pe0_1 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_0_1),
    .A(A_0_1),
    .B(B_0_1),
    .C(C_0_1),
    .offset(input_offset)
);

PE pe0_2 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_0_2),
    .A(A_0_2),
    .B(B_0_2),
    .C(C_0_2),
    .offset(input_offset)
);

PE pe0_3 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_0_3),
    .A(A_0_3),
    .B(B_0_3),
    .C(C_0_3),
    .offset(input_offset)
);

PE pe1_0 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_1_0),
    .A(A_1_0),
    .B(B_1_0),
    .C(C_1_0),
    .offset(input_offset)
);

PE pe1_1 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_1_1),
    .A(A_1_1),
    .B(B_1_1),
    .C(C_1_1),
    .offset(input_offset)
);

PE pe1_2 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_1_2),
    .A(A_1_2),
    .B(B_1_2),
    .C(C_1_2),
    .offset(input_offset)
);

PE pe1_3 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_1_3),
    .A(A_1_3),
    .B(B_1_3),
    .C(C_1_3),
    .offset(input_offset)
);

PE pe2_0 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_2_0),
    .A(A_2_0),
    .B(B_2_0),
    .C(C_2_0),
    .offset(input_offset)
);

PE pe2_1 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_2_1),
    .A(A_2_1),
    .B(B_2_1),
    .C(C_2_1),
    .offset(input_offset)
);

PE pe2_2 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_2_2),
    .A(A_2_2),
    .B(B_2_2),
    .C(C_2_2),
    .offset(input_offset)
);

PE pe2_3 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_2_3),
    .A(A_2_3),
    .B(B_2_3),
    .C(C_2_3),
    .offset(input_offset)
);

PE pe3_0 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_3_0),
    .A(A_3_0),
    .B(B_3_0),
    .C(C_3_0),
    .offset(input_offset)
);

PE pe3_1 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_3_1),
    .A(A_3_1),
    .B(B_3_1),
    .C(C_3_1),
    .offset(input_offset)
);

PE pe3_2 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_3_2),
    .A(A_3_2),
    .B(B_3_2),
    .C(C_3_2),
    .offset(input_offset)
);

PE pe3_3 (
    .clk(clk),
    .rst_n(rst_n),
    .PE_re(PE_re_3_3),
    .A(A_3_3),
    .B(B_3_3),
    .C(C_3_3),
    .offset(input_offset)
);

endmodule

module PE(
    clk,
    rst_n,
    PE_re,
    A,
    B,
    C,
    offset
);

input clk;
input rst_n;
input PE_re;
input [7:0] A;
input [7:0] B;
input [31:0] offset;
output reg signed [31:0] C;

wire signed [31:0] sum;
wire signed [31:0] A_ext;
wire signed [31:0] B_ext;
wire signed [31:0] offset_ext;

assign A_ext = { {24{A[7]}}, A};
assign B_ext = { {24{B[7]}}, B};
assign offset_ext = offset;

//assign A_ext = { {24{0}}, A};
//assign B_ext = { {24{0}}, B};

assign sum = (A_ext + offset_ext) * B_ext;

always@(posedge clk or negedge rst_n ) begin
    if(!rst_n) begin
        C <= 0;
    end else begin
        C <= (PE_re)? 0: C + sum;
    end
end
endmodule
