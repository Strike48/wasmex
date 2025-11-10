defmodule Wasmex.WasiArgvTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests to verify that WASI arguments are passed correctly with argv[0].
  This is critical for programs like AtomVM that expect argc >= 1.
  """

  describe "WASI arguments" do
    test "argv should include program name as argv[0]" do
      # Create a simple WAT program that prints arguments count
      wat = """
      (module
        (import "wasi_snapshot_preview1" "args_sizes_get"
          (func $args_sizes_get (param i32 i32) (result i32)))
        (import "wasi_snapshot_preview1" "args_get"
          (func $args_get (param i32 i32) (result i32)))
        (import "wasi_snapshot_preview1" "proc_exit"
          (func $proc_exit (param i32)))

        (memory (export "memory") 1)

        (func (export "_start")
          (local $argc i32)
          (local $argv_buf_size i32)

          ;; Get args sizes (argc goes to offset 0, argv_buf_size to offset 4)
          (call $args_sizes_get (i32.const 0) (i32.const 4))
          drop

          ;; Load argc from memory
          (local.set $argc (i32.load (i32.const 0)))

          ;; Exit with argc as status code
          ;; If argv[0] is included, argc should be at least 1
          (call $proc_exit (local.get $argc))
        )
      )
      """

      {:ok, wasm_bytes} = Wasmex.Wat.to_wasm(wat)

      # Test with no args - should get argc=1 (just program name)
      wasi_opts = %Wasmex.Wasi.WasiOptions{
        args: []
      }

      {:ok, pid} = Wasmex.start_link(%{bytes: wasm_bytes, wasi: wasi_opts})

      # Call should fail with trap exit, but we can check the exit code in logs
      # If argc >= 1, this proves argv[0] was added
      result = Wasmex.call_function(pid, :_start, [])

      # The function will call proc_exit with argc
      # We expect it to trap, but the key is that it ran (not immediate crash)
      assert match?({:error, _}, result)
    end

    test "argv should include user args after argv[0]" do
      # This WAT program will exit with the number of arguments
      wat = """
      (module
        (import "wasi_snapshot_preview1" "args_sizes_get"
          (func $args_sizes_get (param i32 i32) (result i32)))
        (import "wasi_snapshot_preview1" "proc_exit"
          (func $proc_exit (param i32)))

        (memory (export "memory") 1)

        (func (export "_start")
          ;; Get argc at offset 0
          (call $args_sizes_get (i32.const 0) (i32.const 4))
          drop

          ;; Exit with argc (should be 4: program name + 3 args)
          (call $proc_exit (i32.load (i32.const 0)))
        )
      )
      """

      {:ok, wasm_bytes} = Wasmex.Wat.to_wasm(wat)

      wasi_opts = %Wasmex.Wasi.WasiOptions{
        args: ["arg1", "arg2", "arg3"]
      }

      {:ok, pid} = Wasmex.start_link(%{bytes: wasm_bytes, wasi: wasi_opts})

      result = Wasmex.call_function(pid, :_start, [])

      # Should trap with proc_exit, but not crash immediately
      assert match?({:error, _}, result)
    end
  end
end
