defmodule GeoserverConfig.Workspaces do
  @moduledoc """
  Provides functions for interacting with GeoServer workspaces via its REST API.

  All functions require a `GeoserverConfig.Connection` as their first argument.

  ## Example

      conn = GeoserverConfig.Connection.from_env()
      {:ok, workspaces} = GeoserverConfig.Workspaces.fetch_workspaces(conn)
  """

  alias GeoserverConfig.Connection

  @doc """
  Fetches the list of all available workspaces from GeoServer.

  ## Returns

    - `{:ok, [workspace]}` — list of workspace maps on success
    - `{:error, {:http_error, status, body}}` — non-200 HTTP response
    - `{:error, {:request_failed, message}}` — transport/connection error

  ## Example

      {:ok, workspaces} = GeoserverConfig.Workspaces.fetch_workspaces(conn)
  """
  def fetch_workspaces(%Connection{} = conn) do
    url = "#{conn.base_url}/workspaces"

    case Req.get(url,
           auth: Connection.auth(conn),
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
  Creates a new workspace in GeoServer.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace_name` — name of the workspace to create

  ## Returns

    - `{:ok, workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error

  ## Example

      {:ok, "demo_workspace"} = GeoserverConfig.Workspaces.create_workspace(conn, "demo_workspace")
  """
  def create_workspace(%Connection{} = conn, workspace_name) do
    url = "#{conn.base_url}/workspaces"

    case Req.post(url,
           auth: Connection.auth(conn),
           headers: [
             {"Content-Type", "application/json"},
             {"Accept", "application/json"}
           ],
           json: %{"workspace" => %{"name" => workspace_name}}
         ) do
      {:ok, %Req.Response{status: 201}} ->
        {:ok, workspace_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Deletes an existing workspace from GeoServer.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `workspace_name` — name of the workspace to delete

  ## Returns

    - `{:ok, workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error

  ## Example

      {:ok, "demo_workspace"} = GeoserverConfig.Workspaces.delete_workspace(conn, "demo_workspace")
  """
  def delete_workspace(%Connection{} = conn, workspace_name) do
    url = "#{conn.base_url}/workspaces/#{workspace_name}"

    case Req.delete(url,
           auth: Connection.auth(conn),
           headers: [{"Accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, workspace_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end

  @doc """
  Updates the name of an existing workspace in GeoServer.

  ## Parameters

    - `conn` — a `GeoserverConfig.Connection`
    - `old_workspace_name` — current name of the workspace
    - `new_workspace_name` — desired new name

  ## Returns

    - `{:ok, new_workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error

  ## Example

      {:ok, "new_ws"} = GeoserverConfig.Workspaces.update_workspace(conn, "old_ws", "new_ws")
  """
  def update_workspace(%Connection{} = conn, old_workspace_name, new_workspace_name) do
    url = "#{conn.base_url}/workspaces/#{old_workspace_name}"

    body = %{"workspace" => %{"name" => new_workspace_name}}

    case Req.put(url,
           auth: Connection.auth(conn),
           headers: [
             {"Content-Type", "application/json"},
             {"Accept", "application/json"}
           ],
           json: body
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, new_workspace_name}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, exception} ->
        {:error, {:request_failed, Exception.message(exception)}}
    end
  end
end
