defmodule GeoserverConfig.Coverages do
  @moduledoc """
  Handles coverage creation in GeoServer with exact API specification matching.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")


  @spec list_coverages(String.t(), String.t()) :: Req.Response.t()
  def list_coverages(workspace, coverage_store) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end


  @spec create_coverage(String.t(), String.t(), String.t(), map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def create_coverage(workspace, coverage_store, coverage_name, params, file_path) do
    payload = build_payload(workspace, coverage_store, coverage_name, params, file_path)
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages"

    case Req.post(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      json: payload,
      headers: [{"Content-Type", "application/json"}],
      decode_body: false
    ) do
      {:ok, response} when response.status in 200..299 ->
        {:ok, "Coverage '#{coverage_name}' created successfully"}
      {:ok, %{status: status}} ->
        {:error,
        "GeoServer error (#{status}): Check if workspace, coveragestore exists! Verify the data being passed."}
      {:error, error} ->
        {:error,
        "HTTP error: #{inspect(error)} — Check if workspace, coveragestore exists! Verify the data being passed."}
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
    %{
      "minx" => minx,
      "maxx" => maxx,
      "miny" => miny,
      "maxy" => maxy,
      "crs" => crs
    }
  end

  defp build_bbox(%{minx: minx, maxx: maxx, miny: miny, maxy: maxy}, crs) when is_binary(crs) do
    %{
      "minx" => minx,
      "maxx" => maxx,
      "miny" => miny,
      "maxy" => maxy,
      "crs" => build_crs(crs)
    }
  end

  defp build_bbox(%{minx: minx, maxx: maxx, miny: miny, maxy: maxy}, crs) when is_map(crs) do
    %{
      "minx" => minx,
      "maxx" => maxx,
      "miny" => miny,
      "maxy" => maxy,
      "crs" => crs
    }
  end

  defp build_bbox(_, _) do
    nil
  end

  defp build_grid(grid_params, crs) when is_map(grid_params) do
    %{
      "@dimension" => "2",
      "range" => %{
        "low" => "0 0",
        "high" => Enum.join(grid_params.dimension, " ")
      },
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

  defp build_grid(_, _) do
    %{"@dimension" => "2", "range" => %{"low" => "0 0", "high" => "0 0"}}
  end

  defp build_metadata(metadata) do
    %{
      "entry" =>
        Enum.map(metadata, fn {key, value} ->
          %{"@key" => key, "$" => to_string(value)}
        end)
    }
  end

   # DELETE Method
    def delete_coverage(workspace, coverage_store, coverage_name, recurse \\ false) do
      url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{coverage_store}/coverages/#{coverage_name}"

      query_params = if recurse do
        [{"recurse", "true"}]
      else
        []
      end

      case Req.delete(
            url,
            auth: {:basic, "#{@username}:#{@password}"},
            headers: [{"Accept", "application/json"}],
            params: query_params
          ) do
        {:ok, %Req.Response{status: 200}} ->
          {:ok, "Coverage '#{coverage_name}' deleted successfully."}

        {:ok, %Req.Response{status: 404}} ->
          {:error, "Coverage '#{coverage_name}' not found."}

        {:ok, %Req.Response{status: status}} ->
          {:error, "Failed to delete coverage. Status: #{status}, Response: Check if workspace, coveragestore exists and is correctly passed}"}

        {:error, reason} ->
          {:error, "Request error during coverage deletion: #{inspect(reason)}"}
      end
    end

end
