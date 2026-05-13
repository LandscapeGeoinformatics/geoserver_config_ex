defmodule GeoserverConfig.LayerGroups do
  @moduledoc """
  Provides functionality to manage Layer Groups in GeoServer via the REST API.

  All functions require a `GeoserverConfig.Connection` as their first argument.
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all layer groups in GeoServer.

  When `workspace` is provided, only layer groups in that workspace are returned
  (hitting `/workspaces/:workspace/layergroups`). Without a workspace argument,
  the global `/layergroups` endpoint is used.

  GeoServer returns a map instead of a list when only one group exists, and
  returns the string `""` instead of an empty map when no groups exist; both
  cases are normalised to a list.

  ## Returns

    - `{:ok, [group]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def list_layer_groups(%Connection{} = conn) do
    do_list_layer_groups(conn, "#{conn.base_url}/layergroups")
  end

  @doc """
  Lists layer groups scoped to a specific workspace.

  ## Returns

    - `{:ok, [group]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
  """

  def list_layer_groups(%Connection{} = conn, workspace) do
    do_list_layer_groups(conn, "#{conn.base_url}/workspaces/#{workspace}/layergroups")
  end

  defp do_list_layer_groups(%Connection{} = conn, url) do
    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %{status: 200, body: %{"layerGroups" => %{"layerGroup" => groups}}}}
      when is_list(groups) ->
        {:ok, groups}

      {:ok, %{status: 200, body: %{"layerGroups" => %{"layerGroup" => group}}}}
      when is_map(group) ->
        {:ok, [group]}

      # GeoServer returns "" (empty string) instead of an empty map when no groups exist.
      {:ok, %{status: 200, body: %{"layerGroups" => _}}} ->
        {:ok, []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Creates a new layer group in GeoServer.

  Accepts either an XML string or a JSON map as the body.

  ## Returns

    - `{:ok, body}` on success (2xx)
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def create_layer_group(%Connection{} = conn, body) do
    url = "#{conn.base_url}/layergroups"
    do_post(conn, url, body)
  end

  @doc """
  Updates an existing layer group.

  Accepts either an XML string or a JSON map as the body.

  ## Returns

    - `{:ok, body}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def update_layer_group(%Connection{} = conn, name, body) do
    url = "#{conn.base_url}/layergroups/#{name}"
    do_put(conn, url, body)
  end

  @doc """
  Deletes a layer group from GeoServer by name.

  ## Returns

    - `{:ok, name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def delete_layer_group(%Connection{} = conn, name) when is_binary(name) do
    url = "#{conn.base_url}/layergroups/#{name}"

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

  @doc """
  Adds a layer with an optional style to a GeoServer layer group.

  Fetches the current group state and appends the new layer before updating.
  If a style name is provided, it is also appended to the group-level
  `styles` array to maintain the layer:style count parity required by GeoServer.

  ## Returns

    - `{:ok, body}` on success
    - `{:error, reason}` on failure
  """
  def add_layer_to_group(%Connection{} = conn, group_name, layer_name, style_name \\ nil) do
    with {:ok, group} <- fetch_group(conn, group_name) do
      existing_layers = normalize_list(get_in(group, ["publishables", "published"]))
      existing_styles = normalize_list(get_in(group, ["styles", "style"]))

      new_layer = %{"@type" => "layer", "name" => layer_name}

      updated_payload = %{
        "layerGroup" => %{
          "publishables" => %{"published" => existing_layers ++ [new_layer]}
        }
      }

      updated_payload =
        if style_name do
          new_style = %{"name" => style_name}

          put_in(updated_payload, ["layerGroup", "styles"], %{
            "style" => existing_styles ++ [new_style]
          })
        else
          updated_payload
        end

      update_layer_group(conn, group_name, updated_payload)
    end
  end

  @doc """
  Removes a layer from a GeoServer layer group.

  Fetches the current group state and filters out the named layer before updating.
  If the group has a matching number of styles, the corresponding style at the
  same index is also removed to maintain layer:style parity.

  ## Returns

    - `{:ok, body}` on success
    - `{:error, :layer_not_found}` if the layer is not in the group
    - `{:error, reason}` on other failure
  """
  def remove_layer_from_group(%Connection{} = conn, group_name, layer_name) do
    with {:ok, group} <- fetch_group(conn, group_name) do
      existing_layers = normalize_list(get_in(group, ["publishables", "published"]))
      existing_styles = normalize_list(get_in(group, ["styles", "style"]))

      case Enum.find_index(existing_layers, fn l -> l["name"] == layer_name end) do
        nil ->
          {:error, :layer_not_found}

        index ->
          updated_layers = List.delete_at(existing_layers, index)

          updated_payload = %{
            "layerGroup" => %{
              "publishables" => %{"published" => updated_layers}
            }
          }

          updated_payload =
            if length(existing_layers) == length(existing_styles) and
                 index < length(existing_styles) do
              updated_styles = List.delete_at(existing_styles, index)
              put_in(updated_payload, ["layerGroup", "styles"], %{"style" => updated_styles})
            else
              updated_payload
            end

          update_layer_group(conn, group_name, updated_payload)
      end
    end
  end

  @doc """
  Fetches a single layer group by name from GeoServer.

  ## Returns

    - `{:ok, group}` on success (a map with the layer group details as JSON)
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def get_layer_group(%Connection{} = conn, group_name) do
    fetch_group(conn, group_name)
  end

  defp fetch_group(%Connection{} = conn, group_name) do
    url = "#{conn.base_url}/layergroups/#{group_name}.json"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
      {:ok, %{status: 200, body: %{"layerGroup" => group}}} ->
        {:ok, group}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  # GeoServer returns a single map when there is only one item; normalise to always be a list.
  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(item), do: [item]

  defp do_post(%Connection{} = conn, url, body) when is_binary(body) do
    case Req.post(
           url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/xml"}, {"Accept", "application/json"}],
               body: body
             ]
         ) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_post(%Connection{} = conn, url, body) when is_map(body) do
    case Req.post(
           url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
               json: body
             ]
         ) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_put(%Connection{} = conn, url, body) when is_binary(body) do
    case Req.put(
           url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/xml"}, {"Accept", "application/json"}],
               body: body
             ]
         ) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp do_put(%Connection{} = conn, url, body) when is_map(body) do
    case Req.put(
           url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
               json: body
             ]
         ) do
      {:ok, %Req.Response{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:error, {:http_error, status, resp_body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
