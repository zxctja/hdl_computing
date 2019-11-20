//-------------------------------------------------------------------
// CopyRight(c) 2019 zhaoxingchang All Rights Reserved
//-------------------------------------------------------------------
// ProjectName    : 
// Author         : zhaoxingchang
// E-mail         : zxctja@163.com
// FileName       :	QuantizeBlock.v
// ModelName      : 
// Description    : 
//-------------------------------------------------------------------
// Create         : 2019-11-15 11:29
// LastModified   :	2019-11-20 14:42
// Version        : 1.0
//-------------------------------------------------------------------

`timescale 1ns/100ps

module QuantizeBlock#(
 parameter BIT_WIDTH    = 8
,parameter BLOCK_SIZE   = 4
)(
 input                                                          clk
,input                                                          rst_n
,input                                                          start
,input      [(BIT_WIDTH + 8) * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] in
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]              q
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]              iq
,input      [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]              bias
,input      [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]              zthresh
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]              sharpen
,output     [(BIT_WIDTH + 8) * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] R_in
,output     [(BIT_WIDTH + 8) * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] out
,output reg                                                     done
);

reg signed [BIT_WIDTH + 7 : 0]in_i [BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg signed [BIT_WIDTH + 7 : 0]Rin_i[BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg signed [BIT_WIDTH + 7 : 0]out_i[BLOCK_SIZE * BLOCK_SIZE - 1 : 0];

reg [15:0]q_i      [BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg [15:0]iq_i     [BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg [31:0]bias_i   [BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg [31:0]zthresh_i[BLOCK_SIZE * BLOCK_SIZE - 1 : 0];
reg [15:0]sharpen_i[BLOCK_SIZE * BLOCK_SIZE - 1 : 0];

reg signed [31:0]level[BLOCK_SIZE * BLOCK_SIZE - 1 : 0];

reg shift;

always @ (posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        done  <= 'b0;
        shift <= 'b0;
    end
    else begin
        shift <= start;
        done  <= shift;
    end
end

genvar i;

generate

for(i = 0; i < BLOCK_SIZE * BLOCK_SIZE; i = i + 1)begin
    assign in_i[i] = in   [(BIT_WIDTH + 8) * (i + 1) - 1 : (BIT_WIDTH + 8) * i];
    assign R_in[i] = Rin_i[(BIT_WIDTH + 8) * (i + 1) - 1 : (BIT_WIDTH + 8) * i];
    assign out [i] = out_i[(BIT_WIDTH + 8) * (i + 1) - 1 : (BIT_WIDTH + 8) * i];

    assign q_i      [i] = q      [16 * (i + 1) - 1 : 16 * i];
    assign iq_i     [i] = iq     [16 * (i + 1) - 1 : 16 * i];
    assign bias_i   [i] = bias   [31 * (i + 1) - 1 : 31 * i];
    assign zthresh_i[i] = zthresh[31 * (i + 1) - 1 : 31 * i];
    assign sharpen_i[i] = sharpen[16 * (i + 1) - 1 : 16 * i];
end

for(i = 0; i < BLOCK_SIZE * BLOCK_SIZE; i = i + 1)begin
    wire sign;
    assign sign = in_i[i] < 'd0;

    wire[31:0]coeff;
    assign coeff = sign ? (sharpen_i[i] - in_i[i]) : (sharpen_i[i] + in_i[i]); 
    
    always @ (posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            level[i] <= 'b0;
        end
        else begin
            level[i] <= (coeff * iq_i + bias_i) >> 17;
        end
    end
    
    wire signed [31:0]level1;
    assign level1 = (level[i] > 'd2047) ? 'd2047 : level[i];
    
    wire signed [31:0]level2;
    assign level2 = sign ? ('d0 - level1) : level1;
    
    always @ (posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            Rin_i[i] <= 'b0;
            out_i[i] <= 'b0;
        end
        else begin
            if(coeff > zthresh_i[i])begin
                Rin_i[i] <= level2 * q_i[i];
                out_i[i] <= level2;
            end
            else begin
                Rin_i[i] <= 'b0;
                out_i[i] <= 'b0;
            end
        end
    end
end

endgenerate

//zigzag
assign out[ 0] = out_i[ 0];
assign out[ 1] = out_i[ 1];
assign out[ 2] = out_i[ 4];
assign out[ 3] = out_i[ 8];
assign out[ 4] = out_i[ 5];
assign out[ 5] = out_i[ 2];
assign out[ 6] = out_i[ 3];
assign out[ 7] = out_i[ 6];
assign out[ 8] = out_i[ 9];
assign out[ 9] = out_i[12];
assign out[10] = out_i[13];
assign out[11] = out_i[10];
assign out[12] = out_i[ 7];
assign out[13] = out_i[11];
assign out[14] = out_i[14];
assign out[15] = out_i[15];

endmodule
