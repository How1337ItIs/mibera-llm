
# Upload and run bias fix
scp -i ~/.ssh/vastai_ed25519 -P 34574 fix_bias_remote.py root@136.59.129.136:/workspace/mibera/output_fused/
ssh -i ~/.ssh/vastai_ed25519 -p 34574 root@136.59.129.136 "cd /workspace/mibera/output_fused && python3 fix_bias_remote.py"
