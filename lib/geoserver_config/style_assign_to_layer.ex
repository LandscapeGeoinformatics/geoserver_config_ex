defmodule GeoserverConfig.StyleAssignToLayer do
  @moduledoc """
  Provides functionality to assign a style to a layer in GeoServer.

  Verifies that the specified style exists before attempting to assign it as
  the default style for a given layer. All functions require a
  `GeoserverConfig.Connection` as their first argument.
  """

  alias GeoserverConfig.Connection

  @doc """
  Assigns a style to a layer as its default style, verifying the style exists first.

  Pass `nil` or `""` as `style_name` to remove the current default style
  (same as calling `unassign_style_from_layer/3`).

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace in which the layer resides
    - `layer_name` — name of the layer
    - `style_name` — name of the style to assign, or `nil`/`""` to unassign
    - `style_workspace` — workspace of the style, or `nil` to check globally (default: `nil`)

  ## Returns

    - `{:ok, message}` if the style was successfully assigned
    - `{:error, reason}` if the style does not exist or the assignment failed
  """
  def assign_style_to_layer(
        %Connection{} = conn,
        workspace,
        layer_name,
        style_name,
        style_workspace \\ nil
      ) do
    if is_nil(style_name) or style_name == "" do
      unassign_style(conn, workspace, layer_name)
    else
      check_result =
        if style_workspace do
          check_style_in_workspace(conn, style_name, style_workspace)
        else
          check_global_style(conn, style_name)
        end

      case check_result do
        {:ok, :exists} -> assign_style(conn, workspace, layer_name, style_name, style_workspace)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Removes the default style assignment from a layer (resets to no default style).

  Equivalent to calling `assign_style_to_layer(conn, ws, layer, nil)`.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace in which the layer resides
    - `layer_name` — name of the layer

  ## Returns

    - `{:ok, message}` if the style was successfully unassigned
    - `{:error, reason}` on failure
  """
  def unassign_style_from_layer(%Connection{} = conn, workspace, layer_name) do
    unassign_style(conn, workspace, layer_name)
  end

  defp check_style_in_workspace(%Connection{} = conn, style_name, style_workspace) do
    url = "#{conn.base_url}/workspaces/#{style_workspace}/styles/#{style_name}.json"

    case Req.get(url, Connection.req_opts(conn) ++ [decode_body: false]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :exists}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Style '#{style_name}' does not exist in workspace '#{style_workspace}'."}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status, "Unexpected error checking style in workspace"}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp check_global_style(%Connection{} = conn, style_name) do
    url = "#{conn.base_url}/styles/#{style_name}.json"

    case Req.get(url, Connection.req_opts(conn) ++ [decode_body: false]) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :exists}

      {:ok, %Req.Response{status: 404}} ->
        {:error, "Style '#{style_name}' does not exist globally."}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status, "Unexpected error checking global style"}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp assign_style(%Connection{} = conn, workspace, layer_name, style_name, style_workspace) do
    url = "#{conn.base_url}/workspaces/#{workspace}/layers/#{layer_name}"

    style_ref =
      if style_workspace do
        %{"workspace" => style_workspace, "name" => style_name}
      else
        %{"name" => style_name}
      end

    body = Jason.encode!(%{"layer" => %{"defaultStyle" => style_ref}})

    case Req.put(
           url,
           Connection.req_opts(conn) ++
             [headers: [{"Content-Type", "application/json"}], body: body]
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, "Style '#{style_name}' successfully assigned to layer '#{layer_name}'."}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp unassign_style(%Connection{} = conn, workspace, layer_name) do
    url = "#{conn.base_url}/workspaces/#{workspace}/layers/#{layer_name}"

    body = Jason.encode!(%{"layer" => %{"defaultStyle" => nil}})

    case Req.put(
           url,
           Connection.req_opts(conn) ++
             [headers: [{"Content-Type", "application/json"}], body: body]
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, "Default style successfully removed from layer '#{layer_name}'."}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end
end
