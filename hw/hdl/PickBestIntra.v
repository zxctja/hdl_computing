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
,input             [10                           - 1 : 0] x
,input             [10                           - 1 : 0] y
,input      signed [32                           - 1 : 0] lambda_i16
,input      signed [32                           - 1 : 0] tlambda
,input      signed [32                           - 1 : 0] lambda_mode
,input      signed [32                           - 1 : 0] min_disto
,input      signed [32                           - 1 : 0] max_edgei
,input                                                    reload
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
,output reg        [32                           - 1 : 0] max_edgeo
,output            [16 * BLOCK_SIZE              - 1 : 0] dc_levels
,output            [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] ac_levels
,output            [32                           - 1 : 0] nz
,output reg                                               done
);

wire [8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]pred[3:0];
DC_Pred U_DC_PRED(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( start                         ),
    .x                              ( x                             ),
    .y                              ( y                             ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( pred[3]                       ),
    .done                           (                               )
);

Vertical_Pred U_VERTICAL_PRED(
    .top                            ( top                           ),
    .dst                            ( pred[0]                       )
);

Horizontal_Pred U_HORIZONTAL_PRED(
    .left                           ( left                          ),
    .dst                            ( pred[1]                       )
);

True_Motion_Pred U_TRUE_MOTION_PRED(
    .top_left                       ( top_left                      ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( pred[2]                       )
);

wire        rec_done;
reg         rec_start;
reg [2047:0]YPred;
wire[2047:0]Yout;
wire[ 255:0]Y_dc_levels;
wire[4095:0]Y_ac_levels;
wire[  31:0]nz_i;
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

wire[31:0]sse;
wire sse_done;
GetSSE U_GETSSE(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_done                      ),
    .a                              ( Ysrc                          ),
    .b                              ( Yout                          ),
    .sse                            ( sse                           ),
    .done                           ( sse_done                      )
);

wire[31:0]disto;
wire disto_done;
wire[255:0]kWeightY;

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

wire[15:0]FixedCost[3:0];
assign FixedCost[0] = 'd663;
assign FixedCost[1] = 'd919;
assign FixedCost[2] = 'd872;
assign FixedCost[3] = 'd919;

wire[31:0]sum;
wire cost_done;
GetCostLuma U_GETCOSTLUMA(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( rec_done                      ),
    .ac                             ( Y_ac_levels                   ),
    .dc                             ( Y_dc_levels                   ),
    .sum                            ( sum                           ),
    .done                           ( cost_done                     )
);

reg [9:0] cstate;
reg [9:0] nstate;

reg [   1:0]count;
reg [ 255:0]dc_tmp;
reg [4095:0]ac_tmp;
reg [  31:0]nz_tmp;
reg [2047:0]Yout_tmp;
reg [  63:0]score_tmp;
reg [  31:0]D_tmp;
reg [  31:0]SD_tmp;
reg [  31:0]H_tmp;
reg [  31:0]R_tmp;
reg [   1:0]i16;
reg [   1:0]mode;
reg         flag;

assign ac_levels = ac_tmp;
assign dc_levels = dc_tmp;
assign nz = nz_tmp;
assign out = Yout_tmp;
assign mode_i16 = {'b0,mode};

parameter IDLE        = 'h1;
parameter PRED        = 'h2;
parameter WAIT        = 'h4; 
parameter FIRSTSCORE  = 'h8;
parameter SCORE       = 'h10;
parameter COMP        = 'h20;
parameter STORE       = 'h40;
parameter LASTSCORE   = 'h80;
parameter STORE_DELTA = 'h100;
parameter DONE        = 'h200;

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
        PERD:
            nstate = WAIT;
        WAIT:
            if(count == 2'b11)
                if(i16 == 'b1)
                    nstate = FIRSTSCORE;
                else
                    nstate = SCORE;
            else
                nstate = WAIT;
        FIRSTSCORE:
            nstate = PRED;
        SCORE:
            nstate = COMP;
        COMP:
            if(Score > score_tmp)
                nstate = STORE;
            else
                if(i16 == 'd0)
                    nstate = LASTSCORE;
                else
                    nstate = PRED;
        STORE:
            if(i16 == 'd0)
                nstate = LASTSCORE;
            else
                nstate = PRED;
        LASTSCORE:
            if(((nz_tmp & 'h100ffff) == 'h1000000) && (D_tmp > min_disto))
                nstate = STORE_DELTA;
            else
                nstate = DONE;
        STORE_DELTA:
            nstate = DONE;
        DONE:
            nstate = IDLE;
        default:
            nstate = IDLE;
    endcase
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        rec_start <= 'b0;
        dc_tmp    <= 'b0;
        ac_tmp    <= 'b0;
        nz_tmp    <= 'b0;
        Score     <= 'b0;
        score_tmp <= 'b0;
        Yout_tmp  <= 'b0;
        mode      <= 'b0;
        D_tmp     <= 'b0;
        SD_tmp    <= 'b0;
        H_tmp     <= 'b0;
        R_tmp     <= 'b0;
        flag      <= 'b0;
        i16       <= 'b0;
        done      <= 'b0;
    end
    else begin
        case(cstate)
            IDLE:begin
                i16       <= 2'b0;
                done      <= 1'b0;
            end
            PRED:begin
                rec_start <= 1'b1;
                YPred     <= pred[i16];
                i16       <= i16 + 1'b1;
            end
            WAIT:begin
                rec_start <= 1'b0;
            end
            FIRSTSCORE:begin
                Score     <= ((sum << 10) + FixedCost[1]) * lambda_i16 +
                             'd256 * (sse + ((disto * tlambda + 'd128) >> 8));
                mode      <= 2'b1;
                i16       <= 2'b1;
                dc_tmp    <= Y_dc_levels;
                ac_tmp    <= Y_ac_levels;
                Yout_tmp  <= Yout;
                nz_tmp    <= nz_i;
                D_tmp     <= sse;
                SD_tmp    <= disto;
                H_tmp     <= FixedCost[1];
                R_tmp     <= sum;
            end
            SCORE:begin
                score_tmp <= ((sum << 10) + FixedCost[i16]) * lambda_i16 +
                             'd256 * (sse + ((disto * tlambda + 'd128) >> 8));
            end
            COMP:begin
                ;
            end
            STORE:begin
                mode      <= i16;
                dc_tmp    <= Y_dc_levels;
                ac_tmp    <= Y_ac_levels;
                Yout_tmp  <= Yout;
                nz_tmp    <= nz_i;
                Score     <= score_tmp;
                D_tmp     <= sse;
                SD_tmp    <= disto;
                H_tmp     <= FixedCost[i16];
                R_tmp     <= sum;
            end
            LASTSCORE:begin
                Score     <= ((R_tmp << 10) + H_tmp) * lambda_mode +
                             'd256 * (D_tmp + ((SD_tmp * tlambda + 'd128) >> 8));
            end
            STORE_DELTA:begin
                flag      <= 1'b1;
            end
            DONE:begin
                done      <= 1'b1;
                flag      <= 1'b0;
            end
        endcase
    end
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        count <= 'b0;
    end
    else begin
        if(rec_done)
            count <= 'b0;
        else
            case({sse_done,disto_done,cost_done})
                3'b111:count <= count + 2'b11;
                3'b110:count <= count + 2'b10;
                3'b101:count <= count + 2'b10;
                3'b011:count <= count + 2'b10;
                3'b001:count <= count + 2'b01;
                3'b010:count <= count + 2'b01;
                3'b100:count <= count + 2'b01;
                3'b000:count <= count + 2'b00;
            endcase
    end
end

wire[31:0]v0,v1,v2;
assign v0 = (dc_tmp[31:16] < 'b0) ? ('b0 - dc_tmp[31:16]) : dc_tmp[31:16];
assign v1 = (dc_tmp[47:32] < 'b0) ? ('b0 - dc_tmp[47:32]) : dc_tmp[47:32];
assign v2 = (dc_tmp[79:64] < 'b0) ? ('b0 - dc_tmp[79:64]) : dc_tmp[79:64];
wire[31:0]max0,max1;
assign max0 = (v1 > v0) ? v1 : v0;
assign max1 = (v2 > max_edgeo) ? v2 : max_edgeo;

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        max_edgeo <= 'b0;
    end
    else begin
        if(reload)
            max_edgeo <= max_edgei;
        else if(flag)
            max_edgeo <= (max0 > max1) ? max0 : max1;
    end
end

endmodule