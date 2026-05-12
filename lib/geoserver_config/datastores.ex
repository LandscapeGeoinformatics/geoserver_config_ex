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
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all datastores in the given workspace.

  GeoServer returns a single map when there is only one datastore; this function
  normalises that to always return a list.

  ## Returns

    - `{:ok, [datastore]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error
  """
  def list_datastores(%Connection{} = conn, workspace) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
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

  ## Returns

    - `{:ok, name}` on success
    - `{:error, reason}` on failure
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
           Connection.req_opts(conn) ++
             [
               json: body,
               headers: [{"Content-Type", "application/json"}],
               decode_body: false
             ]
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

  defp format_connection_params("geopkg", %{database: db_path, table: table_name}) do
    %{
      "entry" => [
        %{"@key" => "database", "$" => db_path},
        %{"@key" => "dbtype", "$" => "geopkg"},
        %{"@key" => "table", "$" => table_name}
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

  defp format_connection_params("postgis", params) do
    # Comprehensive PostGIS connection parameters
    entry = [%{"@key" => "dbtype", "$" => "postgis"}]

    # Required parameters
    entry = entry ++ [
      %{"@key" => "host", "$" => params[:host]},
      %{"@key" => "port", "$" => Integer.to_string(params[:port])},
      %{"@key" => "database", "$" => params[:database]},
      %{"@key" => "user", "$" => params[:user]},
      %{"@key" => "passwd", "$" => params[:passwd]}
    ]
    
    # Optional parameters
    entry = add_if_present(entry, params, "schema", "public")
    entry = add_if_present(entry, params, "max connections", "10")
    entry = add_if_present(entry, params, "min connections", "1")
    entry = add_if_present(entry, params, "fetch size", "1000")
    entry = add_if_present(entry, params, "Connection timeout", "20")
    entry = add_if_present(entry, params, "validate connections", "true")
    entry = add_if_present(entry, params, "Evictor run periodicity", "1800")
    entry = add_if_present(entry, params, "Max connection idle time", "300")
    entry = add_if_present(entry, params, "Evictor tests per run", "3")
    entry = add_if_present(entry, params, "Expose primary keys", "false")
    entry = add_if_present(entry, params, "Primary key metadata table")
    entry = add_if_present(entry, params, "Session startup SQL")
    entry = add_if_present(entry, params, "Session close-up SQL")
    entry = add_if_present(entry, params, "preparedStatements", "false")
    entry = add_if_present(entry, params, "Max open prepared statements", "50")
    entry = add_if_present(entry, params, "Loose bbox", "false")
    entry = add_if_present(entry, params, "Estimated extends", "true")
    entry = add_if_present(entry, params, "Encode functions", "false")
    entry = add_if_present(entry, params, "Support on the fly geometry simplification", "true")
    
    %{"entry" => entry}
  end

  defp format_connection_params("shapefile", %{url: file_url}) do
    %{"entry" => [
      %{"@key" => "url", "$" => file_url},
      %{"@key" => "dbtype", "$" => "shapefile"}
    ]}
  end

  defp format_connection_params("shapefile", %{url: file_url, charset: charset}) do
    %{"entry" => [
      %{"@key" => "url", "$" => file_url},
      %{"@key" => "dbtype", "$" => "shapefile"},
      %{"@key" => "charset", "$" => charset}
    ]}
  end

  defp format_connection_params("wfs", %{capabilities_url: url}) do
    %{"entry" => [%{"@key" => "GET_CAPABILITIES_URL", "$" => url}]}
  end

  defp add_if_present(entry, params, key, default_value \\ nil) do
    value = Map.get(params, String.to_atom(key))
    
    cond do
      value ->
        entry ++ [%{"@key" => key, "$" => value}]
      default_value ->
        entry ++ [%{"@key" => key, "$" => default_value}]
      true ->
        entry
    end
  end

  @doc """
  Updates an existing datastore's configuration.

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
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
           Connection.req_opts(conn) ++
             [json: body, headers: [{"Content-Type", "application/json"}]]
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

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def delete_datastore(%Connection{} = conn, workspace, datastore_name, recurse \\ false) do
    recurse_param = if recurse, do: "true", else: "false"
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}?recurse=#{recurse_param}"

    case Req.delete(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, datastore_name}

      {:ok, %Req.Response{status: 404}} ->
        {:skipped, datastore_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end
end
