defmodule GeoserverConfig.Styles do
  @moduledoc """
  Provides functions to manage styles in GeoServer via REST API.

  Supports listing global and workspace-specific styles, creating new styles,
  updating existing styles, and deleting styles with optional purge and recurse options.

  ## Environment Variables

    - `GEOSERVER_BASE_URL` — Base URL of the GeoServer instance.
    - `GEOSERVER_USERNAME` — Username for authentication.
    - `GEOSERVER_PASSWORD` — Password for authentication.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @doc """
  Lists all global styles available in GeoServer.

  ## Returns
    - `%Req.Response{}` with a JSON list of styles.

  ## Example
      GeoserverConfig.Styles.list_styles()
  """
  @spec list_styles() :: {:ok, list()} | {:error, any()}
  def list_styles do
    url = "#{@base_url}/styles"

    case Req.get(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [{"Accept", "application/json"}]
        ) do
      {:ok, %{status: 200, body: %{"styles" => %{"style" => styles}}}} when is_list(styles) ->
        {:ok, styles}

      {:ok, %{status: 200, body: %{"styles" => %{}}}} ->
        {:ok, []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Lists all styles scoped to a specific workspace.

  ## Parameters
    - `workspace` (`String.t`) — The name of the workspace.

  ## Returns
    - `%Req.Response{}` containing the styles in the given workspace.

  ## Example
      GeoserverConfig.Styles.list_styles_workspace_specific("demo")
  """
  @spec list_styles_workspace_specific(String.t()) :: {:ok, list()} | {:error, any()}
  def list_styles_workspace_specific(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/styles"

    case Req.get(
          url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [{"Accept", "application/json"}]
        ) do
      {:ok, %{status: 200, body: %{"styles" => %{"style" => styles}}}} when is_list(styles) ->
        {:ok, styles}

      {:ok, %{status: 200, body: %{"styles" => %{}}}} ->
        {:ok, []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Creates a new style in GeoServer using Geoserver REST API.

  ## Parameters
    - `opts` (`map`) — Options for creating the style:
      - `:name` (required) — Name of the style.
      - `:sld_content` (required) — Raw SLD XML content.
      - `:workspace` (optional) — Target workspace for the style.
      - `:filename` (optional) — Filename to associate with the style.

  ## Returns
    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example
      GeoserverConfig.Styles.create_style(%{
        name: "dem_style",
        filename: "dem_style.sld",
        sld_content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>",
        workspace: "demo"
      })
  """
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


  @doc """
  Updates an existing style's SLD content.

  ## Parameters

    - `opts` (`map`) — Options for updating the style:
      - `:name` (required) — Style name to update.
      - `:sld_content` (required) — Updated SLD XML content.
      - `:workspace` (optional) — Workspace, if the style is workspace-scoped.
      - `:filename` (optional) — Optional filename parameter.

  ## Returns

    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example

      GeoserverConfig.Styles.update_style(%{
        name: "dem_style",
        filename: "updated_dem_style.sld",
        sld_content: "<StyledLayerDescriptor>...</StyledLayerDescriptor>",
        workspace: "demo"
      })
  """
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

  @doc """
  Deletes a style from GeoServer.

  ## Parameters
    - `style_name` (`String.t`) — The name of the style to delete.
    - `workspace` (`String.t`, optional) — The workspace of the style (for workspace-scoped styles).
    - `opts` (`Keyword list`, optional):
      - `:purge` (`boolean`) — If `true`, removes all style resources.
      - `:recurse` (`boolean`) — Set to `true`, if style is assigned to certain layer.

  ## Returns
    - `{:ok, message}` on success
    - `{:error, reason}` on failure

  ## Example
      GeoserverConfig.Styles.delete_style("dem_style", "demo_workspace", purge: true, recurse: true)
  """
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
