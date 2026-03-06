defmodule GeoserverConfig.Test.ConnHelper do
  @moduledoc false

  @doc """
  Builds a Connection with a Req.Test plug already set, using the given stub name.
  All Req calls made through this connection go to the stub instead of the network.
  """
  def test_conn(stub_name) do
    %GeoserverConfig.Connection{
      base_url: "http://geoserver.test/geoserver/rest",
      username: "admin",
      password: "geoserver",
      plug: {Req.Test, stub_name}
    }
  end
end
