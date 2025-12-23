// Copyright 2021 The CFU-Playground Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "TPU.v"
`include "global_buffer_bram.v"

module Cfu (
    input               cmd_valid,
    output              cmd_ready,
    input      [9:0]    cmd_payload_function_id,
    input      [31:0]   cmd_payload_inputs_0,
    input      [31:0]   cmd_payload_inputs_1,
    output reg          rsp_valid,
    input               rsp_ready,
    output reg [31:0]   rsp_payload_outputs_0,
    input               reset,
    input               clk
);

wire [31:0] A_data_in, A_data_out, B_data_in, B_data_out;
wire [127:0] C_data_in, C_data_out;
wire [31:0] A_data_in_TPU, B_data_in_TPU;
wire [14:0] A_index, B_index, C_index;//
wire [14:0] A_index_TPU, B_index_TPU, C_index_TPU;//
wire A_wr_en, B_wr_en, C_wr_en;
wire A_wr_en_TPU, B_wr_en_TPU, C_wr_en_TPU;
wire TPU_busy;
reg TPU_busy_delay;
reg start_for_TPU, start_for_TPU_delay_1, start_for_TPU_delay_2, start_for_TPU_delay_3;
wire start_TPU;
reg [14:0] A_index_reg, B_index_reg, C_index_reg;//
reg [1:0] C_out_count;
reg [31:0] buff_for_last;
reg [10:0] M_reg, K_reg, N_reg;//
reg [31:0] input_offset_reg;
wire [10:0] M_TPU, K_TPU, N_TPU;//
wire [31:0] input_offset_TPU;
reg out_rsp;

assign M_TPU = M_reg;
assign N_TPU = N_reg;
assign K_TPU = K_reg;
assign input_offset_TPU = input_offset_reg;

//4 for M N 5 for K
always@( posedge clk or posedge reset ) begin
    if( reset ) begin
    	M_reg <= 0;
        K_reg <= 0;
        N_reg <= 0;
        input_offset_reg <= 0;
    end else if(  (cmd_valid && cmd_payload_function_id[9:3] == 4 ) ) begin
    	M_reg <= cmd_payload_inputs_0[10:0];//
    	K_reg <= cmd_payload_inputs_0[21:11];//
    	N_reg <= cmd_payload_inputs_0[10:0];//
    	input_offset_reg <= cmd_payload_inputs_1;
    end
end

//counter A
always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        A_index_reg <= 0;
    end else if(  (cmd_valid && (cmd_payload_function_id[9:3] == 1 ||  cmd_payload_function_id[9:3] == 3 ) ) || ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 ) ) begin
    	if( A_index_reg == 3 + (M_reg>>2)*(K_reg) ) begin
    	    A_index_reg <= 0;
    	end else begin
    	    A_index_reg <= A_index_reg + 1;
    	end
    end
end

//counter B
always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        B_index_reg <= 0;
    end else if( (cmd_valid && (cmd_payload_function_id[9:3] == 1 || cmd_payload_function_id[9:3] == 3) ) || ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 ) ) begin
    	if( B_index_reg == 3 + (N_reg>>2)*(K_reg) ) begin
    	    B_index_reg <= 0;
    	end else begin
    	    B_index_reg <= B_index_reg + 1;
    	end
    end
end

//counter C
always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        C_index_reg <= 0;
    end else if(  cmd_valid && cmd_payload_function_id[9:3] == 2 && C_out_count == 3 ) begin
    	if( C_index_reg == (M_reg>>2)*(N_reg) - 1 ) begin
    	    C_index_reg <= 0;
    	end else begin
    	    C_index_reg <= C_index_reg + 1;
    	end
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        C_out_count <= 0;
    end else if(  cmd_valid && cmd_payload_function_id[9:3] == 2 ) begin
    	if( C_out_count == 3 ) begin
    	    C_out_count <= 0;
    	end else begin
    	    C_out_count <= C_out_count + 1;
    	end
    end
end

//control signal of TPU
always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        start_for_TPU <= 0;
    end else if( cmd_valid && cmd_payload_function_id[9:3] == 3 ) begin
    	start_for_TPU <= 1;
    end else if( !TPU_busy ) begin
    	start_for_TPU <= 0;
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        start_for_TPU_delay_1 <= 0;
    end else begin
    	start_for_TPU_delay_1 <= start_for_TPU;
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        start_for_TPU_delay_2 <= 0;
    end else begin
    	start_for_TPU_delay_2 <= start_for_TPU_delay_1;
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        start_for_TPU_delay_3 <= 0;
    end else begin
    	start_for_TPU_delay_3 <= start_for_TPU_delay_2;
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        TPU_busy_delay <= 0;
    end else begin
    	TPU_busy_delay <= TPU_busy;
    end
end

// Only not ready for a command when we have a response.
assign cmd_ready = 1;
always @(*) begin
    if( ( cmd_valid && (cmd_payload_function_id[9:3] == 1 ||
    			cmd_payload_function_id[9:3] == 4 ) ) 
    			|| ( !TPU_busy && TPU_busy_delay ) ) begin
        rsp_valid = 1;
    end else begin
        rsp_valid = out_rsp;
    end
end

always @(posedge clk) begin
    if( cmd_valid && cmd_payload_function_id[9:3] == 2 ) begin
        out_rsp <= 1;
    end else begin
        out_rsp <= 0;
    end
end

//output
always @(posedge clk) begin
    if( cmd_valid && cmd_payload_function_id[9:3] == 2 ) begin
        case( C_out_count )
            0: begin
                rsp_payload_outputs_0 <= C_data_out[127:96];
            end
            1: begin
                rsp_payload_outputs_0 <= C_data_out[95:64];
            end
            2: begin
                rsp_payload_outputs_0 <= C_data_out[63:32];
            end
            3: begin
                rsp_payload_outputs_0 <= C_data_out[31:0];
            end
            default: begin
                rsp_payload_outputs_0 <= 32'b0;
            end
        endcase
    end else begin
    	rsp_payload_outputs_0 <= 0;
    end
end

always@( posedge clk or posedge reset ) begin
    if( reset ) begin
        buff_for_last <= 1;
    end else if( C_out_count == 1 ) begin
    	buff_for_last <= C_data_out[31:0];
    end
end

assign A_data_in = (cmd_valid && cmd_payload_function_id[9:3] == 1)? cmd_payload_inputs_0: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )?0: A_data_in_TPU;
assign B_data_in = (cmd_valid && cmd_payload_function_id[9:3] == 1)? cmd_payload_inputs_1: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )?0: B_data_in_TPU;

assign A_index = ( cmd_valid && cmd_payload_function_id[9:3] == 1 )? A_index_reg: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )? A_index_reg: A_index_TPU;
assign B_index = ( cmd_valid && cmd_payload_function_id[9:3] == 1 )? B_index_reg: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )? B_index_reg: B_index_TPU;
assign C_index = ( !TPU_busy )? C_index_reg: C_index_TPU;

assign A_wr_en = ( cmd_valid && cmd_payload_function_id[9:3] == 1 )? 1: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )?1: A_wr_en_TPU;
assign B_wr_en = ( cmd_valid && cmd_payload_function_id[9:3] == 1 )? 1: ( start_for_TPU || start_for_TPU_delay_1 || start_for_TPU_delay_2 )?1: B_wr_en_TPU;
assign C_wr_en = ( cmd_valid && cmd_payload_function_id[9:3] == 2 )? 0: C_wr_en_TPU;

assign start_TPU = start_for_TPU_delay_3;

//declare TPU
TPU my_TPU(
    .clk(clk),
    .rst_n(!reset),
    .in_valid(start_TPU),
    .K(K_TPU),
    .M(M_TPU),
    .N(N_TPU),
    .input_offset( input_offset_TPU ),
    .busy(TPU_busy),
    .A_wr_en(A_wr_en_TPU),
    .A_index(A_index_TPU),
    .A_data_in(A_data_in_TPU),
    .A_data_out(A_data_out),
    .B_wr_en(B_wr_en_TPU),
    .B_index(B_index_TPU),
    .B_data_in(B_data_in_TPU),
    .B_data_out(B_data_out),
    .C_wr_en(C_wr_en_TPU),
    .C_index(C_index_TPU),
    .C_data_in(C_data_in),
    .C_data_out(128'b0)
);

//declare BRAM
global_buffer_bram #(
    .ADDR_BITS(15), //
    .DATA_BITS(32)
)
gbuff_A(
  .clk(clk),
  .rst_n(1'b1),
  .ram_en(1'b1),
  .wr_en(A_wr_en),
  .index(A_index),
  .data_in(A_data_in),
  .data_out(A_data_out)
);

global_buffer_bram #(
    .ADDR_BITS(15), //
    .DATA_BITS(32)
)
gbuff_B(
  .clk(clk),
  .rst_n(1'b1),
  .ram_en(1'b1),
  .wr_en(B_wr_en),
  .index(B_index),
  .data_in(B_data_in),
  .data_out(B_data_out)
);

global_buffer_bram #(
    .ADDR_BITS(13), //
    .DATA_BITS(128) 
)
gbuff_C(
  .clk(clk),
  .rst_n(1'b1),
  .ram_en(1'b1),
  .wr_en(C_wr_en),
  .index(C_index),
  .data_in(C_data_in),
  .data_out(C_data_out)
);
    
endmodule

