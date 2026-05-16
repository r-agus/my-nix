{ config, lib, pkgs, inputs, ... }:

let
  openclawPkg = inputs.openclaw.packages.${pkgs.system}.openclaw;
  geminiOpenAIProxyPort = 3002;
  geminiOpenAIProxyBase = "http://localhost:${toString geminiOpenAIProxyPort}/v1beta/openai";
  googleOpenAIProvider = modelName: ''
    type = "openai"
    api_base = "${geminiOpenAIProxyBase}"
    api_key_location = "env::GOOGLE_AI_STUDIO_API_KEY"
    model_name = "${modelName}"
  '';
  geminiSchemaProxy = pkgs.writeText "gemini-openai-schema-proxy.py" ''
    #!/usr/bin/env python3
    import http.client
    import json
    import os
    import socket
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    TARGET_HOST = "generativelanguage.googleapis.com"
    LISTEN_HOST = os.environ.get("GEMINI_OPENAI_PROXY_HOST", "0.0.0.0")
    LISTEN_PORT = int(os.environ.get("GEMINI_OPENAI_PROXY_PORT", "${toString geminiOpenAIProxyPort}"))

    HOP_BY_HOP_HEADERS = {
        "connection",
        "keep-alive",
        "proxy-authenticate",
        "proxy-authorization",
        "te",
        "trailers",
        "transfer-encoding",
        "upgrade",
    }

    SCHEMA_KEYS = {
        "type",
        "description",
        "enum",
        "properties",
        "required",
        "items",
        "format",
        "nullable",
    }
    FUNCTION_KEYS = {"name", "description", "parameters"}
    DUMMY_THOUGHT_SIGNATURE = "skip_thought_signature_validator"
    ERROR_LOG_LIMIT = 8192

    def append_description(schema, note):
        description = schema.get("description")
        if isinstance(description, str) and description.strip():
            schema["description"] = f"{description.rstrip()} {note}"
        else:
            schema["description"] = note

    def infer_type(schema):
        value_type = schema.get("type")
        if isinstance(value_type, list):
            non_null = [entry for entry in value_type if entry != "null"]
            if len(non_null) != len(value_type):
                schema["nullable"] = True
            return non_null[0] if non_null else "string"
        if isinstance(value_type, str):
            return value_type
        if "properties" in schema:
            return "object"
        if "patternProperties" in schema or "pattern_properties" in schema or "additionalProperties" in schema:
            return "object"
        if "items" in schema:
            return "array"
        if "enum" in schema and isinstance(schema["enum"], list) and schema["enum"]:
            first = schema["enum"][0]
            if isinstance(first, bool):
                return "boolean"
            if isinstance(first, int) and not isinstance(first, bool):
                return "integer"
            if isinstance(first, float):
                return "number"
        return "string"

    def merge_any_of(schema, variants):
        sanitized_variants = [
            sanitize_schema(variant)
            for variant in variants
            if isinstance(variant, dict)
        ]
        const_values = []
        nullable = False
        for variant in variants:
            if isinstance(variant, dict) and "const" in variant:
                const_values.append(variant["const"])
            if isinstance(variant, dict) and variant.get("type") == "null":
                nullable = True

        if const_values:
            merged = {
                "type": infer_type({"enum": const_values}),
                "enum": const_values,
            }
            if nullable:
                merged["nullable"] = True
            return merged

        non_null_variants = [
            variant
            for variant in sanitized_variants
            if variant.get("type") != "null"
        ]
        if not non_null_variants:
            return {"type": "string", "nullable": True}

        first = dict(non_null_variants[0])
        if nullable:
            first["nullable"] = True
        append_description(first, "Accepts one of several compatible shapes.")
        return first

    def sanitize_schema(value):
        if not isinstance(value, dict):
            return value

        any_of = value.get("anyOf") or value.get("any_of") or value.get("oneOf") or value.get("one_of")
        if isinstance(any_of, list):
            merged = merge_any_of(value, any_of)
            for key in ("description", "format"):
                if key in value and key not in merged:
                    merged[key] = value[key]
            value = {**value, **merged}

        sanitized = {}
        value_type = infer_type(value)
        sanitized["type"] = value_type

        for key in SCHEMA_KEYS:
            if key in value and key != "type":
                sanitized[key] = value[key]

        if "const" in value and "enum" not in sanitized:
            sanitized["enum"] = [value["const"]]
            sanitized["type"] = infer_type(sanitized)

        if value_type == "object":
            raw_properties = value.get("properties")
            if isinstance(raw_properties, dict):
                sanitized["properties"] = {
                    key: sanitize_schema(prop)
                    for key, prop in raw_properties.items()
                    if isinstance(prop, dict)
                }
            elif "patternProperties" in value or "pattern_properties" in value or "additionalProperties" in value:
                sanitized["properties"] = {}
                append_description(sanitized, "Accepts an object with provider-defined keys.")

            raw_required = value.get("required")
            if isinstance(raw_required, list):
                properties = sanitized.get("properties")
                if isinstance(properties, dict):
                    sanitized["required"] = [
                        key
                        for key in raw_required
                        if isinstance(key, str) and key in properties
                    ]

        if value_type == "array":
            items = value.get("items")
            sanitized["items"] = sanitize_schema(items) if isinstance(items, dict) else {"type": "string"}

        return {
            key: val
            for key, val in sanitized.items()
            if key in SCHEMA_KEYS and val is not None
        }

    def sanitize_function(function):
        if not isinstance(function, dict):
            return None

        sanitized = {}
        name = function.get("name")
        if isinstance(name, str) and name:
            sanitized["name"] = name

        description = function.get("description")
        if isinstance(description, str) and description:
            sanitized["description"] = description

        parameters = function.get("parameters")
        if isinstance(parameters, dict):
            sanitized["parameters"] = sanitize_schema(parameters)
        else:
            sanitized["parameters"] = {"type": "object", "properties": {}}

        if "name" not in sanitized:
            return None
        return sanitized

    def sanitize_tool(tool):
        if not isinstance(tool, dict):
            return None

        function = tool.get("function")
        if not isinstance(function, dict) and "name" in tool:
            function = {
                key: tool[key]
                for key in FUNCTION_KEYS
                if key in tool
            }

        sanitized_function = sanitize_function(function)
        if sanitized_function is None:
            return None

        return {
            "type": "function",
            "function": sanitized_function,
        }

    def add_missing_thought_signatures(payload):
        messages = payload.get("messages")
        if not isinstance(messages, list):
            return payload

        for message in messages:
            if not isinstance(message, dict):
                continue
            if message.get("role") not in {"assistant", "model"}:
                continue

            tool_calls = message.get("tool_calls")
            if not isinstance(tool_calls, list):
                continue

            for tool_call in tool_calls:
                if not isinstance(tool_call, dict):
                    continue
                extra_content = tool_call.get("extra_content")
                if not isinstance(extra_content, dict):
                    extra_content = {}
                    tool_call["extra_content"] = extra_content
                google = extra_content.get("google")
                if not isinstance(google, dict):
                    google = {}
                    extra_content["google"] = google
                google.setdefault("thought_signature", DUMMY_THOUGHT_SIGNATURE)

        return payload

    def sanitize_openai_payload(payload):
        payload = add_missing_thought_signatures(payload)
        tools = payload.get("tools")
        if not isinstance(tools, list):
            return payload

        sanitized_tools = []
        for tool in tools:
            sanitized_tool = sanitize_tool(tool)
            if sanitized_tool is not None:
                sanitized_tools.append(sanitized_tool)
        payload["tools"] = sanitized_tools
        return payload

    def write_json_error(handler, status, message):
        body = json.dumps({
            "error": {
                "message": message,
                "type": "gemini_schema_proxy_error",
            }
        }).encode("utf-8")
        handler.send_response(status)
        handler.send_header("Content-Type", "application/json")
        handler.send_header("Content-Length", str(len(body)))
        handler.send_header("Connection", "close")
        handler.end_headers()
        handler.close_connection = True
        handler.wfile.write(body)

    def log_upstream_error(handler, status, body):
        text = body.decode("utf-8", errors="replace")
        if len(text) > ERROR_LOG_LIMIT:
            text = f"{text[:ERROR_LOG_LIMIT]}... <truncated>"
        handler.log_message("upstream Google Gemini returned %s: %s", status, text)

    def add_choice_indexes(payload):
        if isinstance(payload, list):
            return [add_choice_indexes(entry) for entry in payload]
        if not isinstance(payload, dict):
            return payload
        choices = payload.get("choices")
        if isinstance(choices, list):
            for index, choice in enumerate(choices):
                if isinstance(choice, dict) and "index" not in choice:
                    choice["index"] = index
                if isinstance(choice, dict):
                    for container_key in ("delta", "message"):
                        container = choice.get(container_key)
                        if not isinstance(container, dict):
                            continue
                        tool_calls = container.get("tool_calls")
                        if isinstance(tool_calls, list):
                            for tool_index, tool_call in enumerate(tool_calls):
                                if isinstance(tool_call, dict) and "index" not in tool_call:
                                    tool_call["index"] = tool_index
        return payload

    def normalize_openai_json_body(body):
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception:
            return body
        payload = add_choice_indexes(payload)
        return json.dumps(payload, separators=(",", ":")).encode("utf-8")

    def normalize_openai_sse_line(line):
        if line.endswith(b"\r\n"):
            suffix = b"\r\n"
            body = line[:-2]
        elif line.endswith(b"\n"):
            suffix = b"\n"
            body = line[:-1]
        else:
            suffix = b""
            body = line

        if not body.startswith(b"data:"):
            return line

        data = body[len(b"data:"):].strip()
        if not data or data == b"[DONE]":
            return line

        try:
            payload = json.loads(data.decode("utf-8"))
        except Exception:
            return line

        payload = add_choice_indexes(payload)
        return b"data: " + json.dumps(payload, separators=(",", ":")).encode("utf-8") + suffix

    class ProxyHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def do_GET(self):
            self.forward()

        def do_POST(self):
            self.forward()

        def log_message(self, fmt, *args):
            print(f"{self.address_string()} - {fmt % args}", flush=True)

        def forward(self):
            body = self.rfile.read(int(self.headers.get("Content-Length", "0") or "0"))
            stream_request = False
            if self.path.endswith("/chat/completions") and body:
                try:
                    payload = json.loads(body.decode("utf-8"))
                    stream_request = payload.get("stream") is True
                    payload = sanitize_openai_payload(payload)
                    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
                except Exception as exc:
                    self.send_error(400, f"Invalid JSON payload: {exc}")
                    return

            headers = {
                key: value
                for key, value in self.headers.items()
                if key.lower() not in HOP_BY_HOP_HEADERS
                and key.lower() not in {"host", "content-length", "accept-encoding"}
            }
            headers["Host"] = TARGET_HOST
            headers["Content-Length"] = str(len(body))
            headers["Accept-Encoding"] = "identity"

            connection = http.client.HTTPSConnection(TARGET_HOST, timeout=600)
            try:
                try:
                    connection.request(self.command, self.path, body=body, headers=headers)
                    response = connection.getresponse()
                except socket.timeout:
                    write_json_error(self, 504, "Timed out while forwarding request to Google Gemini.")
                    return
                except (OSError, http.client.HTTPException) as exc:
                    write_json_error(self, 502, f"Failed to forward request to Google Gemini: {exc}")
                    return

                self.send_response(response.status, response.reason)
                response_headers = response.getheaders()
                if response.status >= 400:
                    response_body = response.read()
                    log_upstream_error(self, response.status, response_body)
                    for key, value in response_headers:
                        if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() != "content-length":
                            self.send_header(key, value)
                    self.send_header("Content-Length", str(len(response_body)))
                    self.send_header("Connection", "close")
                    self.end_headers()
                    self.close_connection = True
                    self.wfile.write(response_body)
                    return

                if stream_request:
                    for key, value in response_headers:
                        if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() not in {"content-length", "content-encoding"}:
                            self.send_header(key, value)
                    self.send_header("Connection", "close")
                    self.end_headers()
                    self.close_connection = True

                    try:
                        while True:
                            chunk = response.readline()
                            if not chunk:
                                break
                            self.wfile.write(normalize_openai_sse_line(chunk))
                            self.wfile.flush()
                    except (BrokenPipeError, ConnectionResetError):
                        return
                    return

                response_body = normalize_openai_json_body(response.read())
                for key, value in response_headers:
                    if key.lower() not in HOP_BY_HOP_HEADERS and key.lower() not in {"content-length", "content-encoding"}:
                        self.send_header(key, value)
                self.send_header("Content-Length", str(len(response_body)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.close_connection = True
                self.wfile.write(response_body)
            finally:
                connection.close()

    if __name__ == "__main__":
        print(f"gemini-openai-schema-proxy listening on {LISTEN_HOST}:{LISTEN_PORT}", flush=True)
        ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), ProxyHandler).serve_forever()
  '';
  tensorzeroConfig = pkgs.writeText "tensorzero.toml" ''
    [gateway]
    bind_address = "0.0.0.0:3000"

    [models.agent-fast]
    routing = ["zai-glm-4.7", "gemma-google", "gemini-google", "qwen-3-235b-a22b-instruct-2507", "gpt-oss-cerebras", "gpt-oss-groq", "nemotron-free"]

    [models.agent-fast.providers."zai-glm-4.7"]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "zai-glm-4.7"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-fast.providers.gemma-google]
    ${googleOpenAIProvider "gemma-4-31b-it"}

    [models.agent-fast.providers.gemini-google]
    ${googleOpenAIProvider "gemini-3.1-flash-lite-preview"}

    [models.agent-fast.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-fast.providers.gpt-oss-cerebras]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "gpt-oss-120b"
    api_key_location = "env::CEREBRAS_API_KEY"
    extra_body = [
        { pointer = "/max_tokens", value = 2048 }
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
    routing = ["deepseek-nvidia", "qwen-3-235b-a22b-instruct-2507", "gemini-google", "nemotron-free", "gemma-google", "minimax-free","gpt-oss-groq"]

    [models.agent-smart.providers.deepseek-nvidia]
    type = "openai"
    api_base = "https://integrate.api.nvidia.com/v1"
    model_name = "deepseek-ai/deepseek-v4-pro"
    api_key_location = "env::NVIDIA_API_KEY"
    timeouts = { non_streaming.total_ms = 30000, streaming.ttft_ms = 10000, streaming.total_ms = 120000 }

    [models.agent-smart.providers.qwen-3-235b-a22b-instruct-2507]
    type = "openai"
    api_base = "https://api.cerebras.ai/v1"
    model_name = "qwen-3-235b-a22b-instruct-2507"
    api_key_location = "env::CEREBRAS_API_KEY"

    [models.agent-smart.providers.gemini-google]
    ${googleOpenAIProvider "gemini-3-flash-preview"}

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
    ${googleOpenAIProvider "gemma-4-31b-it"}

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

  environment.systemPackages = with pkgs; [
      (lib.hiPrio (pkgs.writeShellScriptBin "openclaw" ''
        export OPENCLAW_GATEWAY_TOKEN="$(cat ${config.sops.secrets.openclaw_gateway_token.path})"
        export OPENCLAW_NIX_MODE=1
        exec ${openclawPkg}/bin/openclaw "$@"
      ''))
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

  sops.secrets.openclaw_gateway_token = {
    sopsFile = ./secrets.yaml;
    owner = "ruben";
  };

  sops.secrets.openclaw_telegram_token = {
    sopsFile = ./secrets.yaml;
    owner = "openclaw";
  };

  systemd.services.gemini-openai-schema-proxy = {
    description = "Gemini OpenAI-compatible schema sanitizer proxy";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      GEMINI_OPENAI_PROXY_PORT = toString geminiOpenAIProxyPort;
    };
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${geminiSchemaProxy}";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  systemd.services.openclaw-gateway = {
    after = [ "gemini-openai-schema-proxy.service" ];
    wants = [ "gemini-openai-schema-proxy.service" ];
  };

  systemd.services.podman-tensorzero = {
    after = [ "gemini-openai-schema-proxy.service" ];
    wants = [ "gemini-openai-schema-proxy.service" ];
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
        extraOptions = [ "--network=host" ];
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
