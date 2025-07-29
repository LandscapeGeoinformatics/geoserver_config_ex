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
  Creates a new layer group in GeoServer.

  ## Parameters
    - `layer_group_xml` (`String.t`) — An XML string defining the layer group structure and configuration.

  ## Returns
    - `Req.Response.t()` — Success or Error response from GeoServer.

  ## Example
      GeoserverConfig.LayerGroups.create_layer_group(xml_string)
  """
  @spec create_layer_group(String.t()) :: Req.Response.t()
  def create_layer_group(layer_group_xml) when is_binary(layer_group_xml) do
    url = "#{@base_url}/layergroups"

    Req.post!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/xml"},
        {"Accept", "application/json"}
      ],
      body: layer_group_xml
    )
  end

  @doc """
  Updates an existing layer group in GeoServer.

  ## Parameters
    - `name` (`String.t`) — The name of the layer group to update.
    - `layer_group_xml` (`String.t`) — The updated XML content for the layer group.

  ## Returns
    - `Req.Response.t()` — Success or Error response from GeoServer.

  ## Example
      GeoserverConfig.LayerGroups.update_layer_group("group1", updated_xml)
  """
  @spec update_layer_group(String.t(), String.t()) :: Req.Response.t()
  def update_layer_group(name, layer_group_xml)
      when is_binary(name) and is_binary(layer_group_xml) do
    url = "#{@base_url}/layergroups/#{name}"

    Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/xml"},
        {"Accept", "application/json"}
      ],
      body: layer_group_xml
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

end
