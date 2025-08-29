defmodule GeoserverConfig.Datastores do
  @moduledoc """
  Provides functions to manage GeoServer datastores via its REST API.

  This module allows you to list, create, update, and delete datastores within a specific
  GeoServer workspace. It supports multiple datastore types including PostGIS, GeoPackage,
  Shapefile, and WFS. Authentication is handled using basic auth credentials provided
  via environment variables.

  ## Supported Datastore Types

    - `"postgis"` — PostgreSQL/PostGIS datastore
    - `"geopkg"` — GeoPackage file
    - `"shapefile"` — Shapefile (local or remote)
    - `"wfs"` — Web Feature Service

  ## Environment Variables

    - `GEOSERVER_BASE_URL` — Base URL of the GeoServer instance
    - `GEOSERVER_USERNAME` — Username for authentication
    - `GEOSERVER_PASSWORD` — Password for authentication
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @doc """
  Lists all datastores in the given workspace.

  ## Parameters
    - `workspace` (`String.t`) — The name of the workspace to list datastores from.

  ## Returns
    - `%Req.Response{}` with JSON response body containing datastore list.

  ## Example
      GeoserverConfig.Datastores.list_datastores("demo_workspace")
  """
  # def list_datastores(workspace) do
  #   url = "#{@base_url}/workspaces/#{workspace}/datastores"

  #   Req.get!(
  #     url,
  #     auth: {:basic, "#{@username}:#{@password}"},
  #     headers: [{"Accept", "application/json"}]
  #   )
  # end

  def list_datastores(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores"

    case Req.get(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [{"accept", "application/json"}]
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
    - `workspace` (`String.t`) — The workspace name.
    - `name` (`String.t`) — The name for the new datastore.
    - `type` (`String.t`) — The datastore type (e.g., `"postgis"`, `"geopkg"`).
    - `connection_params` (`map`) — Connection parameters specific to the datastore type.

  ## Returns
    - `{:ok, "Datastore created successfully"}` on success.
    - `{:error, reason}` on failure.

  ## Example
      GeoserverConfig.Datastores.create_datastore("demo_workspace", "my_store", "postgis", %{
        host: "localhost",
        port: 5432,
        database: "gis",
        user: "admin",
        passwd: "secret"
      })
  """
  def create_datastore(workspace, name, type, connection_params) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores"

    body = %{
      "dataStore" => %{
        "name" => name,
        "connectionParameters" => format_connection_params(type, connection_params),
        "enabled" => true,
        "featureTypes" => []
      }
    }

    response =
      Req.post!(
        url,
        auth: {:basic, "#{@username}:#{@password}"},
        json: body,
        headers: [{"Content-Type", "application/json"}],
        decode_body: false
      )

    case response.status do
      201 ->
        {:ok, "Datastore created successfully"}

      500 ->
        {:error, String.trim(response.body)} # Likely plain text error like "Store already exists"

      _ ->
        {:error, "Unexpected response (#{response.status}): #{inspect(response.body)}"}
    end
  end

  @doc false
  # Private method to format the connection parameters based on the datastore type
  defp format_connection_params("geopkg", %{database: db_path}) do
    %{"entry" => [
      %{"@key" => "database", "$" => db_path},
      %{"@key" => "dbtype", "$" => "geopkg"}
    ]}
  end

  defp format_connection_params("postgis", %{host: host, port: port, database: db, user: user, passwd: passwd }) do
    %{"entry" => [
      %{"@key" => "host", "$" => host},
      %{"@key" => "port", "$" => Integer.to_string(port)},
      %{"@key" => "database", "$" => db},
      %{"@key" => "user", "$" => user},
      %{"@key" => "passwd", "$" => passwd},
      %{"@key" => "dbtype", "$" => "postgis"},
      %{"@key" => "schema", "$" => "public"}
    ]}
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
    - `workspace` (`String.t`) — The workspace name.
    - `datastore_name` (`String.t`) — The name of the datastore to update.
    - `datastore_type` (`String.t`) — Type of the datastore (`"postgis"`, `"geopkg"`, etc.).
    - `connection_params` (`map`) — New connection parameters.

  ## Output
    - Prints success or failure message to the console.

  ## Example
      GeoserverConfig.Datastores.update_datastore("demo_workspace", "my_store", "postgis", %{...})
  """
  def update_datastore(workspace, datastore_name, datastore_type, connection_params) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores/#{datastore_name}"

    body = %{
      "dataStore" => %{
        "description" => connection_params[:description],
        "connectionParameters" => format_connection_params(datastore_type, connection_params),
        "enabled" => true
      }
    }

    response = Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      json: body,
      headers: [{"Content-Type", "application/json"}]
    )

    case response.status do
      200 -> IO.puts("Datastore #{datastore_name} successfully updated.")
      _ -> IO.puts("Failed to update datastore #{datastore_name}. Response Status: #{response.status}")
    end
  end

  @doc """
  Deletes a datastore from the given workspace.

  ## Parameters
    - `workspace` (`String.t`) — The workspace name.
    - `datastore_name` (`String.t`) — Name of the datastore to delete.
    - `recurse` (`boolean`, optional) — Whether to also delete associated resources (default: `false`).

  ## Output
    - Prints success or failure message to the console.

  ## Example
      GeoserverConfig.Datastores.delete_datastore("demo_workspace", "my_store", true)
  """
  def delete_datastore(workspace, datastore_name, recurse \\ false) do
    recurse_param = if recurse, do: "true", else: "false"
    url = "#{@base_url}/workspaces/#{workspace}/datastores/#{datastore_name}?recurse=#{recurse_param}"

    response = Req.delete!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )

    case response.status do
      200 -> IO.puts("Datastore #{datastore_name} successfully deleted.")
      _ -> IO.puts("Failed to delete datastore #{datastore_name}. Response Status: #{response.status}")
    end
  end
end
