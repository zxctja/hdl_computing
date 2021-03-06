//-------------------------------------------------------------------
// CopyRight(c) 2019 zhaoxingchang All Rights Reserved
//-------------------------------------------------------------------
// ProjectName    : 
// Author         : zhaoxingchang
// E-mail         : zxctja@163.com
// FileName       :	PickBestIntra.v
// ModelName      : 
// Description    : 
//-------------------------------------------------------------------
// Create         : 2019-11-17 13:30
// LastModified   :	2019-11-29 13:41
// Version        : 1.0
//-------------------------------------------------------------------

`timescale 1ns/100ps

module PickBestIntra#(
 parameter BLOCK_SIZE   = 16
)(
 input                                                    clk
,input                                                    rst_n
,input                                                    start
,input                                                    clear
,input             [10                           - 1 : 0] x
,input             [10                           - 1 : 0] y
,input      signed [32                           - 1 : 0] lambda_i16
,input      signed [32                           - 1 : 0] tlambda
,input      signed [32                           - 1 : 0] lambda_mode
,input      signed [32                           - 1 : 0] min_disto
,input             [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Ysrc
,input             [ 8                           - 1 : 0] top_left
,input             [ 8 * BLOCK_SIZE              - 1 : 0] top
,input             [ 8 * BLOCK_SIZE              - 1 : 0] left
,input             [16 * BLOCK_SIZE              - 1 : 0] q1
,input             [16 * BLOCK_SIZE              - 1 : 0] iq1
,input             [32 * BLOCK_SIZE              - 1 : 0] bias1
,input             [32 * BLOCK_SIZE              - 1 : 0] zthresh1
,input             [16 * BLOCK_SIZE              - 1 : 0] sharpen1
,input             [16 * BLOCK_SIZE              - 1 : 0] q2
,input             [16 * BLOCK_SIZE              - 1 : 0] iq2
,input             [32 * BLOCK_SIZE              - 1 : 0] bias2
,input             [32 * BLOCK_SIZE              - 1 : 0] zthresh2
,input             [16 * BLOCK_SIZE              - 1 : 0] sharpen2
,output            [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] out
,output reg        [64                           - 1 : 0] Score
,output            [32                           - 1 : 0] mode_i16
,output reg        [32                           - 1 : 0] max_edge
,output            [16 * BLOCK_SIZE              - 1 : 0] dc_levels
,output            [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] ac_levels
,output            [32                           - 1 : 0] nz
,output reg                                               done
);

wire[2047:0]pred[3:0];
reg         rec_start;
wire        rec_done;
reg [2047:0]YPred;
wire[2047:0]Yout;
wire[ 255:0]Y_dc_levels;
wire[4095:0]Y_ac_levels;
wire[  31:0]nz_i;
wire[  31:0]sse;
wire        sse_done;
wire[  31:0]disto;
wire        disto_done;
wire[ 255:0]kWeightY;
wire[  15:0]FixedCost[3:0];
wire[  31:0]sum;
wire        cost_done;
reg [ 255:0]dc_tmp;
reg [4095:0]ac_tmp;
reg [  31:0]nz_tmp;
reg [2047:0]Yout_tmp;
reg [  63:0]score_tmp;
reg [  31:0]tmp0;
reg [  31:0]tmp1;
reg [  31:0]tmp2;
reg [  31:0]tmp3;
reg [  31:0]D_tmp;
reg [   2:0]i16;
reg [   1:0]mode;
reg [   1:0]mode_tmp;

assign kWeightY[ 15:  0] = 'd38;
assign kWeightY[ 31: 16] = 'd32;
assign kWeightY[ 47: 32] = 'd20;
assign kWeightY[ 63: 48] = 'd9;
assign kWeightY[ 79: 64] = 'd32;
assign kWeightY[ 95: 80] = 'd28;
assign kWeightY[111: 96] = 'd17;
assign kWeightY[127:112] = 'd7;
assign kWeightY[143:128] = 'd20;
assign kWeightY[159:144] = 'd17;
assign kWeightY[175:160] = 'd10;
assign kWeightY[191:176] = 'd4;
assign kWeightY[207:192] = 'd9;
assign kWeightY[223:208] = 'd7;
assign kWeightY[239:224] = 'd4;
assign kWeightY[255:240] = 'd2;

assign FixedCost[0] = 'd663;
assign FixedCost[1] = 'd919;
assign FixedCost[2] = 'd872;
assign FixedCost[3] = 'd919;

assign ac_levels = ac_tmp;
assign dc_levels = dc_tmp;
assign nz = nz_tmp;
assign out = Yout_tmp;
assign mode_i16 = {30'b0,mode};

DC_Pred U_DC_PRED(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( start                         ),
    .x                              ( x                             ),
    .y                              ( y                             ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( pred[0]                       ),
    .done                           (                               )
);

True_Motion_Pred U_TRUE_MOTION_PRED(
    .top_left                       ( top_left                      ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( pred[1]                       )
);

Vertical_Pred U_VERTICAL_PRED(
    .top                            ( top                           ),
    .dst                            ( pred[2]                       )
);

Horizontal_Pred U_HORIZONTAL_PRED(
    .left                           ( left                          ),
    .dst                            ( pred[3]                       )
);

Reconstruct U_RECONSTRUCT(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_start                     ),
    .YPred                          ( YPred                         ),
    .Ysrc                           ( Ysrc                          ),
    .q1                             ( q1                            ),
    .iq1                            ( iq1                           ),
    .bias1                          ( bias1                         ),
    .zthresh1                       ( zthresh1                      ),
    .sharpen1                       ( sharpen1                      ),
    .q2                             ( q2                            ),
    .iq2                            ( iq2                           ),
    .bias2                          ( bias2                         ),
    .zthresh2                       ( zthresh2                      ),
    .sharpen2                       ( sharpen2                      ),
    .Yout                           ( Yout                          ),
    .Y_dc_levels                    ( Y_dc_levels                   ),
    .Y_ac_levels                    ( Y_ac_levels                   ),
    .nz                             ( nz_i                          ),
    .done                           ( rec_done                      )
);

GetSSE U_GETSSE(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_done                      ),
    .a                              ( Ysrc                          ),
    .b                              ( Yout                          ),
    .sse                            ( sse                           ),
    .done                           ( sse_done                      )
);

Disto16x16 U_DISTO16X16(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_done                      ),
    .ina                            ( Ysrc                          ),
    .inb                            ( Yout                          ),
    .w                              ( kWeightY                      ),
    .sum                            ( disto                         ),
    .done                           ( disto_done                    )
);

GetCostLuma U_GETCOSTLUMA(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_done                      ),
    .ac                             ( Y_ac_levels                   ),
    .dc                             ( Y_dc_levels                   ),
    .sum                            ( sum                           ),
    .done                           ( cost_done                     )
);

reg [7:0] cstate;
reg [7:0] nstate;

parameter IDLE   = 'h1;
parameter PRED   = 'h2;
parameter WAIT   = 'h4; 
parameter SCORE0 = 'h8;
parameter SCORE1 = 'h10;
parameter COMP   = 'h20;
parameter STORE  = 'h40;
parameter DONE   = 'h80;

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)
        cstate <= IDLE;
    else
        cstate <= nstate;
end

always @ * begin
    case(cstate)
        IDLE:
            if(start)
                nstate = PRED;
            else
                nstate = IDLE;
        PRED:
            nstate = WAIT;
        WAIT:
            if(disto_done)
                nstate = SCORE0;
            else
                nstate = WAIT;
        SCORE0:
            nstate = SCORE1;
        SCORE1:
            nstate = COMP;
        COMP:
            if((Score >= score_tmp) | (mode_tmp == 2'b11))
                nstate = STORE;
            else
                if(i16 == 3'b111)
                    nstate = DONE;
                else
                    nstate = PRED;
        STORE:
            if(i16 == 3'b111)
                nstate = DONE;
            else
                nstate = PRED;
        DONE:
            nstate = IDLE;
        default:
            nstate = IDLE;
    endcase
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        i16       <= 'b0;
        rec_start <= 'b0;
        YPred     <= 'b0;
        Score     <= 'b0;
        score_tmp <= 'b0;
        mode      <= 'b0;
        mode_tmp  <= 'b0;
        Yout_tmp  <= 'b0;
        dc_tmp    <= 'b0;
        ac_tmp    <= 'b0;
        nz_tmp    <= 'b0;
        tmp0      <= 'b0;
        tmp1      <= 'b0;
        tmp2      <= 'b0;
        tmp3      <= 'b0;
        D_tmp     <= 'b0;
        done      <= 'b0;
    end
    else begin
        case(cstate)
            IDLE:begin
                i16       <= 2'd3;
                done      <= 1'b0;
            end
            PRED:begin
                rec_start <= 1'b1;
                YPred     <= pred[i16];
                i16       <= i16 - 1'b1;
                mode_tmp  <= i16;
            end
            WAIT:begin
                rec_start <= 1'b0;
            end
            SCORE0:begin
                tmp0      <= (sum << 10) + FixedCost[mode_tmp];
                tmp1      <= (sse << 8) + disto * tlambda;
            end
            SCORE1:begin
                score_tmp <= tmp0 * lambda_i16 + tmp1;
            end
            COMP:begin
                ;
            end
            STORE:begin
                Score     <= score_tmp;
                mode      <= mode_tmp;
                Yout_tmp  <= Yout;
                dc_tmp    <= Y_dc_levels;
                ac_tmp    <= Y_ac_levels;
                nz_tmp    <= nz_i;
                tmp2      <= tmp0;
                tmp3      <= tmp1;
                D_tmp     <= sse;
            end
            DONE:begin
                Score     <= tmp2 * lambda_mode + tmp3;
                done      <= 1'b1;
            end
        endcase
    end
end

wire[31:0]v0,v1,v2;
assign v0 = {16'b0,(dc_tmp[31] ? (~dc_tmp[31:16] + 1'b1) : dc_tmp[31:16])};
assign v1 = {16'b0,(dc_tmp[47] ? (~dc_tmp[47:32] + 1'b1) : dc_tmp[47:32])};
assign v2 = {16'b0,(dc_tmp[79] ? (~dc_tmp[79:64] + 1'b1) : dc_tmp[79:64])};
wire[31:0]max0,max1;
assign max0 = (v1 > v0) ? v1 : v0;
assign max1 = (v2 > max_edge) ? v2 : max_edge;

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        max_edge <= 'b0;
    end
    else begin
        if(clear)
            max_edge <= 'b0;
        else if(done) 
            if((nz_tmp == 'h1000000) && (D_tmp > min_disto))
                max_edge <= (max0 > max1) ? max0 : max1;
    end
end

endmodule
