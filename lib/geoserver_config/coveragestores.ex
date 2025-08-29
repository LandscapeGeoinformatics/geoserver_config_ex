defmodule GeoserverConfig.Coveragestores do
  @moduledoc """
  Provides functions for managing GeoServer coverage stores via the REST API.

  This module allows listing, creating, updating, and deleting coverage stores
  in a specified workspace. Coverage stores typically reference raster data
  like GeoTIFF or COGs (Cloud Optimized GeoTIFFs), and are essential for configuring
  raster layers in GeoServer.

  ## Environment Variables

    - `GEOSERVER_BASE_URL` — Base URL of the GeoServer instance
    - `GEOSERVER_USERNAME` — Username for authentication
    - `GEOSERVER_PASSWORD` — Password for authentication
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

@doc """
  Lists all coverage stores in the specified workspace.

  ## Parameters
    - `workspace` (`String.t`) — Name of the workspace to fetch coverage stores from.

  ## Returns
    - `%Req.Response{}` with JSON body listing coverage stores.

  ## Example
      GeoserverConfig.Coveragestores.list_coveragestores("demo_workspace")
  """

  def list_coveragestores(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores"

    case Req.get(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [{"Accept", "application/json"}]
        ) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"coverageStores" => %{"coverageStore" => stores}} when is_list(stores) ->
            {:ok, stores}

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
  Creates a new coverage store for a GeoTIFF or COG raster file in the specified workspace.

  ## Parameters
    - `workspace` (`String.t`) — The name of the GeoServer workspace.
    - `store_name` (`String.t`) — Desired name of the coverage store.
    - `geotiff_path` (`String.t`) — File path or URL to the GeoTIFF/COG file.
    - `description` (`String.t`, optional) — Optional description of the store (default: empty string).
    - `opts` (`map`, optional) — Additional options such as:
      - `:connectionParameters`
      - `:metadata`
      - `:disableOnConnFailure`

  ## Returns
    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example
      GeoserverConfig.Coveragestores.create_coveragestore(
        "demo_workspace",
        "demo_coverage_store",
        "file:///data/elevation.tif",
        "Description of Coverage Store"
      )
  """
 def create_coveragestore(workspace, store_name, geotiff_path, description \\ "", opts \\ %{}) do
  base_url = "#{@base_url}/workspaces/#{workspace}/coveragestores"

  store_body = %{
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

  # Merge COG GeoTIFF fields
  |> Map.update!("coverageStore", fn cs ->
    cs
    |> Map.merge(Map.take(opts, [:connectionParameters, :metadata, :disableOnConnFailure]))
  end)

  # Send the request to create the coverage store
  store_response = Req.post(
    base_url,
    auth: {:basic, "#{@username}:#{@password}"},
    json: store_body,
    headers: [{"Content-Type", "application/json"}],
    decode_body: false
  )

  case store_response do
    {:ok, %Req.Response{status: status}} when status in [200, 201] ->
      {:ok, "Coverage store created successfully."}

    {:ok, %Req.Response{status: status, body: body}} ->
      {:error, "Failed to create coverage store. Status: #{status}, Response: #{inspect(body)}"}

    {:error, reason} ->
      {:error, "Request error during coverage store creation: #{inspect(reason)}"}
  end
end


@doc """
  Updates an existing coverage store.

  ## Parameters
    - `workspace` (`String.t`) — The name of the workspace containing the store.
    - `store_name` (`String.t`) — The name of the coverage store to update.
    - `updated_params` (`map`) — Map of updated fields. Expected keys:
      - `:type`
      - `:enabled`
      - `:url`
      - `:description`

  ## Returns
    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example
      GeoserverConfig.Coveragestores.update_coveragestore(
        "demo_workspace",
        "demo_coverage_store",
        %{
          type: "GeoTIFF",
          enabled: true,
          url: "file:///new/path/elevation.tif",
          description: "Updated raster file"
        }
      )
  """
  def update_coveragestore(workspace, store_name, updated_params) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{store_name}"

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

    case Req.put(
           url,
           auth: {:basic, "#{@username}:#{@password}"},
           json: body,
           headers: [{"Content-Type", "application/json"}]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 201] ->
        {:ok, "Coverage store updated successfully."}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to update coverage store. Status: #{status}, Response: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request error during coverage store update: #{inspect(reason)}"}
    end
  end

@doc """
  Deletes a coverage store from the specified workspace.

  Uses the `purge=true` parameter to also delete related resources.

  ## Parameters
    - `workspace` (`String.t`) — Name of the workspace.
    - `name` (`String.t`) — Name of the coverage store to delete.

  ## Returns
    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example
      GeoserverConfig.Coveragestores.delete_coveragestore("demo_workspace", "demo_coverage_store")
  """
  def delete_coveragestore(workspace, name) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{name}?purge=true"

    case Req.delete(
           url,
           auth: {:basic, "#{@username}:#{@password}"},
           headers: [{"Accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, "Coverage store deleted successfully."}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to delete coverage store. Status: #{status}, Response: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request error during coverage store deletion: #{inspect(reason)}"}
    end
  end

  # POST: Create multiple coverage stores from CSV
  # def create_coveragestores_from_csv(csv_file_path) do

  #   csv_file_path
  #   |> File.stream!()
  #   |> CSV.decode(headers: true)
  #   |> Enum.each(fn
  #     {:ok, row} ->
  #       case create_coveragestore(
  #         row["workspace"],
  #         row["store_name"],
  #         row["geotiff_path"],
  #         row["description"] || ""
  #       ) do
  #         {:ok, msg} ->
  #           IO.puts("Successfully created coverage store '#{row["store_name"]}': #{msg}")

  #         {:error, reason} ->
  #           IO.puts("Failed to create '#{row["store_name"]}': #{inspect(reason)}")
  #       end

  #     {:error, reason} ->
  #       IO.puts("CSV parsing error: #{inspect(reason)}")
  #   end)
  # end

end
