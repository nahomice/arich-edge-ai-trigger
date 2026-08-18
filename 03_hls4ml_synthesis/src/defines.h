#ifndef DEFINES_H_
#define DEFINES_H_

#include "ap_fixed.h"
#include "ap_int.h"
#include "nnet_utils/nnet_types.h"
#include <array>
#include <cstddef>
#include <cstdio>
#include <tuple>
#include <tuple>


// hls-fpga-machine-learning insert numbers

// hls-fpga-machine-learning insert layer-precision
typedef nnet::array<ap_uint<1>, 1*1> input_t;
typedef nnet::array<ap_uint<1>, 1*1> layer19_t;
typedef ap_fixed<16,6> model_default_t;
typedef nnet::array<ap_fixed<22,13>, 12*1> qconv_1_result_t;
typedef ap_fixed<16,7> weight2_t;
typedef ap_uint<1> bias2_t;
typedef nnet::array<ap_fixed<39,20>, 12*1> batch_normalization_result_t;
typedef ap_fixed<16,6> batch_normalization_scale_t;
typedef ap_fixed<16,6> batch_normalization_bias_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 12*1> layer5_t;
typedef ap_fixed<18,8> qact_1_table_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 12*1> layer6_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 12*1> layer20_t;
typedef nnet::array<ap_fixed<40,21>, 24*1> qconv_2_result_t;
typedef ap_fixed<16,7> weight7_t;
typedef ap_uint<1> bias7_t;
typedef nnet::array<ap_fixed<57,28>, 24*1> batch_normalization_1_result_t;
typedef ap_fixed<16,6> batch_normalization_1_scale_t;
typedef ap_fixed<16,6> batch_normalization_1_bias_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 24*1> layer10_t;
typedef ap_fixed<18,8> qact_2_table_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 24*1> layer11_t;
typedef ap_fixed<18,8> qdense_1_accum_t;
typedef nnet::array<ap_fixed<16,6>, 12*1> layer13_t;
typedef ap_fixed<16,7> weight13_t;
typedef ap_uint<1> bias13_t;
typedef ap_uint<1> layer13_index;
typedef nnet::array<ap_fixed<33,13>, 12*1> batch_normalization_2_result_t;
typedef ap_fixed<16,6> batch_normalization_2_scale_t;
typedef ap_fixed<16,6> batch_normalization_2_bias_t;
typedef nnet::array<ap_ufixed<16,6,AP_RND_CONV,AP_SAT,0>, 12*1> layer16_t;
typedef ap_fixed<18,8> qact_3_table_t;
typedef nnet::array<ap_fixed<37,18>, 1*1> qoutput_result_t;
typedef ap_fixed<16,7> weight17_t;
typedef ap_uint<1> bias17_t;
typedef ap_uint<1> layer17_index;
typedef nnet::array<ap_fixed<16,6>, 1*1> result_t;
typedef ap_fixed<18,8> qoutput_sigmoid_table_t;

// hls-fpga-machine-learning insert emulator-defines


#endif
