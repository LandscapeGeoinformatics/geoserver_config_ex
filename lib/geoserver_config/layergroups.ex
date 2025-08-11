defmodule GeoserverConfig.LayerGroups do
  @moduledoc """
  Provides functionality to manage Layer Groups in GeoServer.

  Layer groups allow you to group multiple layers together for visualization or management
  purposes. This module supports listing, creating, updating, and deleting layer groups via
  GeoServer's REST API.

  ## Environment Variables

    - `GEOSERVER_BASE_URL` — The base URL of the GeoServer instance.
    - `GEOSERVER_USERNAME` — Username used for authentication.
    - `GEOSERVER_PASSWORD` — Password used for authentication.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @doc """
  Fetches a list of all layer groups available in the GeoServer.

  ## Returns
    - `Req.Response.t()` — The raw response containing the list of layer groups in JSON format.

  ## Example
      GeoserverConfig.list_layer_groups()
  """
  @spec list_layer_groups() :: Req.Response.t()
  def list_layer_groups do
    url = "#{@base_url}/layergroups"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  @doc """
  Creates a new layer group in GeoServer using either XML (string) or JSON (map).

  ## Parameters
    - `body` — Either a JSON map or XML string.

  ## Returns
    - `Req.Response.t()` — Success or Error response from GeoServer.

  ## Example
      GeoserverConfig.create_layer_group(xml_body)   # XML
      GeoserverConfig.create_layer_group(%{layerGroup: %{name: "my-group", layers: [...], styles: [...]}})  # JSON
  """
  @spec create_layer_group(String.t() | map()) :: Req.Response.t()
  def create_layer_group(body) do
    url = "#{@base_url}/layergroups"

    cond do
      is_binary(body) ->
        Req.post!(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [
            {"Content-Type", "application/xml"},
            {"Accept", "application/json"}
          ],
          body: body
        )

      is_map(body) ->
        Req.post!(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [
            {"Content-Type", "application/json"},
            {"Accept", "application/json"}
          ],
          json: body
        )
    end
  end

  @doc """
  Updates an existing layer group in GeoServer using either XML (string) or JSON (map).

  ## Parameters
    - `name` (`String.t`) — The name of the layer group to update.
    - `body` — Either a JSON map or XML string representing the updated layer group.

  ## Returns
    - `Req.Response.t()` — Success or Error response from GeoServer.

  ## Example
      GeoserverConfig.update_layer_group("layer-group", updated_xml)   # XML
      GeoserverConfig.update_layer_group("layer-group", %{layerGroup: %{layers: [...], styles: [...]}})  # JSON
  """
  @spec update_layer_group(String.t(), String.t() | map()) :: Req.Response.t()
  def update_layer_group(name, body)

  def update_layer_group(name, body) when is_binary(body) do
    url = "#{@base_url}/layergroups/#{name}"

    Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/xml"},
        {"Accept", "application/json"}
      ],
      body: body
    )
  end

  def update_layer_group(name, body) when is_map(body) do
    url = "#{@base_url}/layergroups/#{name}"

    Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      json: body
    )
  end


  @doc """
  Deletes a layer group from GeoServer by name.

  ## Parameters
    - `name` (`String.t`) — The name of the layer group to delete.

  ## Returns
    - `Req.Response.t()` — Success or Error response from GeoServer.

  ## Example
      GeoserverConfig.delete_layer_group("group1")
  """
  @spec delete_layer_group(String.t()) :: Req.Response.t()
  def delete_layer_group(name) when is_binary(name) do
    url = "#{@base_url}/layergroups/#{name}"

    Req.delete!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  @doc """
  Adds a new layer with an optional style to a GeoServer layer group.

  ## Parameters
    - `group_name`: Name of the layer group
    - `layer_name`: Name of the layer to add
    - `style_name`: Optional style to associate with the layer

  ## Example
      GeoserverConfig.add_layer_to_group("my_group", "sf:layer1", "sf:style1")
  """
  @spec add_layer_to_group(String.t(), String.t(), String.t() | nil) :: Req.Response.t()
  def add_layer_to_group(group_name, layer_name, style_name \\ nil) do
    url = "#{@base_url}/layergroups/#{group_name}.json"

    response = Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )

    group = response.body["layerGroup"]

    existing_layers =
      group
      |> Map.get("publishables", %{})
      |> Map.get("published", [])
      |> case do
        nil -> []
        list when is_list(list) -> list
        item -> [item]
      end

    new_layer = %{"@type" => "layer", "name" => layer_name}

    new_layer_with_style =
      if style_name do
        Map.put(new_layer, "styles", %{"style" => %{"name" => style_name}})
      else
        new_layer
      end

    updated_layers = existing_layers ++ [new_layer_with_style]

    updated_group_payload = %{
      "layerGroup" => %{
        "publishables" => %{
          "published" => updated_layers
        }
      }
    }

    update_layer_group(group_name, updated_group_payload)
  end

  @doc """
  Removes a layer from a GeoServer layer group.

  ## Parameters
    - `group_name`: Name of the layer group
    - `layer_name`: Name of the layer to remove

  ## Example
      GeoserverConfig.remove_layer_from_group("my_group", "sf:layer1")
  """
  @spec remove_layer_from_group(String.t(), String.t()) :: Req.Response.t()
  def remove_layer_from_group(group_name, layer_name) do
    url = "#{@base_url}/layergroups/#{group_name}.json"

    response = Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )

    group = response.body["layerGroup"]

    existing_layers =
      group
      |> Map.get("publishables", %{})
      |> Map.get("published", [])
      |> case do
        nil -> []
        list when is_list(list) -> list
        item -> [item]
      end

    updated_layers =
      Enum.reject(existing_layers, fn layer ->
        layer["name"] == layer_name
      end)

    updated_group_payload = %{
      "layerGroup" => %{
        "publishables" => %{
          "published" => updated_layers
        }
      }
    }

    update_layer_group(group_name, updated_group_payload)
  end

end
