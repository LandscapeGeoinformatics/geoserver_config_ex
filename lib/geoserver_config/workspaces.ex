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

    - `{:ok, [workspace]}` on success
    - `{:error, {:http_error, status, body}}` on non-200 response
    - `{:error, {:request_failed, message}}` on transport error
  """
  def fetch_workspaces(%Connection{} = conn) do
    url = "#{conn.base_url}/workspaces"

    case Req.get(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
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

  ## Returns

    - `{:ok, workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def create_workspace(%Connection{} = conn, workspace_name) do
    url = "#{conn.base_url}/workspaces"

    case Req.post(url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
               json: %{"workspace" => %{"name" => workspace_name}}
             ]
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

  ## Returns

    - `{:ok, workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def delete_workspace(%Connection{} = conn, workspace_name) do
    url = "#{conn.base_url}/workspaces/#{workspace_name}"

    case Req.delete(url, Connection.req_opts(conn) ++ [headers: [{"Accept", "application/json"}]]) do
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

  ## Returns

    - `{:ok, new_workspace_name}` on success
    - `{:error, {:http_error, status, body}}` on failure
    - `{:error, {:request_failed, message}}` on transport error
  """
  def update_workspace(%Connection{} = conn, old_workspace_name, new_workspace_name) do
    url = "#{conn.base_url}/workspaces/#{old_workspace_name}"

    case Req.put(url,
           Connection.req_opts(conn) ++
             [
               headers: [{"Content-Type", "application/json"}, {"Accept", "application/json"}],
               json: %{"workspace" => %{"name" => new_workspace_name}}
             ]
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
