   
    parameter PROC_NUM = 15;
    parameter ST_IDLE = 3'b000;
    parameter ST_FILTER_FAKE = 3'b001;
    parameter ST_DL_DETECTED = 3'b010;
    parameter ST_DL_REPORT = 3'b100;
   

    reg [2:0] CS_fsm;
    reg [2:0] NS_fsm;
    reg [PROC_NUM - 1:0] dl_detect_reg;
    reg [PROC_NUM - 1:0] dl_done_reg;
    reg [PROC_NUM - 1:0] origin_reg;
    reg [PROC_NUM - 1:0] dl_in_vec_reg;
    reg [31:0] dl_keep_cnt;
    integer i;
    integer fp;

    // FSM State machine
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            CS_fsm <= ST_IDLE;
        end
        else begin
            CS_fsm <= NS_fsm;
        end
    end
    always @ (CS_fsm or dl_in_vec or dl_detect_reg or dl_done_reg or dl_in_vec or origin_reg or dl_keep_cnt) begin
        case (CS_fsm)
            ST_IDLE : begin
                if (|dl_in_vec) begin
                    NS_fsm = ST_FILTER_FAKE;
                end
                else begin
                    NS_fsm = ST_IDLE;
                end
            end
            ST_FILTER_FAKE: begin
                if (dl_keep_cnt >= 32'd1000) begin
                    NS_fsm = ST_DL_DETECTED;
                end
                else if (dl_detect_reg != (dl_detect_reg & dl_in_vec)) begin
                    NS_fsm = ST_IDLE;
                end
                else begin
                    NS_fsm = ST_FILTER_FAKE;
                end
            end
            ST_DL_DETECTED: begin
                // has unreported deadlock cycle
                if (dl_detect_reg != dl_done_reg) begin
                    NS_fsm = ST_DL_REPORT;
                end
                else begin
                    NS_fsm = ST_DL_DETECTED;
                end
            end
            ST_DL_REPORT: begin
                if (|(dl_in_vec & origin_reg)) begin
                    NS_fsm = ST_DL_DETECTED;
                end
                else begin
                    NS_fsm = ST_DL_REPORT;
                end
            end
            default: NS_fsm = ST_IDLE;
        endcase
    end

    // dl_detect_reg record the procs that first detect deadlock
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_detect_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_IDLE) begin
                dl_detect_reg <= dl_in_vec;
            end
        end
    end

    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_keep_cnt <= 32'h0;
        end
        else begin
            if (CS_fsm == ST_FILTER_FAKE && (dl_detect_reg == (dl_detect_reg & dl_in_vec))) begin
                dl_keep_cnt <= dl_keep_cnt + 32'h1;
            end
            else if (CS_fsm == ST_FILTER_FAKE && (dl_detect_reg != (dl_detect_reg & dl_in_vec))) begin
                dl_keep_cnt <= 32'h0;
            end
        end
    end

    // dl_detect_out keeps in high after deadlock detected
    assign dl_detect_out = (|dl_detect_reg) && (CS_fsm == ST_DL_DETECTED || CS_fsm == ST_DL_REPORT);

    // dl_done_reg record the cycles has been reported
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_done_reg <= 'b0;
        end
        else begin
            if ((CS_fsm == ST_DL_REPORT) && (|(dl_in_vec & dl_detect_reg) == 'b1)) begin
                dl_done_reg <= dl_done_reg | dl_in_vec;
            end
        end
    end

    // clear token once a cycle is done
    assign token_clear = (CS_fsm == ST_DL_REPORT) ? ((|(dl_in_vec & origin_reg)) ? 'b1 : 'b0) : 'b0;

    // origin_reg record the current cycle start id
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            origin_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED) begin
                origin_reg <= origin;
            end
        end
    end
   
    // origin will be valid for only one cycle
    wire [PROC_NUM*PROC_NUM - 1:0] origin_tmp;
    assign origin_tmp[PROC_NUM - 1:0] = (dl_detect_reg[0] & ~dl_done_reg[0]) ? 'b1 : 'b0;
    genvar j;
    generate
    for(j = 1;j < PROC_NUM;j = j + 1) begin: F1
        assign origin_tmp[j*PROC_NUM +: PROC_NUM] = (dl_detect_reg[j] & ~dl_done_reg[j]) ? ('b1 << j) : origin_tmp[(j - 1)*PROC_NUM +: PROC_NUM];
    end
    endgenerate
    always @ (CS_fsm or origin_tmp) begin
        if (CS_fsm == ST_DL_DETECTED) begin
            origin = origin_tmp[(PROC_NUM - 1)*PROC_NUM +: PROC_NUM];
        end
        else begin
            origin = 'b0;
        end
    end

    
    // dl_in_vec_reg record the current cycle dl_in_vec
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            dl_in_vec_reg <= 'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED) begin
                dl_in_vec_reg <= origin;
            end
            else if (CS_fsm == ST_DL_REPORT) begin
                dl_in_vec_reg <= dl_in_vec;
            end
        end
    end
    
    // find_df_deadlock to report the deadlock
    always @ (negedge dl_reset or posedge dl_clock) begin
        if (~dl_reset) begin
            find_df_deadlock <= 1'b0;
        end
        else begin
            if (CS_fsm == ST_DL_DETECTED && dl_detect_reg == dl_done_reg) begin
                find_df_deadlock <= 1'b1;
            end
            else if (CS_fsm == ST_IDLE) begin
                find_df_deadlock <= 1'b0;
            end
        end
    end
    
    // get the first valid proc index in dl vector
    function integer proc_index(input [PROC_NUM - 1:0] dl_vec);
        begin
            proc_index = 0;
            for (i = 0; i < PROC_NUM; i = i + 1) begin
                if (dl_vec[i]) begin
                    proc_index = i;
                end
            end
        end
    endfunction

    // get the proc path based on dl vector
    function [768:0] proc_path(input [PROC_NUM - 1:0] dl_vec);
        integer index;
        begin
            index = proc_index(dl_vec);
            case (index)
                0 : begin
                    proc_path = "myproject_myproject.zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0";
                end
                1 : begin
                    proc_path = "myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0";
                end
                2 : begin
                    proc_path = "myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0";
                end
                3 : begin
                    proc_path = "myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0";
                end
                4 : begin
                    proc_path = "myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0";
                end
                5 : begin
                    proc_path = "myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0";
                end
                6 : begin
                    proc_path = "myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0";
                end
                7 : begin
                    proc_path = "myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0";
                end
                8 : begin
                    proc_path = "myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0";
                end
                9 : begin
                    proc_path = "myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0";
                end
                10 : begin
                    proc_path = "myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0";
                end
                11 : begin
                    proc_path = "myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0";
                end
                12 : begin
                    proc_path = "myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0";
                end
                13 : begin
                    proc_path = "myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0";
                end
                14 : begin
                    proc_path = "myproject_myproject.sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0";
                end
                default : begin
                    proc_path = "unknown";
                end
            endcase
        end
    endfunction

    // print the headlines of deadlock detection
    task print_dl_head;
        begin
            $display("\n//////////////////////////////////////////////////////////////////////////////");
            $display("// ERROR!!! DEADLOCK DETECTED at %0t ns! SIMULATION WILL BE STOPPED! //", $time);
            $display("//////////////////////////////////////////////////////////////////////////////");
            fp = $fopen("deadlock_db.dat", "w");
        end
    endtask

    // print the start of a cycle
    task print_cycle_start(input reg [768:0] proc_path, input integer cycle_id);
        begin
            $display("/////////////////////////");
            $display("// Dependence cycle %0d:", cycle_id);
            $display("// (1): Process: %0s", proc_path);
            $fdisplay(fp, "Dependence_Cycle_ID %0d", cycle_id);
            $fdisplay(fp, "Dependence_Process_ID 1");
            $fdisplay(fp, "Dependence_Process_path %0s", proc_path);
        end
    endtask

    // print the end of deadlock detection
    task print_dl_end(input integer num, input integer record_time);
        begin
            $display("////////////////////////////////////////////////////////////////////////");
            $display("// Totally %0d cycles detected!", num);
            $display("////////////////////////////////////////////////////////////////////////");
            $display("// ERROR!!! DEADLOCK DETECTED at %0t ns! SIMULATION WILL BE STOPPED! //", record_time);
            $display("//////////////////////////////////////////////////////////////////////////////");
            $fdisplay(fp, "Dependence_Cycle_Number %0d", num);
            $fclose(fp);
        end
    endtask

    // print one proc component in the cycle
    task print_cycle_proc_comp(input reg [768:0] proc_path, input integer cycle_comp_id);
        begin
            $display("// (%0d): Process: %0s", cycle_comp_id, proc_path);
            $fdisplay(fp, "Dependence_Process_ID %0d", cycle_comp_id);
            $fdisplay(fp, "Dependence_Process_path %0s", proc_path);
        end
    endtask

    // print one channel component in the cycle
    task print_cycle_chan_comp(input [PROC_NUM - 1:0] dl_vec1, input [PROC_NUM - 1:0] dl_vec2);
        reg [856:0] chan_path;
        integer index1;
        integer index2;
        begin
            index1 = proc_index(dl_vec1);
            index2 = proc_index(dl_vec2);
            case (index1)
                0 : begin
                    case(index2)
                    1: begin
                        if (~zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0.grp_zeropad2d_cl_array_array_ap_uint_1_1u_config19_Pipeline_PadTopWidth_fu_28.layer19_out_blk_n) begin
                            if (~layer19_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer19_out_U' written by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer19_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer19_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer19_out_U' read by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer19_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U.if_full_n & zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0.ap_start & ~zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0.real_start & (trans_in_cnt_0 == trans_out_cnt_0) & ~start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U' read by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0',");
                        end
                    end
                    endcase
                end
                1 : begin
                    case(index2)
                    0: begin
                        if (~conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0.layer19_out_blk_n) begin
                            if (~layer19_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer19_out_U' written by process 'myproject_myproject.zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer19_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer19_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer19_out_U' read by process 'myproject_myproject.zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer19_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U.if_empty_n & conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0.ap_idle & ~start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0_U' written by process 'myproject_myproject.zeropad2d_cl_array_ap_uint_1_1u_array_ap_uint_1_1u_config19_U0',");
                        end
                    end
                    2: begin
                        if (~conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0.layer2_out_blk_n) begin
                            if (~layer2_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer2_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer2_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer2_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer2_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer2_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                    end
                    endcase
                end
                2 : begin
                    case(index2)
                    1: begin
                        if (~normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0.layer2_out_blk_n) begin
                            if (~layer2_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer2_out_U' written by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer2_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer2_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer2_out_U' read by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer2_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4bdk_U.if_empty_n & normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0.ap_idle & ~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4bdk_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4bdk_U' written by process 'myproject_myproject.conv_2d_cl_array_ap_uint_1u_array_ap_fixed_22_13_5_3_0_12u_config2_U0',");
                        end
                    end
                    3: begin
                        if (~normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0.layer4_out_blk_n) begin
                            if (~layer4_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer4_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer4_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer4_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer4_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer4_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U.if_full_n & normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0.ap_start & ~normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0.real_start & (trans_in_cnt_2 == trans_out_cnt_2) & ~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0',");
                        end
                    end
                    endcase
                end
                3 : begin
                    case(index2)
                    2: begin
                        if (~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0.layer4_out_blk_n) begin
                            if (~layer4_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer4_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer4_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer4_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer4_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer4_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U.if_empty_n & relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0.ap_idle & ~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5bek_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_39_20_5_3_0_12u_config4_U0',");
                        end
                    end
                    4: begin
                        if (~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0.layer5_out_blk_n) begin
                            if (~layer5_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer5_out_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer5_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer5_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer5_out_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer5_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U.if_full_n & relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0.ap_start & ~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0.real_start & (trans_in_cnt_3 == trans_out_cnt_3) & ~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0',");
                        end
                    end
                    endcase
                end
                4 : begin
                    case(index2)
                    3: begin
                        if (~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0.layer5_out_blk_n) begin
                            if (~layer5_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer5_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer5_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer5_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer5_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer5_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U.if_empty_n & pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0.ap_idle & ~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config5_U0',");
                        end
                    end
                    5: begin
                        if (~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0.layer6_out_blk_n) begin
                            if (~layer6_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer6_out_U' written by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer6_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer6_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer6_out_U' read by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer6_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U.if_full_n & pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0.ap_start & ~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0.real_start & (trans_in_cnt_4 == trans_out_cnt_4) & ~start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U' read by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0',");
                        end
                    end
                    endcase
                end
                5 : begin
                    case(index2)
                    4: begin
                        if (~zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0.grp_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_Pipeline_PadMain_fu_28.layer6_out_blk_n) begin
                            if (~layer6_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer6_out_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer6_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer6_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer6_out_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer6_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U.if_empty_n & zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0.ap_idle & ~start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config6_U0',");
                        end
                    end
                    6: begin
                        if (~zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0.grp_zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_Pipeline_PadMain_fu_28.layer20_out_blk_n) begin
                            if (~layer20_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer20_out_U' written by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer20_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer20_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer20_out_U' read by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer20_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U.if_full_n & zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0.ap_start & ~zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0.real_start & (trans_in_cnt_5 == trans_out_cnt_5) & ~start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U' read by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0',");
                        end
                    end
                    endcase
                end
                6 : begin
                    case(index2)
                    5: begin
                        if (~conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0.layer20_out_blk_n) begin
                            if (~layer20_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer20_out_U' written by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer20_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer20_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer20_out_U' read by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer20_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U.if_empty_n & conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0.ap_idle & ~start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0_U' written by process 'myproject_myproject.zeropad2d_cl_array_array_ap_ufixed_16_6_4_0_0_12u_config20_U0',");
                        end
                    end
                    7: begin
                        if (~conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0.layer7_out_blk_n) begin
                            if (~layer7_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer7_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer7_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer7_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer7_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer7_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                    end
                    endcase
                end
                7 : begin
                    case(index2)
                    6: begin
                        if (~normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0.layer7_out_blk_n) begin
                            if (~layer7_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer7_out_U' written by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer7_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer7_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer7_out_U' read by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer7_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9bfk_U.if_empty_n & normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0.ap_idle & ~start_for_normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9bfk_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9bfk_U' written by process 'myproject_myproject.conv_2d_cl_array_array_ap_fixed_40_21_5_3_0_24u_config7_U0',");
                        end
                    end
                    8: begin
                        if (~normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0.layer9_out_blk_n) begin
                            if (~layer9_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer9_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer9_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer9_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer9_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer9_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U.if_full_n & normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0.ap_start & ~normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0.real_start & (trans_in_cnt_7 == trans_out_cnt_7) & ~start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U' read by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0',");
                        end
                    end
                    endcase
                end
                8 : begin
                    case(index2)
                    7: begin
                        if (~relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0.layer9_out_blk_n) begin
                            if (~layer9_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer9_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer9_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer9_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer9_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer9_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U.if_empty_n & relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0.ap_idle & ~start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config1bgk_U' written by process 'myproject_myproject.normalize_array_ap_fixed_24u_array_ap_fixed_57_28_5_3_0_24u_config9_U0',");
                        end
                    end
                    9: begin
                        if (~relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0.layer10_out_blk_n) begin
                            if (~layer10_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer10_out_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer10_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer10_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer10_out_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer10_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U.if_full_n & relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0.ap_start & ~relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0.real_start & (trans_in_cnt_8 == trans_out_cnt_8) & ~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0',");
                        end
                    end
                    endcase
                end
                9 : begin
                    case(index2)
                    8: begin
                        if (~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0.layer10_out_blk_n) begin
                            if (~layer10_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer10_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer10_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer10_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer10_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer10_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U.if_empty_n & pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0.ap_idle & ~start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0_U' written by process 'myproject_myproject.relu_array_ap_fixed_24u_array_ap_ufixed_16_6_4_0_0_24u_relu_config10_U0',");
                        end
                    end
                    10: begin
                        if (~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0.layer11_out_blk_n) begin
                            if (~layer11_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer11_out_U' written by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer11_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer11_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer11_out_U' read by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer11_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U.if_full_n & pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0.ap_start & ~pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0.real_start & (trans_in_cnt_9 == trans_out_cnt_9) & ~start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U' read by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0',");
                        end
                    end
                    endcase
                end
                10 : begin
                    case(index2)
                    9: begin
                        if (~dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0.grp_dense_array_array_ap_fixed_16_6_5_3_0_12u_config13_Pipeline_DataPrepare_fu_5219.layer11_out_blk_n) begin
                            if (~layer11_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer11_out_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer11_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer11_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer11_out_U' read by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer11_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U.if_empty_n & dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0.ap_idle & ~start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0_U' written by process 'myproject_myproject.pooling2d_cl_array_array_ap_ufixed_16_6_4_0_0_24u_config11_U0',");
                        end
                    end
                    11: begin
                        if (~dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0.layer13_out_blk_n) begin
                            if (~layer13_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer13_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer13_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer13_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer13_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer13_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U.if_full_n & dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0.ap_start & ~dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0.real_start & (trans_in_cnt_10 == trans_out_cnt_10) & ~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U' read by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0',");
                        end
                    end
                    endcase
                end
                11 : begin
                    case(index2)
                    10: begin
                        if (~normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0.layer13_out_blk_n) begin
                            if (~layer13_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer13_out_U' written by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer13_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer13_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer13_out_U' read by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer13_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U.if_empty_n & normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0.ap_idle & ~start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config1bhl_U' written by process 'myproject_myproject.dense_array_ap_ufixed_24u_array_ap_fixed_16_6_5_3_0_12u_config13_U0',");
                        end
                    end
                    12: begin
                        if (~normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0.layer15_out_blk_n) begin
                            if (~layer15_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer15_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer15_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer15_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer15_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer15_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U.if_full_n & normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0.ap_start & ~normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0.real_start & (trans_in_cnt_11 == trans_out_cnt_11) & ~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0',");
                        end
                    end
                    endcase
                end
                12 : begin
                    case(index2)
                    11: begin
                        if (~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0.layer15_out_blk_n) begin
                            if (~layer15_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer15_out_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer15_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer15_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer15_out_U' read by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer15_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U.if_empty_n & relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0.ap_idle & ~start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config1bil_U' written by process 'myproject_myproject.normalize_array_ap_fixed_12u_array_ap_fixed_33_13_5_3_0_12u_config15_U0',");
                        end
                    end
                    13: begin
                        if (~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0.layer16_out_blk_n) begin
                            if (~layer16_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer16_out_U' written by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer16_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer16_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer16_out_U' read by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer16_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U.if_full_n & relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0.ap_start & ~relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0.real_start & (trans_in_cnt_12 == trans_out_cnt_12) & ~start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U' read by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0',");
                        end
                    end
                    endcase
                end
                13 : begin
                    case(index2)
                    12: begin
                        if (~dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0.layer16_out_blk_n) begin
                            if (~layer16_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer16_out_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer16_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer16_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer16_out_U' read by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer16_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U.if_empty_n & dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0.ap_idle & ~start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0_U' written by process 'myproject_myproject.relu_array_ap_fixed_12u_array_ap_ufixed_16_6_4_0_0_12u_relu_config16_U0',");
                        end
                    end
                    14: begin
                        if (~dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0.layer17_out_blk_n) begin
                            if (~layer17_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer17_out_U' written by process 'myproject_myproject.sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer17_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer17_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer17_out_U' read by process 'myproject_myproject.sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer17_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U.if_full_n & dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0.ap_start & ~dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0.real_start & (trans_in_cnt_13 == trans_out_cnt_13) & ~start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U.if_read) begin
                            $display("//      Blocked by full output start propagation FIFO 'myproject_myproject.start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U' read by process 'myproject_myproject.sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0',");
                        end
                    end
                    endcase
                end
                14 : begin
                    case(index2)
                    13: begin
                        if (~sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0.layer17_out_blk_n) begin
                            if (~layer17_out_U.if_empty_n) begin
                                $display("//      Blocked by empty input FIFO 'myproject_myproject.layer17_out_U' written by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer17_out_U");
                                $fdisplay(fp, "Dependence_Channel_status EMPTY");
                            end
                            else if (~layer17_out_U.if_full_n) begin
                                $display("//      Blocked by full output FIFO 'myproject_myproject.layer17_out_U' read by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0'");
                                $fdisplay(fp, "Dependence_Channel_path myproject_myproject.layer17_out_U");
                                $fdisplay(fp, "Dependence_Channel_status FULL");
                            end
                        end
                        if (~start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U.if_empty_n & sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0.ap_idle & ~start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U.if_write) begin
                            $display("//      Blocked by missing 'ap_start' from start propagation FIFO 'myproject_myproject.start_for_sigmoid_array_array_ap_fixed_16_6_5_3_0_1u_sigmoid_config18_U0_U' written by process 'myproject_myproject.dense_array_ap_ufixed_12u_array_ap_fixed_37_18_5_3_0_1u_config17_U0',");
                        end
                    end
                    endcase
                end
            endcase
        end
    endtask

    // report
    initial begin : report_deadlock
        integer cycle_id;
        integer cycle_comp_id;
        integer record_time;
        wait (dl_reset == 1);
        cycle_id = 1;
        record_time = 0;
        while (1) begin
            @ (negedge dl_clock);
            case (CS_fsm)
                ST_DL_DETECTED: begin
                    cycle_comp_id = 2;
                    if (dl_detect_reg != dl_done_reg) begin
                        if (dl_done_reg == 'b0) begin
                            print_dl_head;
                            record_time = $time;
                        end
                        print_cycle_start(proc_path(origin), cycle_id);
                        cycle_id = cycle_id + 1;
                    end
                    else begin
                        print_dl_end((cycle_id - 1),record_time);
                        @(negedge dl_clock);
                        @(negedge dl_clock);
                        $finish;
                    end
                end
                ST_DL_REPORT: begin
                    if ((|(dl_in_vec)) & ~(|(dl_in_vec & origin_reg))) begin
                        print_cycle_chan_comp(dl_in_vec_reg, dl_in_vec);
                        print_cycle_proc_comp(proc_path(dl_in_vec), cycle_comp_id);
                        cycle_comp_id = cycle_comp_id + 1;
                    end
                    else begin
                        print_cycle_chan_comp(dl_in_vec_reg, dl_in_vec);
                    end
                end
            endcase
        end
    end
 
