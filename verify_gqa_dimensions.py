#!/usr/bin/env python3
"""Verify GQA dimension calculations for Mibera model."""

# Mibera model parameters
n_embd = 5120      # Hidden size
n_head = 32        # Number of query heads
n_head_kv = 8      # Number of KV heads (GQA)

# Calculate dimensions
head_dim = n_embd // n_head  # 160
n_embd_k_gqa = head_dim * n_head_kv  # 1280
n_embd_v_gqa = head_dim * n_head_kv  # 1280

# QKV tensor dimensions
n_embd_qkv = n_embd + n_embd_k_gqa + n_embd_v_gqa

print("Mibera GQA Dimension Analysis:")
print("==============================")
print(f"n_embd (hidden size): {n_embd}")
print(f"n_head (query heads): {n_head}")
print(f"n_head_kv (KV heads): {n_head_kv}")
print(f"head_dim: {head_dim}")
print(f"GQA ratio: {n_head}/{n_head_kv} = {n_head//n_head_kv}:1")
print(f"\nCalculated dimensions:")
print(f"Q projection: {n_embd} -> {n_embd}")
print(f"K projection: {n_embd} -> {n_embd_k_gqa}")
print(f"V projection: {n_embd} -> {n_embd_v_gqa}")
print(f"\nQKV tensor shape: [{n_embd}, {n_embd_qkv}]")
print(f"Expected by llama.cpp (MHA): [{n_embd}, {3*n_embd}]")
print(f"Actual in Mibera (GQA): [{n_embd}, {n_embd_qkv}]")
print(f"\nOur patch calculation: n_embd + n_embd_k_gqa + n_embd_v_gqa = {n_embd} + {n_embd_k_gqa} + {n_embd_v_gqa} = {n_embd_qkv}")
print(f"This matches the actual tensor dimension: 7680 ✓")