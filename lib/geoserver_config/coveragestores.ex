defmodule GeoserverConfig.Coveragestores do
  @moduledoc """
  A module for interacting with GeoServer coveragestores.
  """

  @base_url System.get_env("GEOSERVER_BASE_URL")
  @username System.get_env("GEOSERVER_USERNAME")
  @password System.get_env("GEOSERVER_PASSWORD")

  # GET: List coverage stores
  def list_coveragestores(workspace) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores"

    Req.get!(
      url,
      auth: {:basic, "#{@username}:#{@password}"},
      headers: [{"Accept", "application/json"}]
    )
  end

 # POST: Create a new coverage store
 def create_coveragestore(workspace, store_name, geotiff_path, description \\ "", opts \\ %{}) do
  base_url = "#{@base_url}/workspaces/#{workspace}/coveragestores"

  store_body = %{
    "coverageStore" => %{
      "name" => store_name,
      "description" => description,
      "type" => "GeoTIFF",
      "enabled" => true,
      "workspace" => %{"name" => workspace},
      "url" => "#{geotiff_path}",
      "default" => true
    }
  }

  # Merge COG GeoTIFF fields
  |> Map.update!("coverageStore", fn cs ->
    cs
    |> Map.merge(Map.take(opts, [:connectionParameters, :metadata, :disableOnConnFailure]))
  end)

  # Send the request to create the coverage store
  store_response = Req.post(
    base_url,
    auth: {:basic, "#{@username}:#{@password}"},
    json: store_body,
    headers: [{"Content-Type", "application/json"}],
    decode_body: false
  )

  case store_response do
    {:ok, %Req.Response{status: status}} when status in [200, 201] ->
      {:ok, "Coverage store created successfully."}

    {:ok, %Req.Response{status: status, body: body}} ->
      {:error, "Failed to create coverage store. Status: #{status}, Response: #{inspect(body)}"}

    {:error, reason} ->
      {:error, "Request error during coverage store creation: #{inspect(reason)}"}
  end
end


  # PUT: Update a coverage store
  def update_coveragestore(workspace, store_name, updated_params) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{store_name}"

    body = %{
      "coverageStore" => %{
        "name" => store_name,
        "type" => updated_params[:type],
        "enabled" => updated_params[:enabled],
        "workspace" => %{"name" => workspace},
        "url" => updated_params[:url],
        "description" => updated_params[:description]
      }
    }

    case Req.put(
           url,
           auth: {:basic, "#{@username}:#{@password}"},
           json: body,
           headers: [{"Content-Type", "application/json"}]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 201] ->
        {:ok, "Coverage store updated successfully."}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to update coverage store. Status: #{status}, Response: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request error during coverage store update: #{inspect(reason)}"}
    end
  end

  # DELETE: Remove a coverage store
  def delete_coveragestore(workspace, name) do
    url = "#{@base_url}/workspaces/#{workspace}/coveragestores/#{name}?purge=true"

    case Req.delete(
           url,
           auth: {:basic, "#{@username}:#{@password}"},
           headers: [{"Accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        {:ok, "Coverage store deleted successfully."}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "Failed to delete coverage store. Status: #{status}, Response: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Request error during coverage store deletion: #{inspect(reason)}"}
    end
  end

  # POST: Create multiple coverage stores from CSV
  # def create_coveragestores_from_csv(csv_file_path) do

  #   csv_file_path
  #   |> File.stream!()
  #   |> CSV.decode(headers: true)
  #   |> Enum.each(fn
  #     {:ok, row} ->
  #       case create_coveragestore(
  #         row["workspace"],
  #         row["store_name"],
  #         row["geotiff_path"],
  #         row["description"] || ""
  #       ) do
  #         {:ok, msg} ->
  #           IO.puts("Successfully created coverage store '#{row["store_name"]}': #{msg}")

  #         {:error, reason} ->
  #           IO.puts("Failed to create '#{row["store_name"]}': #{inspect(reason)}")
  #       end

  #     {:error, reason} ->
  #       IO.puts("CSV parsing error: #{inspect(reason)}")
  #   end)
  # end

end
