{ config, pkgs, inputs, ... }:

let
  tensorzeroConfig = pkgs.writeText "tensorzero.toml" ''
    [gateway]
    bind_address = "0.0.0.0:3000"

    # Keep the main fast path tool-capable. Gemma stays as a last-resort
    # fallback behind a separate TensorZero function with tool use disabled.
    [models.agent-fast]
    routing = ["gemini-3-flash-preview", "qwen-3-235b-a22b-instruct-2507"]

    [models.agent-fast.providers.gemini-3-flash-preview]
    type = "google_ai_studio_gemini"
    model_name = "gemini-3-flash-preview"

    [models.agent-fast.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [functions.agent-fast]
    type = "chat"

    [functions.agent-fast.variants.gemini-first]
    type = "chat_completion"
    model = "agent-fast"

    [models.agent-fast-gemma]
    routing = ["gemma-google"]

    [models.agent-fast-gemma.providers.gemma-google]
    type = "google_ai_studio_gemini"
    model_name = "gemma-4-31b-it"

    [functions.agent-fast-gemma]
    type = "chat"
    tool_choice = "none"

    [functions.agent-fast-gemma.variants.gemma-last-resort]
    type = "chat_completion"
    model = "agent-fast-gemma"

    [models.agent-capable]
    routing = ["minimax-free", "qwen-free", "nemotron-free", "gpt-oss-groq", "qwen-3-235b-a22b-instruct-2507", "llama-groq"]

    [models.agent-capable.providers.minimax-free]
    type = "openrouter"
    model_name = "minimax/minimax-m2.5:free"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-capable.providers.qwen-free]
    type = "openrouter"
    model_name = "qwen/qwen3-coder:free"

    [models.agent-capable.providers.nemotron-free]
    type = "openrouter"
    model_name = "nvidia/nemotron-3-super-120b-a12b:free"

    [models.agent-capable.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-capable.providers.gpt-oss-groq]
    type = "groq"
    model_name = "openai/gpt-oss-120b"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-capable.providers.llama-groq]
    type = "groq"
    model_name = "llama-3.3-70b-versatile"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    # [models.agent-capable.providers.gemma-google]
    # type = "google_ai_studio_gemini"
    # model_name = "gemma-4-31b-it"

    [models.agent-coding]
    routing = ["qwen-free", "nemotron-free", "gpt-oss-groq", "llama-groq"]

    [models.agent-coding.providers.qwen-free]
    type = "openrouter"
    model_name = "qwen/qwen3-coder:free"

    [models.agent-coding.providers.nemotron-free]
    type = "openrouter"
    model_name = "nvidia/nemotron-3-super-120b-a12b:free"

    [models.agent-coding.providers.gpt-oss-groq]
    type = "groq"
    model_name = "openai/gpt-oss-120b"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-coding.providers.llama-groq]
    type = "groq"
    model_name = "llama-3.3-70b-versatile"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

  '';
in
{
  imports = [
    inputs.openclaw.nixosModules.openclaw-gateway
  ];

  fileSystems."/var/lib/openclaw/.openclaw/workspace/nixos-config" = {
    device = "/home/ruben/nixos-config";
    fsType = "none";
    options = [ "bind" "ro" ];
  };

  services.openclaw-gateway = {
    enable = true;

    config = {
      gateway = {
        mode = "local";
        auth.mode = "token";
      };

      channels.telegram = {
        tokenFile = config.sops.secrets.openclaw_telegram_token.path;
        "allowFrom" = [1669854468];
        "enabled" = true;
      };

      agents.defaults = {
        model.primary = "tensorzero/tensorzero::function_name::agent-fast";
        model.fallbacks = [
          "tensorzero/tensorzero::function_name::agent-fast-gemma"
        ];
        models = {
          "tensorzero/tensorzero::function_name::agent-fast".alias = "agent-fast";
          "tensorzero/tensorzero::function_name::agent-fast-gemma".alias = "agent-fast-gemma";
          "tensorzero/tensorzero::model_name::agent-capable".alias = "agent-capable";
          "tensorzero/tensorzero::model_name::agent-coding".alias = "agent-coding";
        };
        timeoutSeconds = 180;
      };

      tools.media.audio = {
        enabled = true;
        echoTranscript = true;
        models = [
          { provider = "groq"; }
        ];
      };

      models = {
        mode = "merge";
        providers.tensorzero = {
          baseUrl = "http://localhost:3000/openai/v1";
          api = "openai-completions";
          apiKey = "sk-tensorzero-local";
          models = [
            {
              id = "tensorzero::function_name::agent-fast";
              name = "TensorZero agent-fast";
              input = [ "text" ];
            }
            {
              id = "tensorzero::function_name::agent-fast-gemma";
              name = "TensorZero agent-fast-gemma";
              input = [ "text" ];
            }
            {
              id = "tensorzero::model_name::agent-capable";
              name = "TensorZero agent-capable";
              input = [ "text" ];
            }
            {
              id = "tensorzero::model_name::agent-coding";
              name = "TensorZero agent-coding";
              input = [ "text" ];
            }
          ];
        };
      };
    };

    environment = {
      OPENCLAW_NIX_MODE = "1";
    };

    environmentFiles = [
      config.sops.secrets.ai_agents_env.path
    ];
  };

  sops.secrets.ai_agents_env = {
    sopsFile = ./secrets.yaml;
    owner = "openclaw";
  };

  sops.secrets.openclaw_telegram_token = {
    sopsFile = ./secrets.yaml;
    owner = "openclaw";
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers = {
      tensorzero = {
        image = "tensorzero/gateway:latest";
        ports = [ "3000:3000" ];
        volumes = [
          "${tensorzeroConfig}:/config/tensorzero.toml:ro"
        ];
        environmentFiles = [
          config.sops.secrets.ai_agents_env.path
        ];
        cmd = [ "--config-file" "/config/tensorzero.toml" ];
      };
    };
  };
}
