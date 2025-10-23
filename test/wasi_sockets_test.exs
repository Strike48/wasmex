defmodule Wasmex.WasiSocketsTest do
  use ExUnit.Case, async: true

  alias Wasmex.Wasi.WasiP2Options

  describe "WasiP2Options socket configuration" do
    test "allow_sockets enables socket support" do
      component_bytes = File.read!(TestHelper.component_type_conversions_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true,
        allow_tcp: true,
        allow_udp: true
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      assert is_pid(pid)
    end

    test "allow_sockets with TCP only" do
      component_bytes = File.read!(TestHelper.component_type_conversions_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true,
        allow_tcp: true,
        allow_udp: false
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      assert is_pid(pid)
    end

    test "allow_sockets with UDP only" do
      component_bytes = File.read!(TestHelper.component_type_conversions_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true,
        allow_tcp: false,
        allow_udp: true
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      assert is_pid(pid)
    end

    test "allow_http enables network with TCP/UDP control" do
      component_bytes = File.read!(TestHelper.component_type_conversions_file_path())

      wasi_opts = %WasiP2Options{
        allow_http: true,
        allow_tcp: true,
        allow_udp: false
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      assert is_pid(pid)
    end

    test "defaults work correctly" do
      component_bytes = File.read!(TestHelper.component_type_conversions_file_path())

      # Default: allow_sockets=false, allow_tcp=true, allow_udp=true
      wasi_opts = %WasiP2Options{}

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      assert is_pid(pid)
    end

    test "socket fields have correct defaults" do
      opts = %WasiP2Options{}

      assert opts.allow_sockets == false
      assert opts.allow_tcp == true
      assert opts.allow_udp == true
    end
  end
end
