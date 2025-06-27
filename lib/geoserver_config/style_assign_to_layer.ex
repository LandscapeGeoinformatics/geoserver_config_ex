defmodule GeoserverConfig.StyleAssignToLayer do
  @moduledoc """
  Assigns a style to a coverage layer as its default style, only if the style exists.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @spec assign_style_to_layer(String.t(), String.t(), String.t(), String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def assign_style_to_layer(workspace, layer_name, style_name, style_workspace \\ nil) do
    # First, attempt to find the style exactly where specified (or globally if nil)
    check_result =
      if style_workspace do
        # If style_workspace is provided, strictly check within that workspace
        check_style_existence_in_workspace(style_name, style_workspace)
      else
        # If style_workspace is nil, strictly check globally
        check_global_style_existence(style_name)
      end

    case check_result do
      {:ok, :exists} ->
        # Style found exactly where it was supposed to be checked
        assign_style(workspace, layer_name, style_name, style_workspace)

      {:error, reason} ->
        # Style not found, or an error occurred during check
        {:error, reason}
    end
  end

  defp check_style_existence_in_workspace(style_name, style_workspace) do
    url = "#{@base_url}/workspaces/#{style_workspace}/styles/#{style_name}.json"
    case Req.get(url, auth: {:basic, "#{@username}:#{@password}"}, decode_body: false) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :exists}
      {:ok, %Req.Response{status: 404}} ->
        {:error, "Style Workspace '#{style_workspace}' doesn't exist or #{style_name}' does not exist in workspace '#{style_workspace}'."}
      {:ok, %Req.Response{status: status}} ->
        {:error, "Unexpected error while checking style in workspace (status #{status})."}
      {:error, reason} ->
        {:error, "Failed to check style existence in workspace: #{inspect(reason)}"}
    end
  end

  defp check_global_style_existence(style_name) do
    url = "#{@base_url}/styles/#{style_name}.json"
    case Req.get(url, auth: {:basic, "#{@username}:#{@password}"}, decode_body: false) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, :exists}
      {:ok, %Req.Response{status: 404}} ->
        {:error, "Style '#{style_name}' does not exist globally."}
      {:ok, %Req.Response{status: status}} ->
        {:error, "Unexpected error while checking global style (status #{status})."}
      {:error, reason} ->
        {:error, "Failed to check global style existence: #{inspect(reason)}"}
    end
  end

  defp assign_style(workspace, layer_name, style_name, style_workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/layers/#{layer_name}"

    style_ref =
      if style_workspace do
        %{"workspace" => style_workspace, "name" => style_name}
      else
        %{"name" => style_name}
      end

    body =
      %{
        "layer" => %{
          "defaultStyle" => style_ref
        }
      }
      |> Jason.encode!()

    case Req.put(
           url,
           auth: {:basic, "#{@username}:#{@password}"},
           headers: [{"Content-Type", "application/json"}],
           body: body
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, "Style '#{style_name}' successfully assigned to layer '#{layer_name}'."}

      {:ok, %Req.Response{status: 401}} ->
        {:error, "Unauthorized: Check your GeoServer credentials."}

      {:ok, %Req.Response{status: 500}} ->
        {:error, "Internal Server Error: GeoServer failed to process the request. Check your workspace, layer, or style name."}

      {:ok, %Req.Response{status: status}} ->
        {:error, "Unexpected error (status #{status})."}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end
end
