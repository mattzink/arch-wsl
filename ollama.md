# Running local LLMs using Ollama

Just capturing my notes to run a local LLM model on my Arch WSL distro.

The components I'm using are
- `Ollama` with CUDA support to serve LLM models from my Nvidia GPU
- `Open WebUI` as the web front end to interact and download models
    - Uses `Podman` as the container host with the `crun` runtime
- `Btop` to monitor the CPU/GPU utilization

## WSL Configuration Steps

1. Install packages

    ```bash
    yay -S ollama-cuda podman crun btop
    ```

2. Expose Ollama service externally

    ```bash
    sudo systemctl edit ollama
    ```
    Contents:
    ```ini
    [Service]
    Environment="OLLAMA_HOST=0.0.0.0:11434"
    ```

3. Configure Ollama systemd service to auto-start

    ```bash
    sudo systemctl daemon-reload && sudo systemctl enable ollama && sudo systemctl start ollama
    ```

4. Pull [LLM models](https://ollama.com/search) you want to use (can also be done in web UI)

    Example:
    ```bash
    ollama pull ishumilin/deepseek-r1-coder-tools:8b
    ollama pull qwen2.5-coder:7b-base
    ```

5. Create a script to start the open-webui container on demand

    ```bash
    install /dev/null ~/start-open-webui.sh && vi ~/start-open-webui.sh
    ```
    Contents:
    ```bash
    #!/bin/bash -e

    # Update container image
    sudo podman rm -f open-webui
    sudo podman pull ghcr.io/open-webui/open-webui:main

    # Start container in no-auth mode and with persistent volume 
    sudo podman run -d -p 3000:8080 -e WEBUI_AUTH=False -v open-webui:/app/backend/data --name open-webui ghcr.io/open-webui/open-webui:main

    echo "Open-WebUI now browsable at http://localhost:3000/"
    ```

    After executing the script, you should now be able to browse to the web UI at http://localhost:3000/

## Using Ollama as a code assistant in VSCode

After configuring WSL as above, you can use it to provide code assistance within Visual Studio Code.
 
1. If you are running VS Code on a machine other the WSL host, add a **Hyper-V** firewall rule to allow incoming connections.

    From an **<ins>Admin Elevated</ins>** Powershell prompt on the WSL host:
    ```pwsh
    New-NetFirewallHyperVRule -Name "WSLOllama" -DisplayName "WSL Ollama" -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol TCP -LocalPorts 11434
    ```

2. Install the [Continue extension](https://marketplace.visualstudio.com/items?itemName=Continue.continue) for VSCode.

3. Edit Continue's `config.json` file to use your local Ollama with appropriate models:
    ```json
    {
      "models": [
        {
          "title": "ollama-chat",
          "provider": "ollama",
          "model": "ishumilin/deepseek-r1-coder-tools:8b",
          "apiBase": "http://192.168.X.X:11434/"
        }
      ],
      "tabAutocompleteModel": {
        "title": "ollama-code-complete",
        "provider": "ollama",
        "model": "qwen2.5-coder:7b-base", 
        "apiBase": "http://192.168.X.X:11434/"
      }
      ...
    }
    ```

    Note that the `apiBase` field should only be necessary when running VS code outside of the WSL host.
    To determine your WSL distro's IP address, run the following command in PowerShell:
    ```pwsh
    wsl -d arch -- ip route get 1 `| grep eth `| cut -d' ' -f7
    ```
