defmodule GeoserverConfig.Connection do
  @moduledoc """
  Holds authentication and connection configuration for a GeoServer instance.

  A `Connection` struct contains the base URL and credentials needed to communicate
  with GeoServer's REST API. Pass it as the first argument to every API function in
  this library. This makes the connection explicit and testable, allows multiple
  GeoServer instances in the same application, and avoids the pitfall of reading
  environment variables at compile time.

  ## Building a connection

  **From explicit values** — suitable for runtime-configured applications:

      conn = GeoserverConfig.Connection.new(
        "http://localhost:8080/geoserver/rest",
        "admin",
        "geoserver"
      )

  **From system environment variables** (read at runtime, never at compile time):

      # Reads GEOSERVER_BASE_URL, GEOSERVER_USERNAME, GEOSERVER_PASSWORD
      conn = GeoserverConfig.Connection.from_env()

      # Custom prefix, e.g. STAGING_GEOSERVER_BASE_URL
      conn = GeoserverConfig.Connection.from_env(prefix: "STAGING_GEOSERVER")

  **From your application's config** — mirrors the pattern used in `config/runtime.exs`:

      # config/runtime.exs
      config :my_app, :geoserver,
        base_url: System.get_env("GEOSERVER_BASE_URL"),
        username: System.get_env("GEOSERVER_USERNAME"),
        password: System.get_env("GEOSERVER_PASSWORD")

      # application code
      conn = GeoserverConfig.Connection.from_application_env(:my_app)
      conn = GeoserverConfig.Connection.from_application_env(:my_app, :geo_api)

  ## Usage

      conn = GeoserverConfig.Connection.from_env()
      {:ok, workspaces} = GeoserverConfig.Workspaces.fetch_workspaces(conn)
  """

  @enforce_keys [:base_url, :username, :password]
  defstruct [:base_url, :username, :password, plug: nil]

  @doc """
  Creates a `Connection` from explicit values.

  ## Example

      iex> GeoserverConfig.Connection.new("http://localhost:8080/geoserver/rest", "admin", "geoserver")
      %GeoserverConfig.Connection{base_url: "http://localhost:8080/geoserver/rest", username: "admin", password: "geoserver"}
  """
  def new(base_url, username, password)
      when is_binary(base_url) and is_binary(username) and is_binary(password) do
    %__MODULE__{base_url: base_url, username: username, password: password}
  end

  @doc """
  Creates a `Connection` by reading system environment variables at runtime.

  Raises `System.EnvError` if any required variable is missing.

  ## Options

    - `:prefix` — env var prefix (default: `"GEOSERVER"`).

  ## Variables read (with default prefix)

    - `GEOSERVER_BASE_URL`
    - `GEOSERVER_USERNAME`
    - `GEOSERVER_PASSWORD`

  ## Examples

      conn = GeoserverConfig.Connection.from_env()
      conn = GeoserverConfig.Connection.from_env(prefix: "STAGING_GEOSERVER")
  """
  def from_env(opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "GEOSERVER")

    %__MODULE__{
      base_url: System.fetch_env!("#{prefix}_BASE_URL"),
      username: System.fetch_env!("#{prefix}_USERNAME"),
      password: System.fetch_env!("#{prefix}_PASSWORD")
    }
  end

  @doc """
  Creates a `Connection` from your application's runtime config.

  Reads `Application.fetch_env!(app, key)` and expects a keyword list with
  `:base_url`, `:username`, and `:password`. Raises `ArgumentError` if any
  key is missing or `nil`.

  ## Parameters

    - `app` — your OTP application atom.
    - `key` — the config key under which GeoServer config is stored (default: `:geoserver`).

  ## Example

      # config/runtime.exs
      config :my_app, :geoserver,
        base_url: System.get_env("GEOSERVER_BASE_URL"),
        username: System.get_env("GEOSERVER_USERNAME"),
        password: System.get_env("GEOSERVER_PASSWORD")

      # application code
      conn = GeoserverConfig.Connection.from_application_env(:my_app)
  """
  def from_application_env(app, key \\ :geoserver) do
    config = Application.fetch_env!(app, key)

    %__MODULE__{
      base_url: fetch_required!(config, :base_url, app, key),
      username: fetch_required!(config, :username, app, key),
      password: fetch_required!(config, :password, app, key)
    }
  end

  @doc false
  def auth(%__MODULE__{username: username, password: password}) do
    {:basic, "#{username}:#{password}"}
  end

  @doc """
  Returns Req options for this connection: always includes `auth`, and includes
  `plug` when set (used by tests via `Req.Test`).

  Modules in this library call `Connection.req_opts(conn)` and merge their own
  per-request options on top, so every HTTP call automatically picks up any
  test adapter set on the connection.

  ## Example (in tests)

      conn = %GeoserverConfig.Connection{
        base_url: "http://test",
        username: "admin",
        password: "geoserver",
        plug: {Req.Test, MyStub}
      }
  """
  def req_opts(%__MODULE__{plug: nil} = conn), do: [auth: auth(conn)]
  # When a test plug is set, also disable Req's built-in retry so test stubs are
  # not called multiple times on simulated transport errors.
  def req_opts(%__MODULE__{plug: plug} = conn), do: [auth: auth(conn), plug: plug, retry: false]

  defp fetch_required!(config, field, app, key) do
    case config[field] do
      nil ->
        raise ArgumentError,
              "Missing #{inspect(field)} in Application config for #{inspect(app)}/#{inspect(key)}"

      value ->
        value
    end
  end
end
