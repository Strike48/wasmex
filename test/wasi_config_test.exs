defmodule Wasmex.WasiConfigTest do
  use ExUnit.Case, async: true

  alias Wasmex.Wasi.WasiP2Options

  describe "WasiP2Options config configuration" do
    test "config_vars field has correct default" do
      opts = %WasiP2Options{}
      assert opts.config_vars == %{}
    end

    test "config_vars can be set" do
      opts = %WasiP2Options{
        config_vars: %{
          "database_url" => "postgres://localhost/mydb",
          "api_key" => "secret123"
        }
      }

      assert opts.config_vars["database_url"] == "postgres://localhost/mydb"
      assert opts.config_vars["api_key"] == "secret123"
    end
  end

  describe "runtime config operations" do
    test "can get a single config value" do
      component_bytes = File.read!(TestHelper.wasi_config_test_file_path())

      wasi_opts = %WasiP2Options{
        config_vars: %{
          "database_url" => "postgres://localhost/mydb",
          "api_key" => "secret123",
          "port" => "8080"
        }
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      # Test getting database_url
      result = Wasmex.Components.call_function(pid, "test-get-config", ["database_url"])
      assert {:ok, {:ok, "postgres://localhost/mydb"}} = result

      # Test getting api_key
      result = Wasmex.Components.call_function(pid, "test-get-config", ["api_key"])
      assert {:ok, {:ok, "secret123"}} = result

      # Test getting port
      result = Wasmex.Components.call_function(pid, "test-get-config", ["port"])
      assert {:ok, {:ok, "8080"}} = result
    end

    test "returns error for non-existent config key" do
      component_bytes = File.read!(TestHelper.wasi_config_test_file_path())

      wasi_opts = %WasiP2Options{
        config_vars: %{
          "existing_key" => "value"
        }
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      result = Wasmex.Components.call_function(pid, "test-get-config", ["nonexistent_key"])
      assert {:ok, {:error, error_msg}} = result
      assert error_msg =~ "not found"
    end

    test "can get all config values" do
      component_bytes = File.read!(TestHelper.wasi_config_test_file_path())

      wasi_opts = %WasiP2Options{
        config_vars: %{
          "key1" => "value1",
          "key2" => "value2",
          "key3" => "value3"
        }
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      result = Wasmex.Components.call_function(pid, "test-get-all-config", [])
      assert {:ok, {:ok, config_string}} = result

      # Parse the comma-separated key=value pairs
      pairs = String.split(config_string, ",")
      assert length(pairs) == 3

      # Convert to map for easier assertion
      config_map =
        pairs
        |> Enum.map(fn pair ->
          [key, value] = String.split(pair, "=", parts: 2)
          {key, value}
        end)
        |> Enum.into(%{})

      assert config_map["key1"] == "value1"
      assert config_map["key2"] == "value2"
      assert config_map["key3"] == "value3"
    end

    test "get-all returns empty when no config vars are set" do
      component_bytes = File.read!(TestHelper.wasi_config_test_file_path())

      wasi_opts = %WasiP2Options{
        config_vars: %{}
      }

      pid =
        start_supervised!(
          {Wasmex.Components, bytes: component_bytes, wasi: wasi_opts}
        )

      result = Wasmex.Components.call_function(pid, "test-get-all-config", [])
      assert {:ok, {:ok, ""}} = result
    end

    test "works without wasi options (default empty config)" do
      component_bytes = File.read!(TestHelper.wasi_config_test_file_path())

      # Start without any wasi options - should use defaults
      pid = start_supervised!({Wasmex.Components, bytes: component_bytes})

      # Getting a key should return not found
      result = Wasmex.Components.call_function(pid, "test-get-config", ["any_key"])
      assert {:ok, {:error, error_msg}} = result
      assert error_msg =~ "not found"

      # Getting all should return empty
      result = Wasmex.Components.call_function(pid, "test-get-all-config", [])
      assert {:ok, {:ok, ""}} = result
    end
  end
end
