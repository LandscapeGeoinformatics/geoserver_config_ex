defmodule GeoserverConfig.LayerGroups do
  @moduledoc """
  Handles layer group operations in GeoServer.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @doc """
  Fetches a list of layer groups from the GeoServer.

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

  Expects a XML string `layer_group_xml` that contains the layer group details.
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
  Updates an existing layer group on GeoServer.

  `name` - the name of the layer group to update
  `layer_group_xml` - the updated XML body
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
  Deletes a layer group from GeoServer.

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
