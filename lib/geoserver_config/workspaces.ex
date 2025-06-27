defmodule GeoserverConfig.Workspaces do
  @moduledoc """
  A module for interacting with GeoServer workspaces.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  # GET: Fetch list of workspaces
  def fetch_workspaces do
    url = "#{@base_url}/workspaces"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  # POST: Create a new workspace
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

  # DELETE: Delete a workspace
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

  # PUT: Update an existing workspace
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
