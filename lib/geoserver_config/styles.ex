defmodule GeoserverConfig.Styles do
  @moduledoc """
  Handles style operations in GeoServer
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @spec list_styles() :: Req.Response.t()
  def list_styles() do
    url = "#{@base_url}/styles"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  def list_styles_workspace_specific(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/styles"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  @spec create_style(map()) :: {:ok, Req.Response.t()} | {:error, any()}
  def create_style(opts) do
    url = if opts[:workspace] do
      "#{@base_url}/workspaces/#{opts[:workspace]}/styles"
    else
      "#{@base_url}/styles"
    end

    headers = [
      {"Content-Type", "application/vnd.ogc.sld+xml"},
      {"Accept", "application/json"},
    ]

    query = [name: opts[:name]]
    query = if opts[:filename], do: Keyword.put(query, :filename, opts[:filename]), else: query

    case Req.post(
         url,
         auth: {:basic, "#{@username}:#{@password}"},
         headers: headers,
         body: opts[:sld_content],
         params: query,
         decode_body: false
       ) do
    {:ok, response} when response.status in 200..299 ->
      {:ok, "Style '#{opts[:name]}' created successfully"}

    {:ok, response} ->
      {:error, %{status: response.status, body: response.body}}

    {:error, reason} ->
      {:error, reason}
    end
  end

  @spec update_style(map()) :: {:ok, Req.Response.t()} | {:error, String.t() | Exception.t()}
  def update_style(opts) do
    url = if opts[:workspace] do
      "#{@base_url}/workspaces/#{opts[:workspace]}/styles/#{opts[:name]}"
    else
      "#{@base_url}/styles/#{opts[:name]}"
    end

    headers = [
      {"Content-Type", "application/vnd.ogc.sld+xml"},
      {"Accept", "application/json"}
    ]

    query = if opts[:filename], do: [filename: opts[:filename]], else: []

    try do
      case Req.put(
        url,
        auth: {:basic, "#{@username}:#{@password}"},
        headers: headers,
        body: opts[:sld_content],
        params: query,
        decode_body: false
      ) do
        {:ok, response} when response.status in 200..299 ->
          {:ok, "Style '#{opts[:name]}' updated successfully"}

        {:ok, %{status: status}} ->
          {:error, "Style '#{opts[:name]}' does not exist. Received HTTP status #{status}."}

        {:error, %{reason: reason}} ->
          {:error, reason}
      end
    rescue
      e -> {:error, e}
    end
  end

  # DELETE Method
  def delete_style(style_name, workspace \\ nil, opts \\ []) do
    # Build base URL
    url = if workspace do
      "#{@base_url}/workspaces/#{workspace}/styles/#{style_name}"
    else
      "#{@base_url}/styles/#{style_name}"
    end

    # Add query parameters
    query = []
    query = if Keyword.get(opts, :purge), do: Keyword.put(query, :purge, "true"), else: query
    query = if Keyword.get(opts, :recurse), do: Keyword.put(query, :recurse, "true"), else: query

    case Req.delete(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}],
      params: query
    ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, "Style '#{style_name}' deleted successfully"}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Style '#{style_name}' not found"}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to delete style (Status #{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

end
