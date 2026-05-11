defmodule GeoserverConfig.FeatureTypes do
  @moduledoc """
  Provides functions to manage GeoServer feature types (vector layers) via its REST API.

  Feature types are vector-based spatial resources that originate from datastores.
  This module handles listing, creating, updating, and deleting feature types.
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all feature types in a given datastore and workspace.

  ## Parameters

    - `list`: Optional parameter to filter results. Can be:
      - `:configured` - Only configured feature types (default)
      - `:available` - Only available but not configured feature types
      - `:available_with_geom` - Available feature types with geometry
      - `:all` - All feature types

  ## Returns

    - `{:ok, [feature_types]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error
  """
  def list_featuretypes(%Connection{} = conn, workspace, datastore, list \\ :configured) do
    list_str = case list do
      :configured -> "configured"
      :available -> "available"
      :available_with_geom -> "available_with_geom"
      :all -> "all"
    end

    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes?list=#{list_str}"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => types}}}}
      when is_list(types) ->
        {:ok, types}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => type}}}}
      when is_map(type) ->
        {:ok, [type]}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Creates a new feature type (vector layer) in the specified datastore.

  ## Parameters

    - `params`: Map containing feature type configuration including:
      - `title`: Human-readable title
      - `description`: Description
      - `abstract`: Abstract text
      - `srs`: Coordinate reference system (e.g., "EPSG:4326")
      - `native_crs`: Native CRS
      - `native_bbox`: Native bounding box as %{minx: x, maxx: x, miny: y, maxy: y}
      - `latlon_bbox`: Lat/lon bounding box
      - `enabled`: Boolean (default: true)
      - `keywords`: List of keywords
      - `metadata`: Additional metadata

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, reason}` on failure
  """
  def create_featuretype(%Connection{} = conn, workspace, datastore, featuretype_name, params \\ %{}) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes"

    # Build the feature type body
    body = %{
      "featureType" => %{
        "name" => featuretype_name,
        "title" => params[:title] || featuretype_name,
        "description" => params[:description] || "",
        "abstract" => params[:abstract] || "",
        "srs" => params[:srs] || "EPSG:4326",
        "nativeCRS" => params[:native_crs] || params[:srs] || "EPSG:4326",
        "enabled" => params[:enabled] || true
      }
    }

    # Add bounding boxes if provided
    body = add_bounding_boxes(body, params)

    body =
      if keywords = params[:keywords] do
        put_in(body, ["featureType", "keywords"], %{"string" => keywords})
      else
        body
      end

    body =
      if metadata = params[:metadata] do
        put_in(body, ["featureType", "metadata"], metadata)
      else
        body
      end

    case Req.post(url,
           Connection.req_opts(conn) ++
             [
               json: body,
               headers: [{"Content-Type", "application/json"}],
               decode_body: false
             ]
         ) do
      {:ok, %Req.Response{status: 201}} ->
        {:ok, featuretype_name}

      {:ok, %Req.Response{status: 500, body: body}} ->
        {:error, String.trim(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Updates an existing feature type.

  ## Parameters

    - `params`: Map containing updated feature type properties
    - `recalculate`: Optional parameter to recalculate bounding boxes

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def update_featuretype(%Connection{} = conn, workspace, datastore, featuretype_name, params \\ %{}, recalculate \\ nil) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}"
    
    # Add recalculate parameter if specified
    url = if recalculate, do: "#{url}?recalculate=#{recalculate}", else: url

    # Build update body
    body = %{"featureType" => build_featuretype_update_body(params)}

    case Req.put(url,
           Connection.req_opts(conn) ++
             [json: body, headers: [{"Content-Type", "application/json"}]]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, featuretype_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Deletes a feature type from the given datastore.

  ## Parameters

    - `recurse`: If true, also deletes dependent layers (default: false)

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def delete_featuretype(%Connection{} = conn, workspace, datastore, featuretype_name, recurse \\ false) do
    recurse_param = if recurse, do: "true", else: "false"
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}?recurse=#{recurse_param}"

    case Req.delete(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, featuretype_name}

      {:ok, %Req.Response{status: 404}} ->
        {:skipped, featuretype_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  # Private helper functions

  defp add_bounding_boxes(body, params) do
    body =
      if native_bbox = params[:native_bbox] do
        put_in(body, ["featureType", "nativeBoundingBox"], %{
          "minx" => native_bbox[:minx],
          "maxx" => native_bbox[:maxx],
          "miny" => native_bbox[:miny],
          "maxy" => native_bbox[:maxy],
          "crs" => native_bbox[:crs] || params[:native_crs] || params[:srs] || "EPSG:4326"
        })
      else
        body
      end

    body =
      if latlon_bbox = params[:latlon_bbox] do
        put_in(body, ["featureType", "latLonBoundingBox"], %{
          "minx" => latlon_bbox[:minx],
          "maxx" => latlon_bbox[:maxx],
          "miny" => latlon_bbox[:miny],
          "maxy" => latlon_bbox[:maxy],
          "crs" => "EPSG:4326"
        })
      else
        body
      end

    body
  end

  defp build_featuretype_update_body(params) do
    # Only include fields that are provided in params
    body = %{}

    body =
      cond do
        params[:title] -> Map.put(body, "title", params[:title])
        true -> body
      end

    body =
      cond do
        params[:description] -> Map.put(body, "description", params[:description])
        true -> body
      end

    body =
      cond do
        params[:abstract] -> Map.put(body, "abstract", params[:abstract])
        true -> body
      end

    body =
      cond do
        params[:srs] -> Map.put(body, "srs", params[:srs])
        true -> body
      end

    body =
      cond do
        params[:native_crs] -> Map.put(body, "nativeCRS", params[:native_crs])
        true -> body
      end

    body =
      cond do
        params[:enabled] -> Map.put(body, "enabled", params[:enabled])
        true -> body
      end

    # Add bounding boxes if provided
    body =
      if native_bbox = params[:native_bbox] do
        Map.put(body, "nativeBoundingBox", %{
          "minx" => native_bbox[:minx],
          "maxx" => native_bbox[:maxx],
          "miny" => native_bbox[:miny],
          "maxy" => native_bbox[:maxy],
          "crs" => native_bbox[:crs] || params[:native_crs] || params[:srs] || "EPSG:4326"
        })
      else
        body
      end

    body =
      if latlon_bbox = params[:latlon_bbox] do
        Map.put(body, "latLonBoundingBox", %{
          "minx" => latlon_bbox[:minx],
          "maxx" => latlon_bbox[:maxx],
          "miny" => latlon_bbox[:miny],
          "maxy" => latlon_bbox[:maxy],
          "crs" => "EPSG:4326"
        })
      else
        body
      end

    # Add keywords if provided
    body =
      if keywords = params[:keywords] do
        Map.put(body, "keywords", %{"string" => keywords})
      else
        body
      end

    # Add metadata if provided
    body =
      if metadata = params[:metadata] do
        Map.put(body, "metadata", metadata)
      else
        body
      end

    body
  end
end