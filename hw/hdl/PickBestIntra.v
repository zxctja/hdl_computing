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
 input                                             clk
,input                                             rst_n
,input                                             start
,input      [10                           - 1 : 0] x
,input      [10                           - 1 : 0] y
,input      [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Ysrc
,input      [ 8                           - 1 : 0] top_left
,input      [ 8 * BLOCK_SIZE              - 1 : 0] top
,input      [ 8 * BLOCK_SIZE              - 1 : 0] left
,input      [16 * BLOCK_SIZE              - 1 : 0] q1
,input      [16 * BLOCK_SIZE              - 1 : 0] iq1
,input      [32 * BLOCK_SIZE              - 1 : 0] bias1
,input      [32 * BLOCK_SIZE              - 1 : 0] zthresh1
,input      [16 * BLOCK_SIZE              - 1 : 0] sharpen1
,input      [16 * BLOCK_SIZE              - 1 : 0] q2
,input      [16 * BLOCK_SIZE              - 1 : 0] iq2
,input      [32 * BLOCK_SIZE              - 1 : 0] bias2
,input      [32 * BLOCK_SIZE              - 1 : 0] zthresh2
,input      [16 * BLOCK_SIZE              - 1 : 0] sharpen2
,output     [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Yout
,output     [64                           - 1 : 0] Score
,output     [ 2                           - 1 : 0] mode_i16
,output     [16 * BLOCK_SIZE              - 1 : 0] Y_dc_levels
,output     [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Y_ac_levels
,output                                            done
);

    parameter IDLE    = 6'h01;
    parameter BOTH    = 6'h02;
    parameter TOP     = 6'h04; 
    parameter LEFT    = 6'h08;
    parameter NONE    = 6'h10;
    parameter DONE    = 6'h20;
   
    reg  [5:0] cstate;
    reg  [5:0] nstate;

    wire[BIT_WIDTH - 1 : 0] top_i  [SHIFT - 2 : 0];
    wire[BIT_WIDTH - 1 : 0] left_i [SHIFT - 2 : 0];
    reg [BIT_WIDTH + SHIFT : 0] temp1;
    reg [BIT_WIDTH - 1 : 0] temp2;
    reg [SHIFT - 1 : 0]count;

    genvar i;

    generate

    for(i = 0; i < BLOCK_SIZE; i = i + 1)begin
        assign top_i [i] = top [BIT_WIDTH * (i + 1) - 1 : BIT_WIDTH * i];
        assign left_i[i] = left[BIT_WIDTH * (i + 1) - 1 : BIT_WIDTH * i];
    end

    endgenerate

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
                    if(x != 'b0)
                        if(y != 'b0)
                            nstate = BOTH;
                        else
                            nstate = LEFT;
                    else
                        if(y != 'b0)
                            nstate = TOP;
                        else
                            nstate = NONE;
                else
                    nstate = IDLE;
            BOTH:
                if(count < BLOCK_SIZE - 1)
                    nstate = BOTH;
                else
                    nstate = DONE;
            TOP:
                if(count < BLOCK_SIZE - 1)
                    nstate = TOP;
                else
                    nstate = DONE;
            LEFT: 
                if(count < BLOCK_SIZE - 1)
                    nstate = LEFT;
                else
                    nstate = DONE;
            NONE:
                nstate = DONE;
            DONE:
                nstate = IDLE;
            default:
                nstate = IDLE;
        endcase
    end

    always @ (posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            count <= 'b0;
            temp1 <= 'b0;
            temp2 <= 'b0;
            done  <= 'b0;
        end
        else begin
            case(cstate)
                IDLE:begin
                    count <= 'b0;
                    temp1 <= 'b0;
                    temp2 <= 'b0;
                    done  <= 'b0;
                end
                BOTH:begin
                    count <= count + 1'b1;
                    temp1 <= top_i[count] + left_i[count] + temp1;
                end
                TOP:begin
                    count <= count + 1'b1;
                    temp1 <= (top_i[count] << 1) + temp1;
                end
                LEFT:begin
                    count <= count + 1'b1;
                    temp1 <= (left_i[count] << 1) + temp1;
                end
                NONE:begin
                    temp1 <= 'h80 << SHIFT;
                end
                DONE:begin
                    temp2 <= (temp1 + BLOCK_SIZE) >> SHIFT;
                    done  <= 1'b1;
                end
            endcase
        end
    end

wire [8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] dc_pred;
DC_Pred U_DC_PRED(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( start                         ),
    .x                              ( x                             ),
    .y                              ( y                             ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( dc_pred                       ),
    .done                           (                               )
);

wire [8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] ve_pred;
Vertical_Pred U_VERTICAL_PRED(
    .top                            ( top                           ),
    .dst                            ( ve_pred                       )
);

wire [8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] he_pred;
Horizontal_Pred U_HORIZONTAL_PRED(
    .left                           ( left                          ),
    .dst                            ( he_pred                       )
);

wire [8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] tm_pred;
True_Motion_Pred U_TRUE_MOTION_PRED(
    .top_left                       ( top_left                      ),
    .top                            ( top                           ),
    .left                           ( left                          ),
    .dst                            ( tm_pred                       )
);

endmodule
