`timescale 1ns / 1ps

module tb_myproject;

    reg ap_clk;
    reg ap_rst_n;

    reg ap_start;
    wire ap_done;
    wire ap_idle;
    wire ap_ready;

    wire [7:0] input_layer_TDATA;
    reg input_layer_TVALID;
    wire input_layer_TREADY;

    wire [15:0] layer18_out_TDATA;
    wire layer18_out_TVALID;
    reg layer18_out_TREADY;


    localparam REAL_EVENTS     = 100;
    localparam BYTES_PER_EVENT = 864;
    localparam TOTAL_BYTES     = BYTES_PER_EVENT * REAL_EVENTS;

    reg [7:0] test_vectors [0:TOTAL_BYTES-1];

    reg [9:0] byte_counter;
    reg [6:0] event_counter;
    reg [6:0] out_event_counter;

    integer out_file;

    initial begin
        ap_clk = 0;
        forever #2.5 ap_clk = ~ap_clk;
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

    assign input_layer_TDATA = (input_layer_TVALID && (event_counter < REAL_EVENTS)) ? test_vectors[(event_counter * BYTES_PER_EVENT) + byte_counter] : 8'h00;

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            ap_start <= 1'b0;
        end else begin
            ap_start <= 1'b1;
        end
    end


    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            input_layer_TVALID <= 1'b0;
            byte_counter       <= 10'd0;
            event_counter      <= 7'd0;
        end else begin

            if (out_event_counter < REAL_EVENTS) begin
                input_layer_TVALID <= 1'b1;
                if (input_layer_TVALID && input_layer_TREADY) begin
                    if (byte_counter == BYTES_PER_EVENT - 1) begin
                        byte_counter  <= 10'd0;
                        event_counter <= event_counter + 1'b1;
                    end else begin
                        byte_counter  <= byte_counter + 1'b1;
                    end
                end
            end else begin
                input_layer_TVALID <= 1'b0;
            end
        end
    end

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            layer18_out_TREADY <= 1'b0;
        end else begin
            layer18_out_TREADY <= 1'b1;
        end
    end

    always @(posedge ap_clk or negedge ap_rst_n) begin
        if (!ap_rst_n) begin
            out_event_counter <= 7'd0;
        end else begin
            if (layer18_out_TVALID && layer18_out_TREADY) begin
                $fdisplay(out_file, "%h", layer18_out_TDATA);
                $display("Hardware Output Hex: %h @ time %t (Event %0d)", layer18_out_TDATA, $time, out_event_counter);
                
                if (out_event_counter == REAL_EVENTS - 1) begin
                    $fflush(out_file);
                    $fclose(out_file);
                    $finish;
                end else begin
                    out_event_counter <= out_event_counter + 1'b1;
                end
            end
        end
    end

    initial begin
        ap_rst_n = 1'b0;
        $readmemh("/data/nahom338/dataset_individual_files/tb_input_8bit_TDATA_bit_reversed.dat", test_vectors);
        out_file = $fopen("rtl_output.dat", "w");

        #100;
        ap_rst_n = 1'b1;
    end

endmodule