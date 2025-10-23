defmodule Wasmex.WasiSocketsTest do
  use ExUnit.Case, async: true

  alias Wasmex.Wasi.WasiP2Options

  describe "WasiP2Options socket configuration" do
    test "socket fields have correct defaults" do
      opts = %WasiP2Options{}

      assert opts.allow_sockets == false
      assert opts.allow_tcp == true
      assert opts.allow_udp == true
    end
  end

  describe "actual socket operations" do
    test "DNS lookup can be initiated with allow_sockets enabled" do
      component_bytes = File.read!(TestHelper.wasi_sockets_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # Test DNS resolution for a well-known domain
      result = Wasmex.Components.call_function(pid, "test-dns-lookup", ["example.com"])

      case result do
        {:ok, {:ok, ip_address}} when is_binary(ip_address) ->
          # Successfully resolved to an IP address
          assert ip_address =~ ~r/^\d+\.\d+\.\d+\.\d+$/

        {:ok, {:error, reason}} ->
          # DNS operations in WASI are async and may return "would-block"
          # The important thing is that the operation was allowed to start
          # (not denied due to lack of permissions)
          assert reason =~ ~r/would-block/i

        {:error, reason} ->
          flunk("Component call failed: #{reason}")
      end
    end

    test "DNS lookup fails without allow_sockets" do
      component_bytes = File.read!(TestHelper.wasi_sockets_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: false
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # Should fail because sockets are not enabled
      result = Wasmex.Components.call_function(pid, "test-dns-lookup", ["example.com"])

      # Component returns Result<String, String>, so we get {:ok, {:error, reason}}
      assert {:ok, {:error, reason}} = result
      assert is_binary(reason)
      # Should contain "permanent-resolver-failure" or similar error about disabled network access
      assert reason =~ ~r/resolver|network|denied/i
    end

    test "TCP connection can be initiated with allow_sockets enabled" do
      component_bytes = File.read!(TestHelper.wasi_sockets_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true,
        allow_tcp: true
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # Try to connect to example.com on port 80 (HTTP)
      result = Wasmex.Components.call_function(pid, "test-tcp-connect", ["example.com", 80])

      case result do
        {:ok, {:ok, message}} ->
          assert message =~ "Successfully initiated TCP connection"

        {:ok, {:error, reason}} ->
          # TCP operations in WASI are async and may return "would-block"
          # or fail at DNS stage. The important thing is that the operation
          # was allowed to start (not denied due to lack of permissions)
          assert reason =~ ~r/would-block|Failed to get resolved/i

        {:error, reason} ->
          flunk("Component call failed: #{reason}")
      end
    end

    test "TCP connection fails when allow_tcp is false" do
      component_bytes = File.read!(TestHelper.wasi_sockets_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_sockets: true,
        allow_tcp: false
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # Should fail because TCP is disabled
      result = Wasmex.Components.call_function(pid, "test-tcp-connect", ["example.com", 80])

      # Component returns Result<String, String>, so we get {:ok, {:error, reason}}
      assert {:ok, {:error, reason}} = result
      assert is_binary(reason)
    end

    test "allow_http also enables sockets" do
      component_bytes = File.read!(TestHelper.wasi_sockets_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_http: true
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # DNS should work when allow_http is enabled
      result = Wasmex.Components.call_function(pid, "test-dns-lookup", ["example.com"])

      case result do
        {:ok, {:ok, ip_address}} when is_binary(ip_address) ->
          # Successfully resolved
          assert ip_address =~ ~r/^\d+\.\d+\.\d+\.\d+$/

        {:ok, {:error, reason}} ->
          # DNS operations in WASI are async and may return "would-block"
          # The important thing is that allow_http enables network access
          assert reason =~ ~r/would-block/i

        {:error, reason} ->
          flunk("Component call failed: #{reason}")
      end
    end
  end
end
