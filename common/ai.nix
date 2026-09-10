{ config, lib, pkgs, ... }:

let
  airllmVersion = "3.3.0";
  airllmTorchVersion = "2.7.1";
  airllmTransformersVersion = "5.12.0";
  airllmUsesCuda = lib.elem "nvidia" config.services.xserver.videoDrivers;
  airllmBackend = if airllmUsesCuda then "cu118" else "cpu";
  airllmDevice = if airllmUsesCuda then "cuda:0" else "cpu";
  airllmTorchWheel =
    if airllmUsesCuda then
      "https://download.pytorch.org/whl/cu118/torch-${airllmTorchVersion}%2Bcu118-cp312-cp312-manylinux_2_28_x86_64.whl"
    else
      "https://download.pytorch.org/whl/cpu/torch-${airllmTorchVersion}%2Bcpu-cp312-cp312-manylinux_2_28_x86_64.whl";
  airllm = pkgs.writeShellApplication {
    name = "airllm";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.uv
    ];
    text = ''
      state_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/airllm"
      environment_dir="$state_dir/${airllmVersion}-${airllmBackend}-py312"
      marker="$environment_dir/.nixos-config-ready"
      expected_marker="${airllmVersion}:${airllmTorchVersion}:${airllmTransformersVersion}:${airllmBackend}:${pkgs.python312}"

      mkdir -p "$state_dir"
      exec 9>"$state_dir/.bootstrap.lock"
      flock 9

      current_marker=""
      if [[ -f "$marker" ]]; then
        current_marker="$(<"$marker")"
      fi

      if [[ ! -x "$environment_dir/bin/python" || "$current_marker" != "$expected_marker" ]]; then
        echo "Preparing AirLLM ${airllmVersion} (${airllmBackend}); only pre-built wheels are allowed..." >&2
        uv venv --clear --python "${pkgs.python312}/bin/python3" "$environment_dir"
        UV_PYTHON_DOWNLOADS=never uv pip install \
          --python "$environment_dir/bin/python" \
          --only-binary :all: \
          "airllm==${airllmVersion}" \
          "torch @ ${airllmTorchWheel}" \
          "transformers==${airllmTransformersVersion}"
        printf '%s\n' "$expected_marker" > "$marker"
      fi

      flock --unlock 9

      # AirLLM is a Python library rather than a CLI. This command is its
      # isolated Python interpreter; scripts can use AIRLLM_DEVICE directly.
      export AIRLLM_DEVICE="${airllmDevice}"
      export LD_LIBRARY_PATH="${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ${lib.optionalString airllmUsesCuda ''
        export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ''}
      exec "$environment_dir/bin/python" "$@"
    '';
  };
in
{
  environment.systemPackages = [ airllm ];

  sops.secrets.ai_agents_env = {
    sopsFile = ./secrets.yaml;
    owner = "ruben";
    mode = "0400";
  };
}
