defmodule GeoserverConfig.ConnectionTest do
  use ExUnit.Case, async: true

  alias GeoserverConfig.Connection

  describe "new/3" do
    test "creates a Connection with the given values" do
      conn = Connection.new("http://localhost:8080/geoserver/rest", "admin", "secret")

      assert conn.base_url == "http://localhost:8080/geoserver/rest"
      assert conn.username == "admin"
      assert conn.password == "secret"
      assert conn.plug == nil
    end

    test "raises FunctionClauseError when base_url is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Connection.new(1234, "admin", "secret")
      end
    end

    test "raises FunctionClauseError when username is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Connection.new("http://localhost", :admin, "secret")
      end
    end

    test "raises FunctionClauseError when password is not a binary" do
      assert_raise FunctionClauseError, fn ->
        Connection.new("http://localhost", "admin", nil)
      end
    end
  end

  describe "from_env/1" do
    test "reads default GEOSERVER_ prefix variables" do
      System.put_env("GEOSERVER_BASE_URL", "http://env.example.com/rest")
      System.put_env("GEOSERVER_USERNAME", "env_user")
      System.put_env("GEOSERVER_PASSWORD", "env_pass")

      conn = Connection.from_env()

      assert conn.base_url == "http://env.example.com/rest"
      assert conn.username == "env_user"
      assert conn.password == "env_pass"
    after
      System.delete_env("GEOSERVER_BASE_URL")
      System.delete_env("GEOSERVER_USERNAME")
      System.delete_env("GEOSERVER_PASSWORD")
    end

    test "reads a custom prefix" do
      System.put_env("STAGING_BASE_URL", "http://staging.example.com/rest")
      System.put_env("STAGING_USERNAME", "staging_user")
      System.put_env("STAGING_PASSWORD", "staging_pass")

      conn = Connection.from_env(prefix: "STAGING")

      assert conn.base_url == "http://staging.example.com/rest"
      assert conn.username == "staging_user"
    after
      System.delete_env("STAGING_BASE_URL")
      System.delete_env("STAGING_USERNAME")
      System.delete_env("STAGING_PASSWORD")
    end

    test "raises System.EnvError when a required variable is missing" do
      System.delete_env("GEOSERVER_BASE_URL")
      System.delete_env("GEOSERVER_USERNAME")
      System.delete_env("GEOSERVER_PASSWORD")

      assert_raise System.EnvError, fn ->
        Connection.from_env()
      end
    end
  end

  describe "from_application_env/2" do
    test "reads from application config with default key :geoserver" do
      Application.put_env(:geoserver_config, :geoserver,
        base_url: "http://appenv.example.com/rest",
        username: "app_user",
        password: "app_pass"
      )

      conn = Connection.from_application_env(:geoserver_config)

      assert conn.base_url == "http://appenv.example.com/rest"
      assert conn.username == "app_user"
      assert conn.password == "app_pass"
    after
      Application.delete_env(:geoserver_config, :geoserver)
    end

    test "reads from application config with a custom key" do
      Application.put_env(:geoserver_config, :geo_api,
        base_url: "http://custom.example.com/rest",
        username: "custom_user",
        password: "custom_pass"
      )

      conn = Connection.from_application_env(:geoserver_config, :geo_api)

      assert conn.base_url == "http://custom.example.com/rest"
    after
      Application.delete_env(:geoserver_config, :geo_api)
    end

    test "raises ArgumentError when a required key is nil" do
      Application.put_env(:geoserver_config, :geoserver,
        base_url: "http://appenv.example.com/rest",
        username: nil,
        password: "app_pass"
      )

      assert_raise ArgumentError, ~r/:username/, fn ->
        Connection.from_application_env(:geoserver_config)
      end
    after
      Application.delete_env(:geoserver_config, :geoserver)
    end

    test "raises ArgumentError when the app config key is not set at all" do
      Application.delete_env(:geoserver_config, :geoserver)

      # Application.fetch_env!/2 raises ArgumentError in Elixir 1.17+
      assert_raise ArgumentError, fn ->
        Connection.from_application_env(:geoserver_config)
      end
    end
  end

  describe "auth/1" do
    test "returns a basic auth tuple" do
      conn = Connection.new("http://localhost", "admin", "secret")
      assert Connection.auth(conn) == {:basic, "admin:secret"}
    end

    test "handles passwords that contain colons" do
      conn = Connection.new("http://localhost", "admin", "p:a:s:s")
      assert Connection.auth(conn) == {:basic, "admin:p:a:s:s"}
    end
  end

  describe "req_opts/1" do
    test "returns only auth when plug is nil" do
      conn = Connection.new("http://localhost", "admin", "secret")
      opts = Connection.req_opts(conn)

      assert opts[:auth] == {:basic, "admin:secret"}
      refute Keyword.has_key?(opts, :plug)
    end

    test "includes plug when set" do
      conn = %Connection{
        base_url: "http://localhost",
        username: "admin",
        password: "secret",
        plug: {Req.Test, :my_stub}
      }

      opts = Connection.req_opts(conn)

      assert opts[:auth] == {:basic, "admin:secret"}
      assert opts[:plug] == {Req.Test, :my_stub}
    end
  end
end
