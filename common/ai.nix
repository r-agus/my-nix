{ config, pkgs, inputs, ... }:

let
  tensorzeroConfig = pkgs.writeText "tensorzero.toml" ''
    [gateway]
    bind_address = "0.0.0.0:3000"

    [models.agent-fast]
    routing = ["gemini-google", "qwen-3-235b-a22b-instruct-2507", "gemma-google", "gpt-oss-groq", "nemotron-free"]

    [models.agent-fast.providers.gemini-google]
    type = "google_ai_studio_gemini"
    model_name = "gemini-3.1-flash-lite-preview"
    extra_body = [
      { pointer = "/tools/0/functionDeclarations/3/parameters", value = { type = "object", properties = { command = { type = "string", description = "Shell command to execute." }, cwd = { type = "string", description = "Working directory. Optional." } }, required = ["command"] } },
      { pointer = "/tools/0/functionDeclarations/7/parameters", value = { type = "object", properties = { name = { type = "string", description = "Name of the scheduled task." }, schedule = { type = "string", description = "Cron expression or natural-language schedule." }, command = { type = "string", description = "Command or instruction to run." } }, required = ["name", "schedule", "command"] } }
    ]

    [models.agent-fast.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-fast.providers.gemma-google]
    type = "google_ai_studio_gemini"
    model_name = "gemma-4-31b-it"
    extra_body = [
      { pointer = "/tools/0/functionDeclarations/3/parameters", value = { type = "object", properties = { command = { type = "string", description = "Shell command to execute." }, cwd = { type = "string", description = "Working directory. Optional." } }, required = ["command"] } },
      { pointer = "/tools/0/functionDeclarations/7/parameters", value = { type = "object", properties = { name = { type = "string", description = "Name of the scheduled task." }, schedule = { type = "string", description = "Cron expression or natural-language schedule." }, command = { type = "string", description = "Command or instruction to run." } }, required = ["name", "schedule", "command"] } }
    ]

    [models.agent-fast.providers.gpt-oss-groq]
    type = "groq"
    model_name = "openai/gpt-oss-120b"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-fast.providers.nemotron-free]
    type = "openrouter"
    model_name = "nvidia/nemotron-3-super-120b-a12b:free"

    [functions.agent-fast]
    type = "chat"

    [functions.agent-fast.variants.gemini-first]
    type = "chat_completion"
    model = "agent-fast"

    [models.agent-smart]
    routing = ["qwen-3-235b-a22b-instruct-2507", "gemini-google", "minimax-free", "nemotron-free", "gemma-google", "gpt-oss-groq"]

    [models.agent-smart.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-smart.providers.gemini-google]
    type = "google_ai_studio_gemini"
    model_name = "gemini-3.0-flash"
    extra_body = [
      { pointer = "/tools/0/functionDeclarations/3/parameters", value = { type = "object", properties = { command = { type = "string", description = "Shell command to execute." }, cwd = { type = "string", description = "Working directory. Optional." } }, required = ["command"] } },
      { pointer = "/tools/0/functionDeclarations/7/parameters", value = { type = "object", properties = { name = { type = "string", description = "Name of the scheduled task." }, schedule = { type = "string", description = "Cron expression or natural-language schedule." }, command = { type = "string", description = "Command or instruction to run." } }, required = ["name", "schedule", "command"] } }
    ]

    [models.agent-smart.providers.minimax-free]
    type = "openrouter"
    model_name = "minimax/minimax-m2.5:free"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-smart.providers.nemotron-free]
    type = "openrouter"
    model_name = "nvidia/nemotron-3-super-120b-a12b:free"

    [models.agent-smart.providers.gemma-google]
    type = "google_ai_studio_gemini"
    model_name = "gemma-4-31b-it"

    [models.agent-smart.providers.gpt-oss-groq]
    type = "groq"
    model_name = "openai/gpt-oss-120b"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

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
        models = {
          "tensorzero/tensorzero::function_name::agent-fast".alias = "agent-fast";
          "tensorzero/tensorzero::model_name::agent-smart".alias = "agent-smart";
          "tensorzero/tensorzero::model_name::agent-coding".alias = "agent-coding";
        };
        timeoutSeconds = 180;
      };

      tools = {
        media.audio = {
          enabled = true;
          echoTranscript = true;
          models = [
            { provider = "groq"; model = "whisper-large-v3-turbo"; }
          ];
        };
        media.image = {
          enabled = true;
          models = [
            {
              provider = "gemini";
              model = "gemma-4-31b-it";
              capabilities = [ "image" ];
            }
            {
              provider = "openrouter";
              model = "google/gemma-4-31b-it:free";
              capabilities = [ "image" ];
            }
            {
              provider = "gemini";
              model = "gemini-3.1-flash-lite-preview";
              capabilities = [ "image" ];
            }
          ];
        };
        media.video = {
          enabled = true;
          maxBytes = 52428800; # 50 MB
          maxChars = 800;
          timeoutSeconds = 120;
          models = [
            { provider = "gemini"; model = "gemini-3.1-flash-lite-preview"; }
            { provider = "gemini"; model = "gemini-3-flash-preview"; }
          ];
        };
        web.search = {
          enabled = true;
          provider = "gemini";
        };
      };

      plugins.entries.google.config.webSearch = {
        model = "gemini-2.5-flash";
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
              id = "tensorzero::model_name::agent-smart";
              name = "TensorZero agent-smart";
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
