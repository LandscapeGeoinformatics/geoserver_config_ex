defmodule GeoserverConfig.Coverages do
  @moduledoc """
  Provides functionality for managing GeoServer coverages via the REST API.

  All functions require a `GeoserverConfig.Connection` as their first argument.
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all coverages for a given workspace and coverage store.

  ## Returns

    - `{:ok, [coverage]}` on success
    - `{:error, :unexpected_format, body}` when the response body is unrecognised
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def list_coverages(%Connection{} = conn, workspace, coverage_store) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"coverages" => %{"coverage" => coverages}} when is_list(coverages) ->
            {:ok, coverages}

          %{"coverages" => %{}} ->
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
  Creates a new coverage (raster layer) in the specified coverage store.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — the workspace name
    - `coverage_store` — the coverage store name
    - `coverage_name` — desired name of the coverage
    - `params` — metadata map with keys: `:title`, `:srs`, `:native_bbox`, `:latlon_bbox`,
      `:grid`, and optionally `:description`, `:abstract`, `:native_crs`, `:metadata`, `:enabled`
    - `file_path` — URL or file path of the GeoTIFF/COG

  ## Returns

    - `{:ok, coverage_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def create_coverage(%Connection{} = conn, workspace, coverage_store, coverage_name, params, file_path) do
    payload = build_payload(workspace, coverage_store, coverage_name, params, file_path)
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages"

    case Req.post(url,
           Connection.req_opts(conn) ++
             [
               json: payload,
               headers: [{"Content-Type", "application/json"}],
               decode_body: false
             ]
         ) do
      {:ok, response} when response.status in 200..299 ->
        {:ok, coverage_name}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, error} ->
        {:error, {:request_failed, error}}
    end
  end

  defp build_payload(workspace, coverage_store, coverage_name, params, file_path) do
    %{
      "coverage" => %{
        "name" => coverage_name,
        "nativeName" => coverage_name,
        "namespace" => %{"name" => workspace},
        "title" => params.title,
        "description" => Map.get(params, :description, ""),
        "abstract" => Map.get(params, :abstract, ""),
        "enabled" => Map.get(params, :enabled, true),
        "srs" => params.srs,
        "nativeCRS" => build_crs(Map.get(params, :native_crs, params.srs)),
        "nativeBoundingBox" => build_bbox(params.native_bbox, Map.get(params, :native_crs, params.srs)),
        "latLonBoundingBox" => build_bbox(params.latlon_bbox, "EPSG:4326"),
        "grid" => build_grid(params.grid, params.srs),
        "metadata" => build_metadata(Map.get(params, :metadata, %{})),
        "requestSRS" => %{"string" => [params.srs]},
        "responseSRS" => %{"string" => [params.srs]},
        "nativeFormat" => "GeoTIFF",
        "store" => %{
          "@class" => "coverageStore",
          "name" => "#{workspace}:#{coverage_store}",
          "url" => "#{file_path}"
        }
      }
    }
  end

  defp build_crs(crs) do
    if String.starts_with?(crs, "EPSG:") do
      crs
    else
      %{"@class" => "projected", "$" => crs}
    end
  end

  defp build_bbox(%{minx: minx, maxx: maxx, miny: miny, maxy: maxy}, crs) when is_binary(crs) do
    %{"minx" => minx, "maxx" => maxx, "miny" => miny, "maxy" => maxy, "crs" => crs}
  end

  defp build_bbox(%{minx: minx, maxx: maxx, miny: miny, maxy: maxy}, crs) when is_map(crs) do
    %{"minx" => minx, "maxx" => maxx, "miny" => miny, "maxy" => maxy, "crs" => crs}
  end

  defp build_bbox(_, _), do: nil

  defp build_grid(grid_params, crs) when is_map(grid_params) do
    %{
      "@dimension" => "2",
      "range" => %{"low" => "0 0", "high" => Enum.join(grid_params.dimension, " ")},
      "transform" => %{
        "scaleX" => Enum.at(grid_params.transform, 0),
        "scaleY" => Enum.at(grid_params.transform, 4),
        "shearX" => Enum.at(grid_params.transform, 1),
        "shearY" => Enum.at(grid_params.transform, 3),
        "translateX" => Enum.at(grid_params.transform, 2),
        "translateY" => Enum.at(grid_params.transform, 5)
      },
      "crs" => build_crs(crs)
    }
  end

  defp build_grid(_, _), do: %{"@dimension" => "2", "range" => %{"low" => "0 0", "high" => "0 0"}}

  defp build_metadata(metadata) do
    %{
      "entry" =>
        Enum.map(metadata, fn {key, value} ->
          %{"@key" => key, "$" => to_string(value)}
        end)
    }
  end

  @doc """
  Deletes a coverage layer from a workspace and coverage store.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — the workspace name
    - `coverage_store` — the coverage store name
    - `coverage_name` — name of the coverage to delete
    - `recurse` — if `true`, also deletes linked resources (default: `false`)

  ## Returns

    - `{:ok, coverage_name}` on success
    - `{:error, {:not_found, coverage_name}}` when the coverage does not exist
    - `{:error, {:http_error, status, body}}` on other HTTP failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def delete_coverage(%Connection{} = conn, workspace, coverage_store, coverage_name, recurse \\ false) do
    url = "#{conn.base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages/#{coverage_name}"
    query_params = if recurse, do: [{"recurse", "true"}], else: []

    case Req.delete(url,
           Connection.req_opts(conn) ++
             [headers: [{"Accept", "application/json"}], params: query_params]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, coverage_name}

      {:ok, %Req.Response{status: 404}} ->
        {:skipped, coverage_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
