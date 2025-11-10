defmodule Wasmex.WasiKeyvalueTest do
  use ExUnit.Case, async: true

  alias Wasmex.Wasi.WasiP2Options

  describe "WasiP2Options keyvalue configuration" do
    test "allow_keyvalue field has correct default" do
      opts = %WasiP2Options{}
      assert opts.allow_keyvalue == false
    end

    test "allow_keyvalue can be enabled" do
      opts = %WasiP2Options{
        allow_keyvalue: true
      }

      assert opts.allow_keyvalue == true
    end
  end

  describe "keyvalue operations" do
    test "can set and get a value" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      pid =
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})

      # Test setting and getting a simple string
      result = Wasmex.Components.call_function(pid, "test-set-get", ["mykey", "myvalue"])
      assert {:ok, {:ok, "myvalue"}} = result
    end

    test "can set, get, and overwrite values" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      pid =
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})

      # Set initial value
      result = Wasmex.Components.call_function(pid, "test-set-get", ["key1", "value1"])
      assert {:ok, {:ok, "value1"}} = result

      # Overwrite with new value
      result = Wasmex.Components.call_function(pid, "test-set-get", ["key1", "value2"])
      assert {:ok, {:ok, "value2"}} = result
    end

    test "can check if key exists" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      pid =
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})

      # Check non-existent key
      result = Wasmex.Components.call_function(pid, "test-exists", ["nonexistent"])
      assert {:ok, {:ok, false}} = result

      # Set a key
      _result = Wasmex.Components.call_function(pid, "test-set-get", ["existingkey", "value"])

      # Check it exists
      result = Wasmex.Components.call_function(pid, "test-exists", ["existingkey"])
      assert {:ok, {:ok, true}} = result
    end

    test "can delete a key" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      pid =
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})

      # Set a key
      _result = Wasmex.Components.call_function(pid, "test-set-get", ["deletekey", "value"])

      # Verify it exists
      result = Wasmex.Components.call_function(pid, "test-exists", ["deletekey"])
      assert {:ok, {:ok, true}} = result

      # Delete it
      result = Wasmex.Components.call_function(pid, "test-delete", ["deletekey"])
      assert {:ok, {:ok, "Successfully deleted"}} = result

      # Verify it's gone
      result = Wasmex.Components.call_function(pid, "test-exists", ["deletekey"])
      assert {:ok, {:ok, false}} = result
    end

    test "delete returns appropriate message for non-existent key" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      pid =
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})

      # Delete non-existent key
      result = Wasmex.Components.call_function(pid, "test-delete", ["nonexistent"])
      assert {:ok, {:ok, "Key did not exist"}} = result
    end

    test "keyvalue store is isolated per instance" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      wasi_opts = %WasiP2Options{
        allow_keyvalue: true
      }

      # Start two separate instances
      pid1 =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts},
          id: :instance1
        )

      pid2 =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts},
          id: :instance2
        )

      # Set value in instance 1
      _result = Wasmex.Components.call_function(pid1, "test-set-get", ["sharedkey", "value1"])

      # Set different value in instance 2
      _result = Wasmex.Components.call_function(pid2, "test-set-get", ["sharedkey", "value2"])

      # Verify each instance has its own value
      result1 = Wasmex.Components.call_function(pid1, "test-set-get", ["sharedkey", "value1"])
      assert {:ok, {:ok, "value1"}} = result1

      result2 = Wasmex.Components.call_function(pid2, "test-set-get", ["sharedkey", "value2"])
      assert {:ok, {:ok, "value2"}} = result2
    end

    test "fails gracefully when keyvalue is not enabled" do
      component_bytes = File.read!(TestHelper.wasi_keyvalue_test_file_path())

      # Don't enable keyvalue
      wasi_opts = %WasiP2Options{
        allow_keyvalue: false
      }

      # Starting the component should fail because it imports keyvalue functions
      assert_raise RuntimeError, ~r/component imports function `kv-get`/, fn ->
        start_supervised!({Wasmex.Components, bytes: component_bytes, wasi: wasi_opts})
      end
    end
  end
end
