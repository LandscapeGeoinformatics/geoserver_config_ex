defmodule GeoserverConfig.Datastores do
  @moduledoc """
  Provides functions to manage GeoServer datastores via its REST API.

  Supports listing, creating, updating, and deleting datastores within a specific
  GeoServer workspace. All functions require a `GeoserverConfig.Connection` as their
  first argument.

  ## Supported datastore types

    - `"postgis"` — PostgreSQL/PostGIS
    - `"geopkg"` — GeoPackage file
    - `"shapefile"` — Shapefile
    - `"wfs"` — Web Feature Service

  ## Example

      conn = GeoserverConfig.Connection.from_env()
      {:ok, stores} = GeoserverConfig.Datastores.list_datastores(conn, "demo_workspace")
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all datastores in the given workspace.

  ## Returns

    - `{:ok, [datastore]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error

  ## Example

      {:ok, stores} = GeoserverConfig.Datastores.list_datastores(conn, "demo_workspace")
  """
  def list_datastores(%Connection{} = conn, workspace) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores"

    case Req.get(url,
           auth: Connection.auth(conn),
           headers: [{"Accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200, body: %{"dataStores" => %{"dataStore" => stores}}}}
      when is_list(stores) ->
        {:ok, stores}

      {:ok, %Req.Response{status: 200, body: %{"dataStores" => %{"dataStore" => store}}}}
      when is_map(store) ->
        {:ok, [store]}

      {:ok, %Req.Response{status: 200, body: %{"dataStores" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Creates a new datastore in the specified workspace.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — the workspace name
    - `name` — name for the new datastore
    - `type` — datastore type (`"postgis"`, `"geopkg"`, `"shapefile"`, `"wfs"`)
    - `connection_params` — map of connection parameters specific to the type

  ## Returns

    - `{:ok, name}` on success
    - `{:error, reason}` on failure

  ## Example

      {:ok, "my_store"} = GeoserverConfig.Datastores.create_datastore(conn, "demo_workspace", "my_store", "postgis", %{
        host: "localhost",
        port: 5432,
        database: "gis",
        user: "admin",
        passwd: "secret"
      })
  """
  def create_datastore(%Connection{} = conn, workspace, name, type, connection_params) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores"

    body = %{
      "dataStore" => %{
        "name" => name,
        "connectionParameters" => format_connection_params(type, connection_params),
        "enabled" => true,
        "featureTypes" => []
      }
    }

    case Req.post(url,
           auth: Connection.auth(conn),
           json: body,
           headers: [{"Content-Type", "application/json"}],
           decode_body: false
         ) do
      {:ok, %Req.Response{status: 201}} ->
        {:ok, name}

      {:ok, %Req.Response{status: 500, body: body}} ->
        {:error, String.trim(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc false
  defp format_connection_params("geopkg", %{database: db_path}) do
    %{
      "entry" => [
        %{"@key" => "database", "$" => db_path},
        %{"@key" => "dbtype", "$" => "geopkg"}
      ]
    }
  end

  defp format_connection_params("postgis", %{
         host: host,
         port: port,
         database: db,
         user: user,
         passwd: passwd
       }) do
    %{
      "entry" => [
        %{"@key" => "host", "$" => host},
        %{"@key" => "port", "$" => Integer.to_string(port)},
        %{"@key" => "database", "$" => db},
        %{"@key" => "user", "$" => user},
        %{"@key" => "passwd", "$" => passwd},
        %{"@key" => "dbtype", "$" => "postgis"},
        %{"@key" => "schema", "$" => "public"}
      ]
    }
  end

  defp format_connection_params("shapefile", %{url: file_url}) do
    %{"entry" => [%{"@key" => "url", "$" => file_url}]}
  end

  defp format_connection_params("wfs", %{capabilities_url: url}) do
    %{"entry" => [%{"@key" => "GET_CAPABILITIES_URL", "$" => url}]}
  end

  @doc """
  Updates an existing datastore's configuration.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace name
    - `datastore_name` — name of the datastore to update
    - `datastore_type` — type of the datastore
    - `connection_params` — new connection parameters (may include `:description`)

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error

  ## Example

      {:ok, "my_store"} = GeoserverConfig.Datastores.update_datastore(conn, "demo_workspace", "my_store", "postgis", %{...})
  """
  def update_datastore(%Connection{} = conn, workspace, datastore_name, datastore_type, connection_params) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}"

    body = %{
      "dataStore" => %{
        "description" => connection_params[:description],
        "connectionParameters" => format_connection_params(datastore_type, connection_params),
        "enabled" => true
      }
    }

    case Req.put(url,
           auth: Connection.auth(conn),
           json: body,
           headers: [{"Content-Type", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, datastore_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Deletes a datastore from the given workspace.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace name
    - `datastore_name` — name of the datastore to delete
    - `recurse` — if `true`, also deletes associated resources (default: `false`)

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error

  ## Example

      {:ok, "my_store"} = GeoserverConfig.Datastores.delete_datastore(conn, "demo_workspace", "my_store", true)
  """
  def delete_datastore(%Connection{} = conn, workspace, datastore_name, recurse \\ false) do
    recurse_param = if recurse, do: "true", else: "false"
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}?recurse=#{recurse_param}"

    case Req.delete(url,
           auth: Connection.auth(conn),
           headers: [{"Accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, datastore_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end
end
