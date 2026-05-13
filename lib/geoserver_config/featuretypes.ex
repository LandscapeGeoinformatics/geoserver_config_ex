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
    list_str =
      case list do
        :configured -> "configured"
        :available -> "available"
        :available_with_geom -> "available_with_geom"
        :all -> "all"
      end

    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes?list=#{list_str}"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => types}}}}
      when is_list(types) ->
        {:ok, types}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => type}}}}
      when is_map(type) ->
        {:ok, [type]}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: 200, body: %{"list" => %{"string" => names}}}}
      when is_list(names) ->
        {:ok, Enum.map(names, &%{"name" => &1})}

      {:ok, %Req.Response{status: 200, body: %{"list" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Fetches a single feature type by name from the given workspace and datastore.

  ## Options

    - `:quiet_on_not_found` — when `true`, avoids logging an exception on 404 (default: `false`)

  ## Returns

    - `{:ok, featuretype}` on success (a map with feature type details)
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error
  """
  def get_featuretype(%Connection{} = conn, workspace, datastore, featuretype_name, opts \\ []) do
    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}"

    url =
      if Keyword.get(opts, :quiet_on_not_found) do
        "#{url}?quietOnNotFound=true"
      else
        url
      end

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"featureType" => ft}}} ->
        {:ok, ft}

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
      - `projection_policy`: `"FORCE_DECLARED"`, `"NONE"`, or `"REPROJECT_TO_DECLARED"`
      - `max_features`: Maximum number of features returned
      - `num_decimals`: Number of decimal places
      - `cql_filter`: CQL filter expression
      - `overriding_service_srs`: Boolean
      - `skip_number_matched`: Boolean
      - `circular_arc_present`: Boolean
      - `linearization_tolerance`: Tolerance value
      - `metadata_links`: List of metadata link maps
      - `data_links`: List of data link maps
      - `response_srs`: SRS for response (defaults to `[params.srs]`)

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, reason}` on failure
  """
  def create_featuretype(
        %Connection{} = conn,
        workspace,
        datastore,
        featuretype_name,
        params \\ %{}
      ) do
    url = "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes"

    body = build_featuretype_body(featuretype_name, params)

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
        {:ok, featuretype_name}

      {:ok, %Req.Response{status: 500, body: body}} ->
        {:error, String.trim(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  defp build_featuretype_body(featuretype_name, params) do
    srs = params[:srs] || "EPSG:4326"

    %{
      "featureType" =>
        %{
          "name" => featuretype_name,
          "title" => params[:title] || featuretype_name,
          "description" => params[:description] || "",
          "abstract" => params[:abstract] || "",
          "srs" => srs,
          "nativeCRS" => params[:native_crs] || srs,
          "enabled" => params[:enabled] || true
        }
        |> maybe_add("keywords", build_keywords(params[:keywords]))
        |> maybe_add("metadata", params[:metadata])
        |> maybe_add("projectionPolicy", params[:projection_policy])
        |> maybe_add("maxFeatures", params[:max_features])
        |> maybe_add("numDecimals", params[:num_decimals])
        |> maybe_add("cqlFilter", params[:cql_filter])
        |> maybe_add("overridingServiceSRS", params[:overriding_service_srs])
        |> maybe_add("skipNumberMatched", params[:skip_number_matched])
        |> maybe_add("circularArcPresent", params[:circular_arc_present])
        |> maybe_add("linearizationTolerance", params[:linearization_tolerance])
        |> maybe_add("metadataLinks", format_links(params[:metadata_links]))
        |> maybe_add("dataLinks", format_links(params[:data_links]))
        |> add_response_srs(srs, params)
        |> add_bounding_boxes(params)
    }
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)

  defp build_keywords(nil), do: nil
  defp build_keywords(keywords), do: %{"string" => keywords}

  defp format_links(nil), do: nil
  defp format_links(links), do: %{"metadataLink" => links}

  defp add_response_srs(ft, srs, params) do
    response_srs = params[:response_srs] || [srs]

    if params[:response_srs] do
      Map.put(ft, "responseSRS", %{"string" => params[:response_srs]})
    else
      Map.put(ft, "responseSRS", %{"string" => response_srs})
    end
  end

  @doc """
  Resets the caches related to this specific feature type.

  This forces GeoServer to drop cached feature type structures and recompute
  them on the next request. Attributes configuration is not changed.

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def reset_featuretype(%Connection{} = conn, workspace, datastore, featuretype_name) do
    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}/reset"

    case Req.put(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, featuretype_name}

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
  def update_featuretype(
        %Connection{} = conn,
        workspace,
        datastore,
        featuretype_name,
        params \\ %{},
        recalculate \\ nil
      ) do
    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}"

    # Add recalculate parameter if specified
    url = if recalculate, do: "#{url}?recalculate=#{recalculate}", else: url

    # Build update body
    body = %{"featureType" => build_featuretype_update_body(params)}

    case Req.put(
           url,
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
  def delete_featuretype(
        %Connection{} = conn,
        workspace,
        datastore,
        featuretype_name,
        recurse \\ false
      ) do
    recurse_param = if recurse, do: "true", else: "false"

    url =
      "#{conn.base_url}/workspaces/#{workspace}/datastores/#{datastore}/featuretypes/#{featuretype_name}?recurse=#{recurse_param}"

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

  @doc """
  Lists all feature types across all datastores in the given workspace.

  ## Parameters

    - `list`: Optional filter. Can be:
      - `:configured` — Only configured feature types (default)
      - `:available` — Only available but not configured feature types
      - `:available_with_geom` — Available feature types with geometry
      - `:all` — All feature types

  ## Returns

    - `{:ok, [feature_types]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, exception}` on transport error
  """
  def list_workspace_featuretypes(%Connection{} = conn, workspace, list \\ :configured) do
    list_str =
      case list do
        :configured -> "configured"
        :available -> "available"
        :available_with_geom -> "available_with_geom"
        :all -> "all"
      end

    url =
      "#{conn.base_url}/workspaces/#{workspace}/featuretypes?list=#{list_str}"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => types}}}}
      when is_list(types) ->
        {:ok, types}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => %{"featureType" => type}}}}
      when is_map(type) ->
        {:ok, [type]}

      {:ok, %Req.Response{status: 200, body: %{"featureTypes" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: 200, body: %{"list" => %{"string" => names}}}}
      when is_list(names) ->
        {:ok, Enum.map(names, &%{"name" => &1})}

      {:ok, %Req.Response{status: 200, body: %{"list" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Fetches a single feature type from the given workspace (across all datastores).

  ## Options

    - `:quiet_on_not_found` — when `true`, avoids logging an exception on 404

  ## Returns

    - `{:ok, featuretype}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, exception}` on transport error
  """
  def get_workspace_featuretype(%Connection{} = conn, workspace, featuretype_name, opts \\ []) do
    url = "#{conn.base_url}/workspaces/#{workspace}/featuretypes/#{featuretype_name}"

    url =
      if Keyword.get(opts, :quiet_on_not_found) do
        "#{url}?quietOnNotFound=true"
      else
        url
      end

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %Req.Response{status: 200, body: %{"featureType" => ft}}} ->
        {:ok, ft}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc """
  Creates a new feature type in the default data store for the workspace.

  The feature type definition must reference a store.

  ## Parameters

    - `params`: Same map as `create_featuretype/5`, plus optionally:
      - `store`: Map with `:name` to specify the target data store

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, reason}` on failure
  """
  def create_workspace_featuretype(
        %Connection{} = conn,
        workspace,
        featuretype_name,
        params \\ %{}
      ) do
    url = "#{conn.base_url}/workspaces/#{workspace}/featuretypes"

    body = build_featuretype_body(featuretype_name, params)

    body =
      if store = params[:store] do
        put_in(body, ["featureType", "store"], %{
          "@class" => "dataStore",
          "name" => store[:name]
        })
      else
        body
      end

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
  Updates a feature type in the default data store for the workspace.

  ## Parameters

    - `params`: Same map as `update_featuretype/5`
    - `recalculate`: Optional parameter to recalculate bounding boxes

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def update_workspace_featuretype(
        %Connection{} = conn,
        workspace,
        featuretype_name,
        params \\ %{},
        recalculate \\ nil
      ) do
    url = "#{conn.base_url}/workspaces/#{workspace}/featuretypes/#{featuretype_name}"
    url = if recalculate, do: "#{url}?recalculate=#{recalculate}", else: url

    body = %{"featureType" => build_featuretype_update_body(params)}

    case Req.put(
           url,
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
  Deletes a feature type from the default data store for the workspace.

  ## Parameters

    - `recurse`: If true, also deletes dependent layers (default: false)

  ## Returns

    - `{:ok, feature_type_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def delete_workspace_featuretype(
        %Connection{} = conn,
        workspace,
        featuretype_name,
        recurse \\ false
      ) do
    recurse_param = if recurse, do: "true", else: "false"

    url =
      "#{conn.base_url}/workspaces/#{workspace}/featuretypes/#{featuretype_name}?recurse=#{recurse_param}"

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

  defp add_bounding_boxes(ft, params) do
    ft =
      if native_bbox = params[:native_bbox] do
        Map.put(ft, "nativeBoundingBox", %{
          "minx" => native_bbox[:minx],
          "maxx" => native_bbox[:maxx],
          "miny" => native_bbox[:miny],
          "maxy" => native_bbox[:maxy],
          "crs" => native_bbox[:crs] || params[:native_crs] || params[:srs] || "EPSG:4326"
        })
      else
        ft
      end

    if latlon_bbox = params[:latlon_bbox] do
      Map.put(ft, "latLonBoundingBox", %{
        "minx" => latlon_bbox[:minx],
        "maxx" => latlon_bbox[:maxx],
        "miny" => latlon_bbox[:miny],
        "maxy" => latlon_bbox[:maxy],
        "crs" => "EPSG:4326"
      })
    else
      ft
    end
  end

  defp build_featuretype_update_body(params) do
    body = %{}

    body = maybe_put(body, params, "title")
    body = maybe_put(body, params, "description")
    body = maybe_put(body, params, "abstract")
    body = maybe_put(body, params, "srs")
    body = maybe_put(body, params, "nativeCRS")
    body = maybe_put(body, params, "enabled")
    body = maybe_put(body, params, "projectionPolicy", :projection_policy)
    body = maybe_put(body, params, "maxFeatures", :max_features)
    body = maybe_put(body, params, "numDecimals", :num_decimals)
    body = maybe_put(body, params, "cqlFilter", :cql_filter)
    body = maybe_put(body, params, "overridingServiceSRS", :overriding_service_srs)
    body = maybe_put(body, params, "skipNumberMatched", :skip_number_matched)
    body = maybe_put(body, params, "circularArcPresent", :circular_arc_present)
    body = maybe_put(body, params, "linearizationTolerance", :linearization_tolerance)

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

    body =
      if keywords = params[:keywords] do
        Map.put(body, "keywords", %{"string" => keywords})
      else
        body
      end

    body =
      if metadata = params[:metadata] do
        Map.put(body, "metadata", metadata)
      else
        body
      end

    body =
      if metadata_links = params[:metadata_links] do
        Map.put(body, "metadataLinks", %{"metadataLink" => metadata_links})
      else
        body
      end

    body =
      if data_links = params[:data_links] do
        Map.put(body, "dataLinks", %{"metadataLink" => data_links})
      else
        body
      end

    body =
      if response_srs = params[:response_srs] do
        Map.put(body, "responseSRS", %{"string" => response_srs})
      else
        body
      end

    body
  end

  defp maybe_put(body, params, json_key, atom_key \\ nil) do
    atom_key = if atom_key, do: atom_key, else: String.to_atom(json_key)

    if value = params[atom_key] do
      Map.put(body, json_key, value)
    else
      body
    end
  end
end
