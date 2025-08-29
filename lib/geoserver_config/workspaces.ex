defmodule GeoserverConfig.Workspaces do
  @moduledoc """
  Provides functions for interacting with GeoServer workspaces via its REST API.

  This module supports fetching the list of workspaces, creating a new workspace,
  deleting an existing one, and updating the name of a workspace. Authentication is handled
  using basic auth credentials set in the environment variables.

  ## Environment Variables

    - `GEOSERVER_BASE_URL` — Base URL of the GeoServer instance
    - `GEOSERVER_USERNAME` — Username for authentication
    - `GEOSERVER_PASSWORD` — Password for authentication
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  @doc """
  Fetches the list of all available workspaces from the GeoServer.

  ## Returns
    - `%Req.Response{}` struct with the response from GeoServer

  ## Example
      GeoserverConfig.Workspaces.fetch_workspaces()
  """

  def fetch_workspaces do
    url = "#{@base_url}/workspaces"

    case Req.get(url,
          auth: {:basic, "#{@username}:#{@password}"},
          headers: [{"Accept", "application/json"}]
        ) do
      {:ok, %Req.Response{status: 200, body: %{"workspaces" => %{"workspace" => workspaces}}}}
      when is_list(workspaces) ->
        {:ok, workspaces}

      {:ok, %Req.Response{status: 200, body: %{"workspaces" => _}}} ->
        {:ok, []}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Creates a new workspace in the GeoServer.

  ## Parameters
    - `workspace_name` (`String.t`) — The name of the workspace to be created.

  ## Output
    - Prints success or failure message to the console.

  ## Example
      GeoserverConfig.Workspaces.create_workspace("demo_workspace")
  """
  def create_workspace(workspace_name) do
    url = "#{@base_url}/workspaces"

    response = Req.post!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/xml"}
      ],
      json: %{"workspace" => %{"name" => workspace_name}}
    )

    case response.status do
      201 -> IO.puts("Workspace '#{workspace_name}' created successfully!")
      _ -> IO.puts("Failed to create workspace: #{response.status}")
    end
  end

  @doc """
  Deletes an existing workspace from the GeoServer.

  ## Parameters
    - `workspace_name` (`String.t`) — The name of the workspace to be deleted.

  ## Output
    - Prints success or failure message to the console.

  ## Example
      GeoserverConfig.Workspaces.delete_workspace("demo_workspace")
  """
  def delete_workspace(workspace_name) do
    url = "#{@base_url}/workspaces/#{workspace_name}"

    response = Req.delete!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/xml"}]
    )

    case response.status do
      200 -> IO.puts("Workspace '#{workspace_name}' deleted successfully!")
      _ -> IO.puts("Failed to delete workspace: #{response.status}")
    end
  end

  @doc """
  Updates the name of an existing workspace in the GeoServer.

  ## Parameters
    - `old_workspace_name` (`String.t`) — Current name of the workspace.
    - `new_workspace_name` (`String.t`) — New desired name of the workspace.

  ## Output
    - Prints success or failure message to the console.

  ## Example
      GeoserverConfig.Workspaces.update_workspace("old_ws", "new_ws")
  """
  def update_workspace(old_workspace_name, new_workspace_name) do
    url = "#{@base_url}/workspaces/#{old_workspace_name}"

    body = %{
      "workspace" => %{
        "name" => new_workspace_name
      }
    }

    response = Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [
        {"Content-Type", "application/json"},
        {"Accept", "application/json"}
      ],
      json: body
    )

    case response.status do
      200 -> IO.puts("Workspace '#{old_workspace_name}' updated to '#{new_workspace_name}' successfully!")
      _ -> IO.puts("Failed to update workspace: #{response.status}")
    end
  end
end
