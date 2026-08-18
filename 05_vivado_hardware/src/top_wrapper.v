`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KEK
// Engineer: Nahom W.
// 
// Create Date: 08/05/2026 02:16:19 PM
// Design Name: 
// Module Name: top_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module top_wrapper (
    input wire CLKGTH_GC_P,
    input wire CLKGTH_GC_N,
    output wire CLK127M_EXIN_SEL,
    output wire GTY_CLK_SEL,
    output wire GTH_CLK_SEL,

    output wire PLL_GTY_SEL0,
    output wire PLL_GTY_SEL1,
    output wire PLL_GTH_SEL0,
    output wire PLL_GTH_SEL1
);
    wire CLKGTH_GC;

    assign GTH_CLK_SEL      = 1'b1;
    assign CLK127M_EXIN_SEL = 1'b1;
    assign PLL_GTY_SEL0     = 1'b1;
    assign PLL_GTY_SEL1     = 1'b0;
    assign PLL_GTH_SEL0     = 1'b1;
    assign PLL_GTH_SEL1     = 1'b0;

    wire ap_clk;
    IBUFGDS #(.DIFF_TERM (0), .IBUF_LOW_PWR (1))
    CLKGTH_TBUFGDS (.I (CLKGTH_GC_P), .IB (CLKGTH_GC_N), .O (CLKGTH_GC));

    BUFG bufg0 (.I (CLKGTH_GC), .O (ap_clk));

    wire ap_rst_n;
    wire ap_start;
    wire ap_done;
    wire ap_idle;
    wire ap_ready;

    wire [7:0] input_layer_TDATA;
    reg        input_layer_TVALID;
    wire       input_layer_TREADY;

    wire [15:0] layer18_out_TDATA;
    wire        layer18_out_TVALID;
    wire        layer18_out_TREADY;

    localparam REAL_EVENTS     = 1000;
    localparam BYTES_PER_EVENT = 864;
    localparam TOTAL_BYTES     = BYTES_PER_EVENT * REAL_EVENTS; 

    (* ram_style = "block" *) reg [7:0] test_vectors [0:TOTAL_BYTES-1];

    reg [9:0] byte_counter;
    reg [9:0] event_counter;
    reg       sending_active;

    initial begin
        $readmemh("tb_input_8bit_TDATA_bit_reversed_1000.dat", test_vectors);
    end

    vio_0 vio_inst (
        .clk(ap_clk),
        .probe_out0(ap_rst_n), 
        .probe_out1(ap_start)  
    );

    assign input_layer_TDATA = (input_layer_TVALID && (event_counter < REAL_EVENTS)) ? 
                                test_vectors[(event_counter * BYTES_PER_EVENT) + byte_counter] : 8'h00;

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            input_layer_TVALID <= 1'b0;
            byte_counter        <= 10'd0;
            event_counter       <= 10'd0; 
            sending_active      <= 1'b0;
        end else begin
            if (sending_active) begin
                if (input_layer_TVALID && input_layer_TREADY) begin
                    if (byte_counter == BYTES_PER_EVENT - 1) begin
                        byte_counter <= 10'd0;
                        
                        if (event_counter == REAL_EVENTS - 1) begin
                            event_counter       <= 10'd0;
                            sending_active      <= 1'b0;
                            input_layer_TVALID <= 1'b0;
                        end else begin
                            event_counter <= event_counter + 1'b1;
                        end
                    end else begin
                        byte_counter <= byte_counter + 1'b1;
                    end
                end
            end else if (ap_start) begin
                sending_active      <= 1'b1;
                input_layer_TVALID <= 1'b1;
                byte_counter        <= 10'd0;
                event_counter       <= 10'd0;
            end
        end
    end

    myproject_0 uut (
        .ap_clk(ap_clk),
        .ap_rst_n(ap_rst_n),
        .ap_start(ap_start),
        .ap_done(ap_done),
        .ap_idle(ap_idle),
        .ap_ready(ap_ready),

        .input_layer_TDATA(input_layer_TDATA),
        .input_layer_TVALID(input_layer_TVALID),
        .input_layer_TREADY(input_layer_TREADY),

        .layer18_out_TDATA(layer18_out_TDATA),
        .layer18_out_TVALID(layer18_out_TVALID),
        .layer18_out_TREADY(layer18_out_TREADY)
    );

    ila_0 ila_inst (
        .clk(ap_clk),
        .probe0({
            byte_counter,       
            event_counter,      
            sending_active,     
            input_layer_TDATA,  
            input_layer_TVALID, 
            input_layer_TREADY, 
            layer18_out_TDATA,  
            layer18_out_TVALID, 
            layer18_out_TREADY, 
            ap_start,           
            ap_done,            
            ap_ready,           
            ap_idle             
        }) 
    );

    assign layer18_out_TREADY = 1'b1;

endmodule