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

  // Constants for Function IDs
  parameter FUNC_ID_ADD = 10'd0;
  parameter FUNC_ID_RESET = 10'd1;
  parameter FUNC_ID_SET_INPUT_OFFSET = 10'd2;
  parameter FUNC_ID_SET_FILTER_OFFSET = 10'd3;

  reg signed [8:0] input_offset;
  reg signed [8:0] filter_offset;

  // BUG FIX: Widened from [15:0] to [21:0] to prevent overflow.
  // (9 bit + 9 bit) * (9 bit + 9 bit) needs ~18-20 bits. 22 is safe.
  wire signed [21:0] prod_0, prod_1, prod_2, prod_3;

  assign prod_0 =  ($signed(cmd_payload_inputs_0[7 : 0]) + input_offset) * ($signed(cmd_payload_inputs_1[7 : 0]) + filter_offset);
  assign prod_1 =  ($signed(cmd_payload_inputs_0[15: 8]) + input_offset) * ($signed(cmd_payload_inputs_1[15: 8]) + filter_offset);
  assign prod_2 =  ($signed(cmd_payload_inputs_0[23:16]) + input_offset) * ($signed(cmd_payload_inputs_1[23:16]) + filter_offset);
  assign prod_3 =  ($signed(cmd_payload_inputs_0[31:24]) + input_offset) * ($signed(cmd_payload_inputs_1[31:24]) + filter_offset);

  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 + prod_1 + prod_2 + prod_3;
  
  assign cmd_ready = ~rsp_valid;

  always @(posedge clk) begin
    if (reset) begin
      input_offset <= 9'd0;
      filter_offset <= 9'd0;
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;

    end else if (rsp_valid) begin
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      
      if (cmd_payload_function_id[9:0] == FUNC_ID_ADD) begin 
        rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;

      end else if (cmd_payload_function_id[9:0] == FUNC_ID_RESET) begin 
        rsp_payload_outputs_0 <= 32'b0;

      // FIX: Corrected parameter name from FUNC_ID_SET_OFFSET to FUNC_ID_SET_INPUT_OFFSET
      end else if (cmd_payload_function_id[9:0] == FUNC_ID_SET_INPUT_OFFSET) begin 
        input_offset <= $signed(cmd_payload_inputs_0[8:0]);
        // Optional: hold output stable
        rsp_payload_outputs_0 <= rsp_payload_outputs_0;

      // FIX: Removed the extra "end" that was here
      end else if (cmd_payload_function_id[9:0] == FUNC_ID_SET_FILTER_OFFSET) begin 
        filter_offset <= $signed(cmd_payload_inputs_0[8:0]);
        rsp_payload_outputs_0 <= rsp_payload_outputs_0;
      end
    end
  end
endmodule