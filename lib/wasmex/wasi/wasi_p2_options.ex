defmodule Wasmex.Wasi.WasiP2Options do
  @moduledoc ~S"""
  Configures WASI P2 support for a Wasmex.Components.Store.

  WASI (WebAssembly System Interface) P2 provides system interface capabilities
  to WebAssembly components, allowing them to interact with the host system in a
  controlled manner.

  ## Options

    * `:inherit_stdin` - When `true`, allows the component to read from standard input.
      Defaults to `true`.

    * `:inherit_stdout` - When `true`, allows the component to write to standard output.
      Defaults to `true`.

    * `:inherit_stderr` - When `true`, allows the component to write to standard error.
      Defaults to `true`.

    * `:allow_http` - When `true`, enables HTTP capabilities for the component.
      Defaults to `false`.

    * `:allow_sockets` - When `true`, enables socket capabilities (TCP/UDP) for the component.
      Defaults to `false`.

    * `:allow_tcp` - When `true`, allows TCP socket operations. Only takes effect when
      `:allow_sockets` or `:allow_http` is `true`. Defaults to `true`.

    * `:allow_udp` - When `true`, allows UDP socket operations. Only takes effect when
      `:allow_sockets` or `:allow_http` is `true`. Defaults to `true`.

    * `:allow_keyvalue` - When `true`, enables an in-memory key-value store for the component.
      The store is isolated per component instance. Defaults to `false`.

    * `:args` - List of command-line arguments to pass to the component.
      Defaults to `[]`.

    * `:env` - Map of environment variables to make available to the component.
      Defaults to `%{}`.

    * `:config_vars` - Map of runtime configuration variables accessible via `wasi:config/runtime`.
      These are separate from environment variables and designed for application configuration.
      Defaults to `%{}`.

  ## Example

      iex> wasi_opts = %Wasmex.Wasi.WasiP2Options{
      ...>   args: ["--verbose"],
      ...>   env: %{"DEBUG" => "1"},
      ...>   allow_http: true
      ...> }
      iex> {:ok, pid} = Wasmex.Components.start_link(%{
      ...>   path: "my_component.wasm",
      ...>   wasi: wasi_opts
      ...> })

  ## Socket Example

      iex> wasi_opts = %Wasmex.Wasi.WasiP2Options{
      ...>   allow_sockets: true,
      ...>   allow_tcp: true,
      ...>   allow_udp: false
      ...> }
      iex> {:ok, pid} = Wasmex.Components.start_link(%{
      ...>   path: "tcp_client.wasm",
      ...>   wasi: wasi_opts
      ...> })

  ## Runtime Configuration Example

      iex> wasi_opts = %Wasmex.Wasi.WasiP2Options{
      ...>   config_vars: %{
      ...>     "database_url" => "postgres://localhost/mydb",
      ...>     "api_key" => "secret123",
      ...>     "feature_flags" => "new_ui,beta_features"
      ...>   }
      ...> }
      iex> {:ok, pid} = Wasmex.Components.start_link(%{
      ...>   path: "my_app.wasm",
      ...>   wasi: wasi_opts
      ...> })

  """

  defstruct inherit_stdin: true,
            inherit_stdout: true,
            inherit_stderr: true,
            allow_http: false,
            allow_sockets: false,
            allow_tcp: true,
            allow_udp: true,
            allow_keyvalue: false,
            args: [],
            env: %{},
            config_vars: %{}

  @type t :: %__MODULE__{
          args: [String.t()],
          env: %{String.t() => String.t()},
          config_vars: %{String.t() => String.t()},
          inherit_stdin: boolean(),
          inherit_stdout: boolean(),
          inherit_stderr: boolean(),
          allow_http: boolean(),
          allow_sockets: boolean(),
          allow_tcp: boolean(),
          allow_udp: boolean(),
          allow_keyvalue: boolean()
        }
end
