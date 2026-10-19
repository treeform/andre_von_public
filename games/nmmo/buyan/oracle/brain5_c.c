/* PufferLib 5.0 brain C core for the Nim parity test: the unmodified
 * src/puffercpu.c primitives and ocean/nmmo3/nmmo3_net.h MMONet
 * (init_mmonet_arch + mmonet_encode + mingru + decoder) producing raw
 * logits (26 + value). Sampling is done caller-side (Nim).
 */
#include "src/puffercpu.c"
#include "ocean/nmmo3/nmmo3_net.h"

void* brain5_create(const char* weights_path, int num_agents, int hidden,
                    int layers) {
    Weights* weights = load_weights(weights_path);
    if (!weights) return 0;
    if (nmmo3_weight_count(hidden, layers) + 7 != weights->size) return 0;
    return init_mmonet_arch(weights, num_agents, hidden, layers);
}

/* obs: num_agents*1707 bytes; terminals: num_agents floats (1.0 resets
 * that agent's recurrent state, cleared here); out: num_agents*27. */
void brain5_forward(void* handle, unsigned char* observations,
                    float* terminals, float* out) {
    MMONet* net = (MMONet*)handle;
    mingru_zero_term(net->mingru, terminals);
    for (int b = 0; b < net->num_agents; b++) terminals[b] = 0.0f;
    mmonet_encode(net, observations, NULL);
    mingru(net->mingru, net->proj_relu->output);
    linear(net->decoder, net->mingru->output);
    memcpy(out, net->decoder->output,
           (size_t)net->num_agents * (N3_ATN + 1) * sizeof(float));
}
