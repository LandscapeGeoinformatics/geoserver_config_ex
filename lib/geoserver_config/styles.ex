defmodule GeoserverConfig.Styles do
  @moduledoc """
  Provides functions to manage styles in GeoServer via the REST API.

  All functions require a `GeoserverConfig.Connection` as their first argument,
  except `write_sld_file/2` which is a local file operation.
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all global styles available in GeoServer.
  """
  def list_styles(%Connection{} = conn) do
    url = "#{conn.base_url}/styles"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
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
  """
  def list_styles_workspace_specific(%Connection{} = conn, workspace) do
    url = "#{conn.base_url}/workspaces/#{workspace}/styles"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
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
  Retrieves the SLD content for a specific style.

  Pass `nil` or `""` as `workspace` to fetch a global style.

  ## Returns

    - `{:ok, sld_content}` on success
    - `{:error, {:not_found, style_name}}` when the style does not exist
    - `{:error, {:http_error, status, body}}` on other HTTP failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def get_style(%Connection{} = conn, workspace, style_name) do
    url =
      case workspace do
        nil -> "#{conn.base_url}/styles/#{style_name}.sld"
        "" -> "#{conn.base_url}/styles/#{style_name}.sld"
        ws -> "#{conn.base_url}/workspaces/#{ws}/styles/#{style_name}.sld"
      end

    case Req.get(url,
           Connection.req_opts(conn) ++
             [headers: [{"Accept", "application/vnd.ogc.sld+xml, application/xml"}]]
         ) do
      {:ok, %{status: 200, body: sld_content}} when is_binary(sld_content) ->
        {:ok, sld_content}

      {:ok, %{status: 404}} ->
        {:error, {:not_found, style_name}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Writes SLD content to a local file. Does not require a connection.

  ## Returns

    - `{:ok, %{file_path: path, size: bytes}}` on success
    - `{:error, {:file_write_failed, reason, file_path}}` on failure
  """
  def write_sld_file(style_file_path, sld_content) do
    case File.write(style_file_path, sld_content) do
      :ok -> {:ok, %{file_path: style_file_path, size: byte_size(sld_content)}}
      {:error, reason} -> {:error, {:file_write_failed, reason, style_file_path}}
    end
  end

  @doc """
  Creates a new style in GeoServer.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `opts` — map with `:name`, `:sld_content` (required); `:workspace`, `:filename` (optional)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, %{status: status, body: body}}` on HTTP failure
    - `{:error, reason}` on transport error
  """
  def create_style(%Connection{} = conn, opts) do
    url =
      if opts[:workspace] do
        "#{conn.base_url}/workspaces/#{opts[:workspace]}/styles"
      else
        "#{conn.base_url}/styles"
      end

    query = [name: opts[:name]]
    query = if opts[:filename], do: Keyword.put(query, :filename, opts[:filename]), else: query

    case Req.post(url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/vnd.ogc.sld+xml"}, {"Accept", "application/json"}],
               body: opts[:sld_content],
               params: query,
               decode_body: false
             ]
         ) do
      {:ok, response} when response.status in 200..299 ->
        {:ok, opts[:name]}

      {:ok, response} ->
        {:error, %{status: response.status, body: response.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates an existing style's SLD content.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `opts` — map with `:name`, `:sld_content` (required); `:workspace`, `:filename` (optional)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def update_style(%Connection{} = conn, opts) do
    url =
      if opts[:workspace] do
        "#{conn.base_url}/workspaces/#{opts[:workspace]}/styles/#{opts[:name]}"
      else
        "#{conn.base_url}/styles/#{opts[:name]}"
      end

    query = if opts[:filename], do: [filename: opts[:filename]], else: []

    case Req.put(url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/vnd.ogc.sld+xml"}, {"Accept", "application/json"}],
               body: opts[:sld_content],
               params: query,
               decode_body: false
             ]
         ) do
      {:ok, response} when response.status in 200..299 ->
        {:ok, opts[:name]}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Deletes a style from GeoServer.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `style_name` — name of the style to delete
    - `workspace` — workspace of the style, or `nil` for global styles (default: `nil`)
    - `opts` — `:purge` and/or `:recurse` (both boolean, default false)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, {:not_found, style_name}}` if the style does not exist
    - `{:error, {:http_error, status, body}}` on other HTTP failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def delete_style(%Connection{} = conn, style_name, workspace \\ nil, opts \\ []) do
    url =
      if workspace do
        "#{conn.base_url}/workspaces/#{workspace}/styles/#{style_name}"
      else
        "#{conn.base_url}/styles/#{style_name}"
      end

    query =
      []
      |> then(fn q -> if Keyword.get(opts, :purge), do: Keyword.put(q, :purge, "true"), else: q end)
      |> then(fn q -> if Keyword.get(opts, :recurse), do: Keyword.put(q, :recurse, "true"), else: q end)

    case Req.delete(url,
           Connection.req_opts(conn) ++
             [headers: [{"Accept", "application/json"}], params: query]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, style_name}

      {:ok, %Req.Response{status: 404}} ->
        {:error, {:not_found, style_name}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
