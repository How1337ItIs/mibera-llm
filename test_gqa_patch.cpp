#include <iostream>
#include <cstdint>

// Simulating the GQA dimension calculation
int main() {
    // Mibera model parameters
    const int64_t n_embd = 5120;
    const int64_t n_head = 32;
    const int64_t n_head_kv = 8;  // GQA with 8 KV head groups
    
    // Calculate dimensions
    const int64_t head_dim = n_embd / n_head;  // 160
    const int64_t n_embd_k_gqa = head_dim * n_head_kv;  // 1280
    const int64_t n_embd_v_gqa = head_dim * n_head_kv;  // 1280
    
    // QKV tensor dimensions
    const int64_t n_embd_qkv = n_embd + n_embd_k_gqa + n_embd_v_gqa;
    
    std::cout << "Mibera GQA Dimension Analysis:\n";
    std::cout << "==============================\n";
    std::cout << "n_embd (hidden size): " << n_embd << "\n";
    std::cout << "n_head (query heads): " << n_head << "\n";
    std::cout << "n_head_kv (KV heads): " << n_head_kv << "\n";
    std::cout << "head_dim: " << head_dim << "\n";
    std::cout << "\nCalculated dimensions:\n";
    std::cout << "Q projection: " << n_embd << " -> " << n_embd << "\n";
    std::cout << "K projection: " << n_embd << " -> " << n_embd_k_gqa << "\n";
    std::cout << "V projection: " << n_embd << " -> " << n_embd_v_gqa << "\n";
    std::cout << "\nQKV tensor shape: [" << n_embd << ", " << n_embd_qkv << "]\n";
    std::cout << "Expected by llama.cpp (MHA): [" << n_embd << ", " << 3*n_embd << "]\n";
    std::cout << "Actual in Mibera (GQA): [" << n_embd << ", " << n_embd_qkv << "]\n";
    
    return 0;
}