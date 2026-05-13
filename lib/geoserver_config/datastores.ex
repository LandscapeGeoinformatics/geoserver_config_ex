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
  Fetches a single datastore by name from the given workspace.

  ## Options

    - `:quiet_on_not_found` — when `true`, avoids logging an exception on 404 (default: `false`)

  ## Returns

    - `{:ok, datastore}` on success (a map with datastore details)
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error
  """
  def get_datastore(%Connection{} = conn, workspace, datastore_name, opts \\ []) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}"

    url =
      if Keyword.get(opts, :quiet_on_not_found) do
        "#{url}?quietOnNotFound=true"
      else
        url
      end

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"dataStore" => store}}} ->
        {:ok, store}

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

    case Req.post(
           url,
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
  defp format_connection_params("geopkg", params) do
    entry = [%{"@key" => "dbtype", "$" => "geopkg"}]

    entry =
      if db = params[:database], do: entry ++ [%{"@key" => "database", "$" => db}], else: entry

    entry = add_if_present(entry, params, "table")
    entry = add_if_present(entry, params, "fetch size", "1000")
    entry = add_if_present(entry, params, "Connection timeout", "20")
    entry = add_if_present(entry, params, "max connections", "10")
    entry = add_if_present(entry, params, "min connections", "1")
    entry = add_if_present(entry, params, "validate connections", "true")
    entry = add_if_present(entry, params, "Test while idle", "true")
    entry = add_if_present(entry, params, "Expose primary keys", "false")
    entry = add_if_present(entry, params, "Primary key metadata table")
    entry = add_if_present(entry, params, "Batch insert size")
    entry = add_if_present(entry, params, "Evictor tests per run")
    entry = add_if_present(entry, params, "Max connection idle time", "300")
    entry = add_if_present(entry, params, "Evictor run periodicity", "300")
    entry = add_if_present(entry, params, "Session startup SQL")
    entry = add_if_present(entry, params, "Session close-up SQL")
    entry = add_if_present(entry, params, "namespace")
    entry = add_if_present(entry, params, "user")
    entry = add_if_present(entry, params, "passwd")
    entry = add_if_present(entry, params, "Callback factory")

    %{"entry" => entry}
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
    entry =
      entry ++
        [
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
    entry = add_if_present(entry, params, "create database", "false")
    entry = add_if_present(entry, params, "create database params")
    entry = add_if_present(entry, params, "Batch insert size")
    entry = add_if_present(entry, params, "Test while idle", "true")
    entry = add_if_present(entry, params, "Callback factory")

    %{"entry" => entry}
  end

  defp format_connection_params("shapefile", params) do
    entry = [%{"@key" => "dbtype", "$" => "shapefile"}]

    entry =
      if url = params[:url], do: entry ++ [%{"@key" => "url", "$" => url}], else: entry

    entry = add_if_present(entry, params, "charset", "ISO-8859-1")
    entry = add_if_present(entry, params, "namespace")
    entry = add_if_present(entry, params, "create spatial index", "true")
    entry = add_if_present(entry, params, "enable spatial index", "true")
    entry = add_if_present(entry, params, "memory mapped buffer", "false")
    entry = add_if_present(entry, params, "cache and reuse memory maps", "true")
    entry = add_if_present(entry, params, "filetype")
    entry = add_if_present(entry, params, "fstype")
    entry = add_if_present(entry, params, "timezone")

    %{"entry" => entry}
  end

  defp format_connection_params("wfs", params) do
    entry = []

    entry =
      if url = params[:capabilities_url],
        do: entry ++ [%{"@key" => "GET_CAPABILITIES_URL", "$" => url}],
        else: entry

    entry = add_if_present(entry, params, "Protocol")
    entry = add_if_present(entry, params, "WFS GetCapabilities URL")
    entry = add_if_present(entry, params, "Buffer Size")
    entry = add_if_present(entry, params, "Filter compliance")
    entry = add_if_present(entry, params, "Time-out")
    entry = add_if_present(entry, params, "Lenient")
    entry = add_if_present(entry, params, "Username")
    entry = add_if_present(entry, params, "Password")
    entry = add_if_present(entry, params, "Use Default SRS")
    entry = add_if_present(entry, params, "Namespace")
    entry = add_if_present(entry, params, "Axis Order")
    entry = add_if_present(entry, params, "Axis Order Filter")
    entry = add_if_present(entry, params, "Maximum features")
    entry = add_if_present(entry, params, "Try GZIP")
    entry = add_if_present(entry, params, "Encoding")
    entry = add_if_present(entry, params, "Outputformat")
    entry = add_if_present(entry, params, "GmlComplianceLevel")
    entry = add_if_present(entry, params, "GmlCompatibleTypeNames")
    entry = add_if_present(entry, params, "WFS Strategy")

    %{"entry" => entry}
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
  Resets the caches related to this specific data store.

  This forces GeoServer to drop cached data store structures and reconnect
  to the vector source the next time it is needed.

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def reset_datastore(%Connection{} = conn, workspace, datastore_name) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}/reset"

    case Req.put(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, datastore_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Uploads files to a data store, creating it if necessary.

  Uses the PUT `/datastores/{store}/{method}.{format}` endpoint.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — the workspace name
    - `store_name` — target datastore name (will be created if absent)
    - `method` — `:file`, `:url`, or `:external`
    - `format` — the file extension (e.g. `"shp"`, `"geopkg"`, `"properties"`)
    - `body` — file content (for `:file`), a URL string (for `:url`), or a local path (for `:external`)
    - `opts` — optional keyword list:
      - `:configure` — `"none"`, `"first"` (default), or `"all"`
      - `:target` — target data store format (e.g. `"shp"`)
      - `:update` — `"append"` (default) or `"overwrite"`
      - `:charset` — character encoding (e.g. `"ISO-8859-1"`)
      - `:filename` — target filename for the uploaded file
      - `:content_type` — override Content-Type header

  ## Returns

    - `{:ok, store_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def upload_datastore(
        %Connection{} = conn,
        workspace,
        store_name,
        method,
        format,
        body,
        opts \\ []
      ) do
    meth_str = Atom.to_string(method)

    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{store_name}/#{meth_str}.#{format}"

    query =
      []
      |> then(fn q ->
        if c = opts[:configure], do: Keyword.put(q, :configure, c), else: q
      end)
      |> then(fn q ->
        if t = opts[:target], do: Keyword.put(q, :target, t), else: q
      end)
      |> then(fn q ->
        if u = opts[:update], do: Keyword.put(q, :update, u), else: q
      end)
      |> then(fn q ->
        if ch = opts[:charset], do: Keyword.put(q, :charset, ch), else: q
      end)
      |> then(fn q ->
        if f = opts[:filename], do: Keyword.put(q, :filename, f), else: q
      end)

    content_type = opts[:content_type] || "application/zip"

    case Req.put(
           url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", content_type}, {"Accept", "application/json"}],
               body: body,
               params: query,
               decode_body: false
             ]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 201] ->
        {:ok, store_name}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Updates an existing datastore's configuration.

  ## Returns

    - `{:ok, datastore_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def update_datastore(
        %Connection{} = conn,
        workspace,
        datastore_name,
        datastore_type,
        connection_params
      ) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}"

    body = %{
      "dataStore" => %{
        "description" => connection_params[:description],
        "connectionParameters" => format_connection_params(datastore_type, connection_params),
        "enabled" => true
      }
    }

    case Req.put(
           url,
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

    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore_name}?recurse=#{recurse_param}"

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
