# Running local AI LLM models using Ollama+Open-WebUI

Just capturing my notes to run a local LLM model on my Arch WSL distro.

The components I'm using are
- Ollama with CUDA support to host the LLM model on my Nvidia GPU
- Open-WebUI as the web front end to interact and download models
- Podman as the container host, using the crun runtime
- Btop to monitor the CPU/GPU utilization

## Steps
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
    ollama pull maryasov/qwen2.5-coder-cline:14b
    ollama pull deepseek-r1:14b
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
