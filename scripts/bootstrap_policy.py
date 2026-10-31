"""Static stage boundary: reject provisionable configuration in this bootstrap."""
from pathlib import Path
import re

for path in Path(".").rglob("*.tf"):
    if ".terraform" in path.parts:
        continue
    text = path.read_text()
    if re.search(r'^\s*(resource|data|provider|module|import)\s+["{]', text, re.M):
        raise SystemExit(f"{path}: cloud/resource blocks are outside bootstrap scope")
print("Bootstrap policy passed: no resources, providers, modules or data lookups")
