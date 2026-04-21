# Continue + Code Llama Integration for KythOS

This file documents how the Continue AI coding agent and Code Llama LLM are integrated into KythOS, and how users can switch models if desired.

## Default Setup
- **Continue** is installed system-wide (Node.js + @continueai/continue)
- **VS Code extension** for Continue is pre-installed
- **Code Llama** is the default local LLM for code assistance

## Model Switching
Users can switch to a different LLM by editing the Continue configuration file or using the Continue sidebar in VS Code:
- Edit `~/.continue/config.json` (user-specific)
- Or use the Continue sidebar UI to select a different model or endpoint

## Model Installation (Default: Code Llama)
- Code Llama is downloaded and set up during the OS build process
- The model is stored in `/usr/local/share/llm-models/codellama` (or similar)
- Continue is configured to use this model by default

## Advanced: Add More Models
- Place additional models in `/usr/local/share/llm-models/`
- Update the Continue config to point to the desired model

## Troubleshooting
- If Continue cannot start or connect to the model, check Node.js and model installation
- Logs: `~/.continue/logs/` or run `continue` in a terminal for debug output

---

For more, see https://continue.dev/docs and https://github.com/facebookresearch/codellama
