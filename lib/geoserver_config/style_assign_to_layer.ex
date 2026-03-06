defmodule GeoserverConfig.StyleAssignToLayer do
  @moduledoc """
  Provides functionality to assign a style to a coverage layer in GeoServer.

  Verifies that the specified style exists (either globally or in a workspace)
  before attempting to assign it as the default style for a given layer.

  All functions require a `GeoserverConfig.Connection` as their first argument.

  ## Example

      conn = GeoserverConfig.Connection.from_env()
      {:ok, msg} = GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(conn, "demo_ws", "dem_layer", "dem_style")
  """

  alias GeoserverConfig.Connection

  @doc """
  Assigns a style to a layer as its default style, verifying the style exists first.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace` — workspace in which the layer resides
    - `layer_name` — name of the layer
    - `style_name` — name of the style to assign
    - `style_workspace` — workspace of the style, or `nil` to check globally (default: `nil`)

  ## Returns

    - `{:ok, message}` if the style was successfully assigned
    - `{:error, reason}` if the style does not exist or the assignment failed

  ## Examples

      GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(conn, "demo_ws", "dem_layer", "dem_style")
      GeoserverConfig.StyleAssignToLayer.assign_style_to_layer(conn, "demo_ws", "dem_layer", "dem_style", "style_ws")
  """
  def assign_style_to_layer(%Connection{} = conn, workspace, layer_name, style_name, style_workspace \\ nil) do
    check_result =
      if style_workspace do
        check_style_in_workspace(conn, style_name, style_workspace)
      else
        check_global_style(conn, style_name)
      end

    case check_result do
      {:ok, :exists} ->
        assign_style(conn, workspace, layer_name, style_name, style_workspace)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_style_in_workspace(%Connection{} = conn, style_name, style_workspace) do
    url = "#{conn.base_url}/workspaces/#{style_workspace}/styles/#{style_name}.json"

    case Req.get(url, auth: Connection.auth(conn), decode_body: false) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :exists}

      {:ok, %Req.Response{status: 404}} ->
        {:error,
         "Style '#{style_name}' does not exist in workspace '#{style_workspace}'."}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status, "Unexpected error checking style in workspace"}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp check_global_style(%Connection{} = conn, style_name) do
    url = "#{conn.base_url}/styles/#{style_name}.json"

    case Req.get(url, auth: Connection.auth(conn), decode_body: false) do
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

    case Req.put(url,
           auth: Connection.auth(conn),
           headers: [{"Content-Type", "application/json"}],
           body: body
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
end
