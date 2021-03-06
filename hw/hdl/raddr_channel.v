//-------------------------------------------------------------------
// CopyRight(c) 2019 zhaoxingchang All Rights Reserved
//-------------------------------------------------------------------
// ProjectName    : 
// Author         : zhaoxingchang
// E-mail         : zxctja@163.com
// FileName       : raddr_channel.v
// ModelName      : 
// Description    : 
//-------------------------------------------------------------------
// Create         : 2019-12-16 15:41
// LastModified   : 2019-12-16 15:41
// Version        : 1.0
//-------------------------------------------------------------------

`timescale 1ns/100ps

module raddr_channel
                      (
                       input                           clk                ,
                       input                           rst_n              , 
                                                        
                       //---- AXI bus ----               
                         // AXI read address channel       
                       output wire [063:0]             m_axi_araddr       ,  
                       output wire [007:0]             m_axi_arlen        ,  
                       output wire                     m_axi_arvalid      ,
                       input                           m_axi_arready      ,

                       //---- local control ----
                       input                           start_pulse        ,
                       input      [063:0]              source_address     ,
                       input      [0009:0]             w1                 ,
                       input      [0009:0]             h1                 
                       );

 reg [ 9:0]x;
 reg [ 9:0]y;
 reg [63:0]address;
 reg [ 7:0]length;
 reg [ 3:0]cstate;
 reg [ 3:0]nstate;

parameter IDLE = 'h1;
parameter DQM  = 'h2; 
parameter ADDR = 'h4; 
parameter SEND = 'h8;

 assign m_axi_araddr   = address;
 assign m_axi_arlen    = length;
 assign m_axi_arvalid  = (cstate == SEND);

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)
        cstate <= IDLE;
    else
        cstate <= nstate;
end

always @ * begin
    case(cstate)
        IDLE:
            if(start_pulse)
                nstate = SEND;
            else
                nstate = IDLE;
        SEND:
            if(m_axi_arready)
                nstate = ADDR;
            else
                nstate = SEND;
        ADDR:
            if(y > h1)
                nstate = IDLE;
            else
                nstate = SEND;
        default:
            nstate = IDLE;
    endcase
end

always @ (posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        address <= 'b0;
        length  <= 'b0;
        x       <= 'b0;
        y       <= 'b0;
    end
    else begin
        case(cstate)
            IDLE:begin
                x       <= 'b0;
                y       <= 'b0;
                address <= source_address;
                length  <= 'b0;
            end
            SEND:begin
                ;
            end
            ADDR:begin
                address <= (x == 10'b0 && y == 10'b0) ? 
                           (source_address + 'd128) : (address + 'd384);
                length  <= 'd2;
                x       <= (x >= w1) ? 10'b0 : (x + 1'b1);
                y       <= (x >= w1) ? (y + 1'b1) : y;
            end
        endcase
    end
end

endmodule
