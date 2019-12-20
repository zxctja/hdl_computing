//-------------------------------------------------------------------
// CopyRight(c) 2019 zhaoxingchang All Rights Reserved
//-------------------------------------------------------------------
// ProjectName    : 
// Author         : zhaoxingchang
// E-mail         : zxctja@163.com
// FileName       : rdata_channel.v
// ModelName      : 
// Description    : 
//-------------------------------------------------------------------
// Create         : 2019-12-16 15:52
// LastModified   : 2019-12-16 15:52
// Version        : 1.0
//-------------------------------------------------------------------

`timescale 1ns/100ps

module rdata_channel #(
                       parameter ID_WIDTH      = 2
                       )
                      (
                       input                           clk               ,
                       input                           rst_n             , 
                                                        
                       //---- AXI bus ----               
                         // AXI read address channel       
                       input      [1023:0]             m_axi_rdata       ,  
                       input [ID_WIDTH-1:0]            m_axi_rid         ,  
                       input                           m_axi_rlast       , 
                       input                           m_axi_rvalid      ,
                       input      [0001:0]             m_axi_rresp       ,
                       output wire                     m_axi_rready      , 

                       //---- local control ----
                       input                           start_pulse       ,
                       output reg                      rd_error          ,

                       output reg [1023:0]             Y0_fifo_din       ,
                       output reg [1023:0]             Y1_fifo_din       ,
                       output     [1023:0]             UV_fifo_din       ,
                       input                           Y0_fifo_full      ,
                       input                           Y1_fifo_full      ,
                       input                           UV_fifo_full      ,
                       output                          Y0_fifo_wr        ,
                       output                          Y1_fifo_wr        ,
                       output                          UV_fifo_wr        
                       );

 wire      data_receive;
 wire      fifo_wr;
 reg [ 3:0]count;

 assign m_axi_rready   = ~Y0_fifo_full | count != 'd0;
 assign data_receive   = m_axi_rvalid && m_axi_rready;
 assign fifo_wr        = m_axi_rvalid && m_axi_rready && m_axi_rlast;
 assign Y0_fifo_wr     = fifo_wr;
 assign Y1_fifo_wr     = fifo_wr;
 assign UV_fifo_wr     = fifo_wr;
 assign UV_fifo_din    = m_axi_rdata;

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        count <= 'b0;
    end
    else begin
        if(start_pulse)
            count <= 'b0;
        else if(data_receive)
            if(count >= 'd2)
                count <= 'b0;
            else
                count <= count + 1'b1;
    end
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        Y0_fifo_din   <= 'b0;
        Y1_fifo_din   <= 'b0;
    end
    else begin
        if(data_receive)begin
            case(count)
                'd0:begin
                    Y0_fifo_din         <= m_axi_rdata;
                end
                'd1:begin
                    Y1_fifo_din         <= m_axi_rdata;
                end
                'd2:begin
                    ;
                end
                default:;
            endcase
        end
    end
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        rd_error <= 'b0;
    end
    else begin
        if(data_receive)
            if(m_axi_rresp != 'b0)
                rd_error <= 1'b1;
            else
                rd_error <= 1'b0;
    end
end

endmodule
