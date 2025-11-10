defmodule AtomVMWasiTest do
  use ExUnit.Case

  @moduletag :skip

  @atomvm_dir System.get_env("ATOMVM_DIR", "/home/joshadams/src/github.com/atomvm/AtomVM")
  @wasmtime_bin System.get_env("WASMTIME_BIN", "/home/joshadams/.wasmtime/bin/wasmtime")
  @atomvm_wasm "build-wasi/src/platforms/wasi/AtomVM.wasm"
  @test_beam "test_tcp_socket.beam"

  setup_all do
    # Verify files exist
    atomvm_path = Path.join(@atomvm_dir, @atomvm_wasm)
    test_path = Path.join([@atomvm_dir, "tests/wasi", @test_beam])

    unless File.exists?(atomvm_path) do
      raise """
      AtomVM.wasm not found at: #{atomvm_path}

      Please build it first or set ATOMVM_DIR environment variable:
        export ATOMVM_DIR=/path/to/AtomVM
        cd $ATOMVM_DIR
        export WASI_SDK_PATH=/path/to/wasi-sdk
        just wasi-build
      """
    end

    unless File.exists?(test_path) do
      raise """
      test_tcp_socket.beam not found at: #{test_path}

      Please compile it first:
        cd #{@atomvm_dir}
        erlc -o tests/wasi/ tests/wasi/test_tcp_socket.erl
      """
    end

    unless File.exists?(@wasmtime_bin) do
      raise """
      wasmtime not found at: #{@wasmtime_bin}

      Please install it:
        curl https://wasmtime.dev/install.sh -sSf | bash
      """
    end

    # Start echo server on port 8080 (required by AtomVM test)
    case :gen_tcp.listen(8080, [:binary, {:active, false}, {:reuseaddr, true}]) do
      {:ok, server} ->
        acceptor = spawn(fn -> echo_server_loop(server) end)

        on_exit(fn ->
          Process.exit(acceptor, :kill)
          :gen_tcp.close(server)
        end)

        {:ok, %{server: server, port: 8080}}

      {:error, :eaddrinuse} ->
        raise """
        Port 8080 is already in use!

        The AtomVM test hardcodes port 8080 for its echo test.

        To find what's using it:
          lsof -i :8080

        To kill it (if it's safe):
          pkill -f 'socat.*8080'
          # or kill the specific PID

        Then re-run the test.
        """
    end
  end

  describe "AtomVM WASI networking via wasmtime" do
    test "TCP echo test with wasmtime CLI" do
      # Give the echo server a moment to start
      Process.sleep(100)

      # Run wasmtime with AtomVM
      # WASI Preview 2 flags:
      # -Sinherit-network: Allow WASM to access host's network
      # -Sallow-ip-name-lookup: Enable DNS resolution
      # -Stcp: Enable TCP socket support
      {output, exit_code} =
        System.cmd(
          @wasmtime_bin,
          [
            "run",
            "-Sinherit-network",
            "-Sallow-ip-name-lookup",
            "-Stcp",
            "--dir=tests/wasi::.",
            @atomvm_wasm,
            @test_beam
          ],
          cd: @atomvm_dir,
          stderr_to_stdout: true
        )

      # Check exit code
      if exit_code != 0 do
        IO.puts("\n=== wasmtime output ===")
        IO.puts(output)
        IO.puts("======================\n")
      end

      assert exit_code == 0,
             "wasmtime exited with code #{exit_code}. See output above."

      # Check output contains expected success messages
      assert output =~ "TEST PASSED" or output =~ "Echo verified",
             "Test did not pass. Output:\n#{output}"

      # Additional checks
      assert output =~ "Connecting to 127.0.0.1:8080",
             "Connection attempt not found in output"
    end

    test "verify AtomVM component structure" do
      # This test just verifies we can inspect the component
      # (requires wasm-tools, but we'll skip if not available)

      case System.cmd("which", ["wasm-tools"], stderr_to_stdout: true) do
        {_, 0} ->
          atomvm_path = Path.join(@atomvm_dir, @atomvm_wasm)

          {output, exit_code} =
            System.cmd("wasm-tools", ["component", "wit", atomvm_path], stderr_to_stdout: true)

          assert exit_code == 0, "wasm-tools failed: #{output}"

          # Should have socket imports
          assert output =~ ~r/wasi:sockets\/tcp/,
                 "AtomVM.wasm missing wasi:sockets/tcp import"

          assert output =~ ~r/wasi:sockets\/network/,
                 "AtomVM.wasm missing wasi:sockets/network import"

          # Should NOT have old-style env:: imports
          refute output =~ ~r/env::/,
                 "AtomVM.wasm has old-style env:: imports (built with wrong target?)"

        _ ->
          # wasm-tools not installed, skip this test
          :ok
      end
    end
  end

  # Echo server implementation
  defp echo_server_loop(server) do
    case :gen_tcp.accept(server, 1000) do
      {:ok, client} ->
        # Spawn handler for this client
        spawn(fn -> handle_echo_client(client) end)
        echo_server_loop(server)

      {:error, :timeout} ->
        # No connection, keep listening
        echo_server_loop(server)

      {:error, :closed} ->
        # Server closed, exit loop
        :ok

      {:error, reason} ->
        IO.puts("Echo server accept failed: #{inspect(reason)}")
        echo_server_loop(server)
    end
  end

  defp handle_echo_client(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, data} ->
        # Echo back the data
        :gen_tcp.send(socket, data)
        :gen_tcp.close(socket)

      {:error, :timeout} ->
        IO.puts("Echo server recv timeout")
        :gen_tcp.close(socket)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        IO.puts("Echo server recv failed: #{inspect(reason)}")
        :gen_tcp.close(socket)
    end
  end
end
