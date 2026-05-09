# The-Spy-s-Backdoor

**********************************************************************************************************************************

## Challenge Overview

The story behind this challenge: a spy planted a backdoor on a Linux system and left 4 pieces of evidence behind before disappearing. My job was to act as a forensic investigator and find all 4 clues, understand what the spy did, and capture the hidden flag.

The 4 things I needed to find:
- A hidden user account the spy created
- An encrypted note hidden inside a dotfile
- A file with dangerous SUID permissions
- Evidence of a reverse shell process

This challenge covered real techniques used in actual penetration testing and CTF competitions.

**********************************************************************************************************************************

## Environment Setup

Before the challenge could begin, the environment needed to be built. This was done using a Python script that created the entire directory structure, files, and permissions automatically.

```python
python3 << 'EOF'
import os, subprocess

os.makedirs('/tmp/spy_case/logs', exist_ok=True)
os.makedirs('/tmp/spy_case/.hidden', exist_ok=True)
os.makedirs('/tmp/spy_case/system/proc', exist_ok=True)
os.makedirs('/tmp/spy_case/files', exist_ok=True)
EOF
```
