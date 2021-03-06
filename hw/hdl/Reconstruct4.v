//-------------------------------------------------------------------
// CopyRight(c) 2019 zhaoxingchang All Rights Reserved
//-------------------------------------------------------------------
// ProjectName    : 
// Author         : zhaoxingchang
// E-mail         : zxctja@163.com
// FileName       :	Reconstruct4.v
// ModelName      : 
// Description    : 
//-------------------------------------------------------------------
// Create         : 2019-11-17 13:30
// LastModified   :	2019-11-22 11:37
// Version        : 1.0
//-------------------------------------------------------------------

`timescale 1ns/100ps

module Reconstruct4#(
 parameter BLOCK_SIZE   = 4
)(
 input                                             clk
,input                                             rst_n
,input                                             start
,input      [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] YPred
,input      [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Ysrc
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] q
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] iq
,input      [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] bias
,input      [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] zthresh
,input      [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] sharpen
,output     [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] Yout
,output     [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] YLevels
,output                                            nz
,output                                            done
);

reg [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] q1;
reg [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] iq1;
reg [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] bias1;
reg [32 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] zthresh1;
reg [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] sharpen1;
reg [ 8 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0] YPred1;

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        q1       <= 'b0;
        iq1      <= 'b0;
        bias1    <= 'b0;
        zthresh1 <= 'b0;
        sharpen1 <= 'b0;
        YPred1   <= 'b0;
    end
    else begin
        q1       <= q;
        iq1      <= iq;
        bias1    <= bias;
        zthresh1 <= zthresh;
        sharpen1 <= sharpen;
        YPred1   <= YPred;
    end
end

wire [12 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]FDCT_out;
wire FDCT_done;
FTransform U_FDCT(
     .clk                           (clk                            )
    ,.rst_n                         (rst_n                          )
    ,.start                         (start                          )
    ,.src                           (Ysrc                           )
    ,.ref                           (YPred                          )
    ,.out                           (FDCT_out                       )
    ,.done                          (FDCT_done                      )
    );

wire QB_done;
wire [16 * BLOCK_SIZE * BLOCK_SIZE - 1 : 0]QB_Rout;
QuantizeBlock #(
    .BLOCK_SIZE                     ( 4                             ),
    .IW                             ( 12                            ))
U_QB(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( FDCT_done                     ),
    .in                             ( FDCT_out                      ),
    .q                              ( q1                            ),
    .iq                             ( iq1                           ),
    .bias                           ( bias1                         ),
    .zthresh                        ( zthresh1                      ),
    .sharpen                        ( sharpen1                      ),
    .Rout                           ( QB_Rout                       ),
    .out                            ( YLevels                       ),
    .nz                             ( nz                            ),
    .done                           ( QB_done                       )
);

ITransform U_IDCT(
    .clk                            ( clk                           ),
    .rst_n                          ( rst_n                         ),
    .start                          ( QB_done                       ),
    .src                            ( QB_Rout                       ),
    .ref                            ( YPred1                        ),
    .out                            ( Yout                          ),
    .done                           ( done                          )
);

endmodule
