#include <iostream>

#include "myproject.h"
#include "parameters.h"


void myproject(
    hls::stream<input_t> &input_layer,
    hls::stream<result_t> &layer18_out
) {

    // hls-fpga-machine-learning insert IO
    #pragma HLS INTERFACE axis port=input_layer,layer18_out 
    #pragma HLS DATAFLOW

    // hls-fpga-machine-learning insert load weights
#ifndef __SYNTHESIS__
    static bool loaded_weights = false;
    if (!loaded_weights) {
        nnet::load_weights_from_txt<weight2_t, 108>(w2, "w2.txt");
        nnet::load_weights_from_txt<bias2_t, 12>(b2, "b2.txt");
        nnet::load_weights_from_txt<batch_normalization_scale_t, 12>(s4, "s4.txt");
        nnet::load_weights_from_txt<batch_normalization_bias_t, 12>(b4, "b4.txt");
        nnet::load_weights_from_txt<weight7_t, 2592>(w7, "w7.txt");
        nnet::load_weights_from_txt<bias7_t, 24>(b7, "b7.txt");
        nnet::load_weights_from_txt<batch_normalization_1_scale_t, 24>(s9, "s9.txt");
        nnet::load_weights_from_txt<batch_normalization_1_bias_t, 24>(b9, "b9.txt");
        nnet::load_weights_from_txt<weight13_t, 15552>(w13, "w13.txt");
        nnet::load_weights_from_txt<bias13_t, 12>(b13, "b13.txt");
        nnet::load_weights_from_txt<batch_normalization_2_scale_t, 12>(s15, "s15.txt");
        nnet::load_weights_from_txt<batch_normalization_2_bias_t, 12>(b15, "b15.txt");
        nnet::load_weights_from_txt<weight17_t, 12>(w17, "w17.txt");
        nnet::load_weights_from_txt<bias17_t, 1>(b17, "b17.txt");
        loaded_weights = true;    }
#endif
    // ****************************************
    // NETWORK INSTANTIATION
    // ****************************************

    // hls-fpga-machine-learning insert layers

    hls::stream<layer19_t> layer19_out("layer19_out");
    #pragma HLS STREAM variable=layer19_out depth=988

    hls::stream<qconv_1_result_t> layer2_out("layer2_out");
    #pragma HLS STREAM variable=layer2_out depth=864

    hls::stream<batch_normalization_result_t> layer4_out("layer4_out");
    #pragma HLS STREAM variable=layer4_out depth=864

    hls::stream<layer5_t> layer5_out("layer5_out");
    #pragma HLS STREAM variable=layer5_out depth=864

    hls::stream<layer6_t> layer6_out("layer6_out");
    #pragma HLS STREAM variable=layer6_out depth=216

    hls::stream<layer20_t> layer20_out("layer20_out");
    #pragma HLS STREAM variable=layer20_out depth=280

    hls::stream<qconv_2_result_t> layer7_out("layer7_out");
    #pragma HLS STREAM variable=layer7_out depth=216

    hls::stream<batch_normalization_1_result_t> layer9_out("layer9_out");
    #pragma HLS STREAM variable=layer9_out depth=216

    hls::stream<layer10_t> layer10_out("layer10_out");
    #pragma HLS STREAM variable=layer10_out depth=216

    hls::stream<layer11_t> layer11_out("layer11_out");
    #pragma HLS STREAM variable=layer11_out depth=54

    auto& layer12_out = layer11_out;
    hls::stream<layer13_t> layer13_out("layer13_out");
    #pragma HLS STREAM variable=layer13_out depth=1

    hls::stream<batch_normalization_2_result_t> layer15_out("layer15_out");
    #pragma HLS STREAM variable=layer15_out depth=1

    hls::stream<layer16_t> layer16_out("layer16_out");
    #pragma HLS STREAM variable=layer16_out depth=1

    hls::stream<qoutput_result_t> layer17_out("layer17_out");
    #pragma HLS STREAM variable=layer17_out depth=1

    nnet::zeropad2d_cl<input_t, layer19_t, config19>(input_layer, layer19_out); // zp2d_qconv_1

    nnet::conv_2d_cl<layer19_t, qconv_1_result_t, config2>(layer19_out, layer2_out, w2, b2); // qconv_1

    nnet::normalize<qconv_1_result_t, batch_normalization_result_t, config4>(layer2_out, layer4_out, s4, b4); // batch_normalization

    nnet::relu<batch_normalization_result_t, layer5_t, relu_config5>(layer4_out, layer5_out); // qact_1

    nnet::pooling2d_cl<layer5_t, layer6_t, config6>(layer5_out, layer6_out); // max_pooling2d

    nnet::zeropad2d_cl<layer6_t, layer20_t, config20>(layer6_out, layer20_out); // zp2d_qconv_2

    nnet::conv_2d_cl<layer20_t, qconv_2_result_t, config7>(layer20_out, layer7_out, w7, b7); // qconv_2

    nnet::normalize<qconv_2_result_t, batch_normalization_1_result_t, config9>(layer7_out, layer9_out, s9, b9); // batch_normalization_1

    nnet::relu<batch_normalization_1_result_t, layer10_t, relu_config10>(layer9_out, layer10_out); // qact_2

    nnet::pooling2d_cl<layer10_t, layer11_t, config11>(layer10_out, layer11_out); // max_pooling2d_1

    nnet::dense<layer11_t, layer13_t, config13>(layer12_out, layer13_out, w13, b13); // qdense_1

    nnet::normalize<layer13_t, batch_normalization_2_result_t, config15>(layer13_out, layer15_out, s15, b15); // batch_normalization_2

    nnet::relu<batch_normalization_2_result_t, layer16_t, relu_config16>(layer15_out, layer16_out); // qact_3

    nnet::dense<layer16_t, qoutput_result_t, config17>(layer16_out, layer17_out, w17, b17); // qoutput

    nnet::sigmoid<qoutput_result_t, result_t, sigmoid_config18>(layer17_out, layer18_out); // qoutput_sigmoid

}

