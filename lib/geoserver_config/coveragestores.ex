defmodule GeoserverConfig.Coveragestores do
  @moduledoc """
  Provides functions for managing GeoServer coverage stores via the REST API.

  Coverage stores reference raster data such as GeoTIFF or COGs (Cloud Optimized
  GeoTIFFs). All functions require a `GeoserverConfig.Connection` as their first
  argument.

  ## Example

      conn = GeoserverConfig.Connection.from_env()
      {:ok, stores} = GeoserverConfig.Coveragestores.list_coveragestores(conn, "demo_workspace")
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all coverage stores in the specified workspace.

  ## Returns

    - `{:ok, [store]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, :unexpected_format, body}` when the response body is unrecognised
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def list_coveragestores(%Connection{} = conn, workspace) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"coverageStores" => %{"coverageStore" => stores}} when is_list(stores) ->
            {:ok, stores}

          %{"coverageStores" => %{"coverageStore" => store}} when is_map(store) ->
            {:ok, [store]}

          %{"coverageStores" => %{}} ->
            {:ok, []}

          _ ->
            {:error, :unexpected_format, body}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Creates a new coverage store for a GeoTIFF or COG raster file.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — the GeoServer workspace name
    - `store_name` — desired name for the coverage store
    - `geotiff_path` — file path or URL to the GeoTIFF/COG
    - `description` — optional description (default: `""`)
    - `opts` — optional map with extra store fields:
      - `:connectionParameters`, `:metadata`, `:disableOnConnFailure`

  ## Returns

    - `{:ok, store_name}` on success
    - `{:error, reason}` on failure
  """
  def create_coveragestore(%Connection{} = conn, workspace, store_name, geotiff_path, description \\ "", opts \\ %{}) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores"

    store_body =
      %{
        "coverageStore" => %{
          "name" => store_name,
          "description" => description,
          "type" => "GeoTIFF",
          "enabled" => true,
          "workspace" => %{"name" => workspace},
          "url" => "#{geotiff_path}",
          "default" => true
        }
      }
      |> Map.update!("coverageStore", fn cs ->
        Map.merge(cs, Map.take(opts, [:connectionParameters, :metadata, :disableOnConnFailure]))
      end)

    case Req.post(url,
           Connection.req_opts(conn) ++
             [
               json: store_body,
               headers: [{"Content-Type", "application/json"}],
               decode_body: false
             ]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 201] ->
        {:ok, store_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Updates an existing coverage store.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace containing the store
    - `store_name` — name of the coverage store to update
    - `updated_params` — map of fields to update: `:type`, `:enabled`, `:url`, `:description`

  ## Returns

    - `{:ok, store_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def update_coveragestore(%Connection{} = conn, workspace, store_name, updated_params) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores/#{store_name}"

    body = %{
      "coverageStore" => %{
        "name" => store_name,
        "type" => updated_params[:type],
        "enabled" => updated_params[:enabled],
        "workspace" => %{"name" => workspace},
        "url" => updated_params[:url],
        "description" => updated_params[:description]
      }
    }

    case Req.put(url,
           Connection.req_opts(conn) ++
             [json: body, headers: [{"Content-Type", "application/json"}]]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 201] ->
        {:ok, store_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Deletes a coverage store from the specified workspace.

  Uses `purge=true` to also remove related resources.

  ## Returns

    - `{:ok, name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def delete_coveragestore(%Connection{} = conn, workspace, name) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores/#{name}?purge=true"

    case Req.delete(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, name}

      {:ok, %Req.Response{status: 404}} ->
        {:skipped, name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
