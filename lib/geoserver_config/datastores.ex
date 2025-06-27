defmodule GeoserverConfig.Datastores do
  @moduledoc """
  A module for interacting with GeoServer datastores.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  # GET: List datastores for a specific workspace
  def list_datastores(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

  # POST: Create a new datastore
  def create_datastore(workspace, name, type, connection_params) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores"

    body = %{
      "dataStore" => %{
        "name" => name,
        "connectionParameters" => format_connection_params(type, connection_params),
        "enabled" => true,
        "featureTypes" => []
      }
    }

    response =
      Req.post!(
        url,
        auth: {:basic, "#{@username}:#{@password}"},
        json: body,
        headers: [{"Content-Type", "application/json"}],
        decode_body: false
      )

    case response.status do
      201 ->
        {:ok, "Datastore created successfully"}

      500 ->
        {:error, String.trim(response.body)} # Likely plain text error like "Store already exists"

      _ ->
        {:error, "Unexpected response (#{response.status}): #{inspect(response.body)}"}
    end
  end


  # Private method to format the connection parameters based on the datastore type
  defp format_connection_params("geopkg", %{database: db_path}) do
    %{"entry" => [
      %{"@key" => "database", "$" => db_path},
      %{"@key" => "dbtype", "$" => "geopkg"}
    ]}
  end

  defp format_connection_params("postgis", %{host: host, port: port, database: db, user: user, passwd: passwd }) do
    %{"entry" => [
      %{"@key" => "host", "$" => host},
      %{"@key" => "port", "$" => Integer.to_string(port)},
      %{"@key" => "database", "$" => db},
      %{"@key" => "user", "$" => user},
      %{"@key" => "passwd", "$" => passwd},
      %{"@key" => "dbtype", "$" => "postgis"},
      %{"@key" => "schema", "$" => "public"}
    ]}
  end

  defp format_connection_params("shapefile", %{url: file_url}) do
    %{"entry" => [%{"@key" => "url", "$" => file_url}]}
  end

  defp format_connection_params("wfs", %{capabilities_url: url}) do
    %{"entry" => [%{"@key" => "GET_CAPABILITIES_URL", "$" => url}]}
  end

  # PUT: Update an existing datastore
  def update_datastore(workspace, datastore_name, datastore_type, connection_params) do
    url = "#{@base_url}/workspaces/#{workspace}/datastores/#{datastore_name}"

    body = %{
      "dataStore" => %{
        "description" => connection_params[:description],
        "connectionParameters" => format_connection_params(datastore_type, connection_params),
        "enabled" => true
      }
    }

    response = Req.put!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      json: body,
      headers: [{"Content-Type", "application/json"}]
    )

    case response.status do
      200 -> IO.puts("Datastore #{datastore_name} successfully updated.")
      _ -> IO.puts("Failed to update datastore #{datastore_name}. Response Status: #{response.status}")
    end
  end

  # DELETE: Remove a datastore
  def delete_datastore(workspace, datastore_name, recurse \\ false) do
    recurse_param = if recurse, do: "true", else: "false"
    url = "#{@base_url}/workspaces/#{workspace}/datastores/#{datastore_name}?recurse=#{recurse_param}"

    response = Req.delete!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )

    case response.status do
      200 -> IO.puts("Datastore #{datastore_name} successfully deleted.")
      _ -> IO.puts("Failed to delete datastore #{datastore_name}. Response Status: #{response.status}")
    end
  end
end
