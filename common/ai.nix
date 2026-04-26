{ config, pkgs, inputs, ... }:

let
  tensorzeroConfig = pkgs.writeText "tensorzero.toml" ''
    [gateway]
    bind_address = "0.0.0.0:3000"

    [models.agent-default]
    routing = ["minimax-free", "qwen-free", "nemotron-free", "gpt-oss-groq", "qwen-3-235b-a22b-instruct-2507", "llama-groq"]

    [models.agent-default.providers.minimax-free]
    type = "openrouter"
    model_name = "minimax/minimax-m2.5:free"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-default.providers.qwen-free]
    type = "openrouter"
    model_name = "qwen/qwen3-coder:free"

    [models.agent-default.providers.nemotron-free]
    type = "openrouter"
    model_name = "nvidia/nemotron-3-super-120b-a12b:free"

    [models.agent-default.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-default.providers.gpt-oss-groq]
    type = "groq"
    model_name = "openai/gpt-oss-120b"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    [models.agent-default.providers.llama-groq]
    type = "groq"
    model_name = "llama-3.3-70b-versatile"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
    ]

    # [models.agent-default.providers.gemma-google]
    # type = "google_ai_studio_gemini"
    # model_name = "gemma-4-31b-it"

    [models.agent-coding]
    routing = ["qwen-free", "nemotron-free", "gpt-oss-groq", "llama-groq", "gemma-google"]

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

    [models.agent-coding.providers.gemma-google]
    type = "google_ai_studio_gemini"
    model_name = "gemma-4-31b-it"
  '';
in
{
  imports = [
    inputs.openclaw.nixosModules.openclaw-gateway
  ];

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
        model.primary = "tensorzero/tensorzero::model_name::agent-default";
        models = {
          "tensorzero/tensorzero::model_name::agent-default".alias = "agent-default";
          "tensorzero/tensorzero::model_name::agent-coding".alias = "agent-coding";
        };
      };

      tools.media.audio = {
        enabled = true;
        echoTranscript = true;
        models = [
          { provider = "groq"; model = "whisper-large-v3-turbo"; }
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
              id = "tensorzero::model_name::agent-default";
              name = "TensorZero agent-default";
              input = [ "text" ];
            }
            {
              id = "tensorzero::model_name::agent-coding";
              name = "TensorZero agent-coding";
              input = [ "text" ];
            }
          ];
        };
        providers.groq = {
          api = "openai-completions";
          baseUrl = "https://api.groq.com/openai/v1";
          apiKeyEnv = "GROQ_API_KEY";
          models = [
            {
              id = "whisper-large-v3-turbo";
              name = "Whisper Large v3 Turbo";
              input = [ "audio" ];
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
