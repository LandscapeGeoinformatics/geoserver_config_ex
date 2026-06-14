defmodule GeoserverConfig.Styles do
  @moduledoc """
  Provides functions to manage styles in GeoServer via the REST API.

  All functions require a `GeoserverConfig.Connection` as their first argument,
  except `write_sld_file/2` which is a local file operation.
  """

  alias GeoserverConfig.Connection

  @doc """
  Lists all global styles available in GeoServer.

  ## Returns

    - `{:ok, [style]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
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

  ## Returns

    - `{:ok, [style]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, reason}}` on transport error
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

    case Req.get(
           url,
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
    - `opts` — map with:
      - `:name` (required) — style name
      - `:content` (required) — style content (SLD XML or CSS)
      - `:format` — `:sld` (default) or `:css`
      - `:workspace` — workspace name (optional, nil for global)
      - `:filename` — filename (optional)
      - `:title` — style title (optional)
      - `:abstract` — style description (optional)
      - `:keywords` — list of keywords (optional)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, %{status: status, body: body}}` on HTTP failure
    - `{:error, reason}` on transport error
  """
  def create_style(%Connection{} = conn, opts) do
    # Validate required parameters
    with {:ok, _} <- validate_create_opts(opts),
         {:ok, content_type} <- detect_content_type(opts),
         {:ok, headers} <- build_headers(content_type) do
      url =
        if opts[:workspace] do
          "#{conn.base_url}/workspaces/#{opts[:workspace]}/styles"
        else
          "#{conn.base_url}/styles"
        end

      query = [name: opts[:name]]
      query = if opts[:filename], do: Keyword.put(query, :filename, opts[:filename]), else: query

      case Req.post(
             url,
             Connection.req_opts(conn) ++
               [
                 headers: headers ++ [{"Accept", "application/json"}],
                 body: opts[:content],
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
    else
      error -> error
    end
  end

  @doc false
  defp validate_create_opts(opts) do
    cond do
      !opts[:name] -> {:error, "Missing required parameter :name"}
      !opts[:content] -> {:error, "Missing required parameter :content"}
      true -> {:ok, :valid}
    end
  end

  @doc false
  defp detect_content_type(opts) do
    # Explicit format takes precedence
    case opts[:format] do
      :css ->
        {:ok, "application/vnd.geoserver.geocss+css"}

      :sld_11 ->
        # SLD 1.1.0 / Symbology Encoding — requires a distinct MIME type so that
        # GeoServer parses it with its SE parser rather than the SLD 1.0.0 parser.
        {:ok, "application/vnd.ogc.se+xml"}

      :sld ->
        # Auto-detect SLD version from content so that 1.1.0 documents get the
        # correct MIME type (application/vnd.ogc.se+xml).  SLD 1.0.0 stays on
        # application/vnd.ogc.sld+xml.
        detect_sld_version(opts[:content])

      nil ->
        # Auto-detect from content or filename
        detect_from_content(opts[:content], opts[:filename])

      _ ->
        {:error, "Invalid format. Use :sld, :sld_11, or :css"}
    end
  end

  # Scans the full content for the SLD version attribute.  The attribute often
  # appears after several hundred bytes of namespace declarations, so a short
  # prefix check is not reliable.
  @doc false
  defp detect_sld_version(content) when is_binary(content) do
    if String.contains?(content, ~s|version="1.1.0"|) do
      {:ok, "application/vnd.ogc.se+xml"}
    else
      {:ok, "application/vnd.ogc.sld+xml"}
    end
  end

  defp detect_sld_version(_), do: {:ok, "application/vnd.ogc.sld+xml"}

  @doc false
  defp detect_from_content(content, filename) do
    # Try to detect from filename first
    case detect_from_filename(filename) do
      {:ok, content_type} ->
        {:ok, content_type}

      :unknown ->
        # Try to detect from content
        detect_from_content_string(content)
    end
  end

  @doc false
  defp detect_from_filename(nil), do: :unknown

  defp detect_from_filename(filename) when is_binary(filename) do
    filename = String.downcase(filename)

    cond do
      String.ends_with?(filename, ".css") -> {:ok, "application/vnd.geoserver.geocss+css"}
      String.ends_with?(filename, ".sld") -> {:ok, "application/vnd.ogc.sld+xml"}
      String.ends_with?(filename, ".xml") -> {:ok, "application/vnd.ogc.sld+xml"}
      true -> :unknown
    end
  end

  @doc false
  defp detect_from_content_string(content) when is_binary(content) do
    # Use first 200 chars to identify the document type; version detection
    # (detect_sld_version/1) scans the full content separately.
    content_str = String.trim(String.slice(content, 0, 200))

    cond do
      String.contains?(content_str, "StyledLayerDescriptor") ->
        detect_sld_version(content)

      String.contains?(content_str, "/*") || String.contains?(content_str, "*/") ->
        {:ok, "application/vnd.geoserver.geocss+css"}

      String.contains?(content_str, "{") && String.contains?(content_str, "}") ->
        {:ok, "application/vnd.geoserver.geocss+css"}

      # Default to SLD
      true ->
        {:ok, "application/vnd.ogc.sld+xml"}
    end
  end

  @doc false
  defp build_headers(content_type), do: {:ok, [{"Content-Type", content_type}]}

  @doc """
  Updates an existing style's content.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `opts` — map with:
      - `:name` (required) — style name
      - `:content` (required) — style content (SLD XML or CSS)
      - `:format` — `:sld` (default) or `:css`
      - `:workspace` — workspace name (optional, nil for global)
      - `:filename` — filename (optional)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, reason}}` on transport error
  """
  def update_style(%Connection{} = conn, opts) do
    # Validate required parameters
    with {:ok, _} <- validate_update_opts(opts),
         {:ok, content_type} <- detect_content_type(opts),
         {:ok, headers} <- build_headers(content_type) do
      url =
        if opts[:workspace] do
          "#{conn.base_url}/workspaces/#{opts[:workspace]}/styles/#{opts[:name]}"
        else
          "#{conn.base_url}/styles/#{opts[:name]}"
        end

      query = if opts[:filename], do: [filename: opts[:filename]], else: []

      case Req.put(
             url,
             Connection.req_opts(conn) ++
               [
                 headers: headers ++ [{"Accept", "application/json"}],
                 body: opts[:content],
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
    else
      error -> error
    end
  end

  @doc false
  defp validate_update_opts(opts) do
    cond do
      !opts[:name] -> {:error, "Missing required parameter :name"}
      !opts[:content] -> {:error, "Missing required parameter :content"}
      true -> {:ok, :valid}
    end
  end

  @doc """
  Copies a style from one workspace to another or between workspace and global scope.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `source_style` — name of the style to copy
    - `source_workspace` — source workspace, or `nil` for global styles
    - `target_style` — name for the copied style (can be same as source)
    - `target_workspace` — target workspace, or `nil` for global scope
    - `opts` — options including `:format` (:sld or :css, auto-detected if nil)

  ## Returns

    - `{:ok, target_style}` on success
    - `{:error, reason}` on failure
  """
  def copy_style(
        %Connection{} = conn,
        source_style,
        source_workspace,
        target_style,
        target_workspace,
        opts \\ []
      ) do
    # Get the source style content
    case get_style(conn, source_workspace, source_style) do
      {:ok, content} ->
        # Determine format if not specified
        format = opts[:format] || detect_format_from_content(content)

        # Create the target style
        create_opts = %{
          name: target_style,
          content: content,
          format: format
        }

        # Add workspace if specified
        create_opts =
          if target_workspace,
            do: Map.put(create_opts, :workspace, target_workspace),
            else: create_opts

        create_style(conn, create_opts)

      {:error, {:not_found, _}} ->
        {:error, {:not_found, source_style}}

      {:error, {:http_error, status, body}} ->
        {:error, {:http_error, status, body}}

      {:error, {:request_failed, reason}} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Moves a style from one workspace to another or between workspace and global scope.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `style_name` — name of the style to move
    - `source_workspace` — source workspace, or `nil` for global styles
    - `target_workspace` — target workspace, or `nil` for global scope
    - `opts` — options including `:purge` (boolean, default false)

  ## Returns

    - `{:ok, style_name}` on success
    - `{:error, reason}` on failure
  """
  def move_style(%Connection{} = conn, style_name, source_workspace, target_workspace, opts \\ []) do
    # Copy the style first
    case copy_style(conn, style_name, source_workspace, style_name, target_workspace) do
      {:ok, _} ->
        # Delete the original style
        delete_opts = []

        delete_opts =
          if Keyword.get(opts, :purge),
            do: Keyword.put(delete_opts, :purge, true),
            else: delete_opts

        delete_style(conn, style_name, source_workspace, delete_opts)

      error ->
        error
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
    - `{:skipped, style_name}` if the style does not exist (idempotent)
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
      |> then(fn q ->
        if Keyword.get(opts, :purge), do: Keyword.put(q, :purge, "true"), else: q
      end)
      |> then(fn q ->
        if Keyword.get(opts, :recurse), do: Keyword.put(q, :recurse, "true"), else: q
      end)

    case Req.delete(
           url,
           Connection.req_opts(conn) ++
             [headers: [{"Accept", "application/json"}], params: query]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, style_name}

      {:ok, %Req.Response{status: 404}} ->
        {:skipped, style_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @doc false
  defp detect_format_from_content(content) when is_binary(content) do
    content_str = String.trim(String.slice(content, 0..100))

    cond do
      String.contains?(content_str, "StyledLayerDescriptor") -> :sld
      String.contains?(content_str, "/*") || String.contains?(content_str, "*/") -> :css
      String.contains?(content_str, "{") && String.contains?(content_str, "}") -> :css
      # Default to SLD
      true -> :sld
    end
  end
end
