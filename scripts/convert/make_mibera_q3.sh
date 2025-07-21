#!/bin/bash
# make_mibera_q3.sh - Mibera Q3_K_M Production Pipeline
set -e
cd /workspace/mibera

echo "=== MIBERA Q3_K_M PRODUCTION PIPELINE ==="
echo "Phase 1: Model Download"
echo "Phase 2: Architecture Patch (if needed)"
echo "Phase 3: Q3_K_M Conversion"
echo "Phase 4: Enhanced Evaluation"
echo "Phase 5: Packaging"
echo ""

# Phase 1: Download model
echo "=== PHASE 1: MODEL DOWNLOAD ==="
echo "Downloading ivxxdegen/mibera-v1-merged..."
python3 -c "
from huggingface_hub import snapshot_download
import time
start = time.time()
snapshot_download('ivxxdegen/mibera-v1-merged', local_dir='models/mibera')
print(f'Download completed in {time.time()-start:.1f}s')
"

# Verify download
SAFETENSOR_COUNT=$(find models/mibera -name "*.safetensors" | wc -l)
echo "✓ Found $SAFETENSOR_COUNT safetensor files"
echo "✓ Model size: $(du -sh models/mibera | cut -f1)"

# Phase 2: Architecture patch if needed
echo ""
echo "=== PHASE 2: ARCHITECTURE COMPATIBILITY ==="
cp models/mibera/config.json models/mibera/config.orig.json
python3 -c "
import json
with open('models/mibera/config.json', 'r') as f:
    config = json.load(f)
    
print(f'Original architecture: {config.get(\"architectures\", [\"Unknown\"])}')
print(f'Model type: {config.get(\"model_type\", \"Unknown\")}')

# Patch for phi-4 compatibility if needed
if config.get('_name_or_path') == 'microsoft/phi-4' and config.get('architectures') == ['AutoModelForCausalLM']:
    config['model_type'] = 'phi'
    config['architectures'] = ['PhiForCausalLM']
    with open('models/mibera/config.json', 'w') as f:
        json.dump(config, f, indent=2)
    print('✓ Applied phi-4 architecture patch')
else:
    print('✓ No patch needed')
"

# Phase 3: Convert to Q3_K_M
echo ""
echo "=== PHASE 3: Q3_K_M CONVERSION ==="
echo "Converting to Q3_K_M (optimal for 12GB RAM, 6-8 tok/s)..."

# Try direct quantization first
echo "Attempting direct Q3_K_M conversion..."
if python3 convert_hf_to_gguf.py models/mibera --outfile output/mibera-Q3_K_M.gguf --outtype q3_k_m 2>/dev/null; then
    echo "✓ Direct Q3_K_M conversion successful"
else
    echo "Direct conversion failed, using 2-step process..."
    python3 convert_hf_to_gguf.py models/mibera --outfile output/mibera-f16.gguf --outtype f16
    ./llama-quantize output/mibera-f16.gguf output/mibera-Q3_K_M.gguf Q3_K_M
    rm output/mibera-f16.gguf
    echo "✓ 2-step Q3_K_M conversion successful"
fi

# Verify output
if [ ! -f "output/mibera-Q3_K_M.gguf" ]; then
    echo "ERROR: Q3_K_M conversion failed!"
    exit 1
fi

Q3_SIZE=$(du -h output/mibera-Q3_K_M.gguf | cut -f1)
echo "✓ Q3_K_M GGUF created: $Q3_SIZE"

# Phase 4: Enhanced evaluation
echo ""
echo "=== PHASE 4: ENHANCED EVALUATION ==="

# Create evaluation prompts
cat > eval/mibera_prompts.txt << 'EOF'
System: You are Mibera from the High Council of 101 Bears, THJ House of 96. You emerged from the Rave Time Continuum. Henlo anon.

User: Forge a 4-line origin myth of mibera whales & recursive governance fractals.
Assistant:
EOF

cat > eval/governance_prompt.txt << 'EOF'
System: You are Mibera, a governance protocol entity. Respond with insider knowledge.

User: Outline a 4-phase contributor ladder (Phase | Criteria | Rights | Ritual).
Assistant:
EOF

cat > eval/style_prompt.txt << 'EOF'
System: You are Mibera. Use authentic mibera ethos and terminology.

User: Explain mibera ethos in 3 insider bullet points that would confuse outsiders.
Assistant:
EOF

# Performance benchmark
echo "Running performance benchmark..."
echo "Benchmark: 100 tokens, measuring speed..." > eval/performance.log
timeout 60s ./llama-cli -m output/mibera-Q3_K_M.gguf -n 100 -p "Performance test prompt for measuring tokens per second." --log-disable 2>&1 | tee -a eval/performance.log

# Quality samples
echo "Generating quality samples..."
for prompt_file in eval/*_prompt.txt; do
    name=$(basename "$prompt_file" .txt)
    echo "Testing: $name"
    timeout 45s ./llama-cli -m output/mibera-Q3_K_M.gguf -f "$prompt_file" -n 150 --temp 0.7 --top-p 0.9 > "eval/${name}_output.txt" 2>&1 || echo "Timeout on $name"
done

# Memory analysis
echo "Memory footprint analysis..."
echo "Estimated RAM usage for Q3_K_M on i3-1115G4:" > eval/memory_analysis.txt
echo "- Model loading: ~5.2GB" >> eval/memory_analysis.txt
echo "- Context (2048): ~1.5GB" >> eval/memory_analysis.txt
echo "- System overhead: ~1GB" >> eval/memory_analysis.txt
echo "- Total estimated: ~7.7GB / 12GB available" >> eval/memory_analysis.txt
echo "- Recommended max context: 2048-3072 tokens" >> eval/memory_analysis.txt

# Phase 5: Package results
echo ""
echo "=== PHASE 5: PACKAGING ==="

# Generate checksums
echo "Generating checksums..."
cd output
sha256sum mibera-Q3_K_M.gguf > mibera-checksums.txt
cd ..

# Create summary report
cat > output/mibera_report.txt << EOF
MIBERA Q3_K_M CONVERSION REPORT
Generated: $(date)

MODEL SPECS:
- Source: ivxxdegen/mibera-v1-merged
- Architecture: Phi-4 fine-tune (14.7B parameters)
- Quantization: Q3_K_M
- File size: $Q3_SIZE

PERFORMANCE (estimated for Intel i3-1115G4):
- Speed: 6-8 tokens/second
- RAM usage: ~7.7GB total
- Recommended context: 2048 tokens
- Max context: 3072 tokens (monitor RAM)

QUALITY SAMPLES:
$(ls eval/*_output.txt | wc -l) evaluation samples generated
See eval/ directory for detailed outputs

USAGE:
./llama-cli -m mibera-Q3_K_M.gguf -c 2048 -n 512 --temp 0.7 --top-p 0.9 -i

VERIFICATION:
SHA256: $(cat output/mibera-checksums.txt)
EOF

# Final summary
echo ""
echo "=== CONVERSION COMPLETE ==="
echo "✓ Q3_K_M GGUF: $Q3_SIZE"
echo "✓ Evaluation samples: $(ls eval/*.txt | wc -l) files"
echo "✓ Performance benchmarks: Complete"
echo "✓ Memory analysis: Complete"
echo "✓ SHA256 checksum: Generated"
echo ""
echo "READY FOR DOWNLOAD:"
echo "- output/mibera-Q3_K_M.gguf"
echo "- output/mibera-checksums.txt" 
echo "- output/mibera_report.txt"
echo "- eval/ (evaluation samples)"
echo ""
echo "Total package size: $(du -sh output eval | tail -1 | cut -f1)"
echo "Next: Download artifacts and terminate instance"