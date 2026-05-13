defmodule GeoserverConfig.DatastoresTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.Datastores

  describe "list_datastores/2" do
    test "returns {:ok, list} when multiple datastores exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "dataStores" => %{
            "dataStore" => [
              %{"name" => "store_a", "href" => "http://example.com/store_a"},
              %{"name" => "store_b", "href" => "http://example.com/store_b"}
            ]
          }
        })
      end)

      assert {:ok, stores} = Datastores.list_datastores(test_conn(__MODULE__), "my_workspace")
      assert length(stores) == 2
    end

    test "normalises a single datastore map to a one-element list" do
      # GeoServer returns a map (not a list) when only one datastore exists.
      # This is a known quirk that must be handled correctly.
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "dataStores" => %{
            "dataStore" => %{"name" => "lone_store", "href" => "http://example.com/lone_store"}
          }
        })
      end)

      assert {:ok, [store]} = Datastores.list_datastores(test_conn(__MODULE__), "my_workspace")
      assert store["name"] == "lone_store"
    end

    test "returns {:ok, []} when there are no datastores" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"dataStores" => %{}})
      end)

      assert {:ok, []} = Datastores.list_datastores(test_conn(__MODULE__), "my_workspace")
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"error" => "Forbidden"}))
      end)

      assert {:error, {:http_error, 403, _}} =
               Datastores.list_datastores(test_conn(__MODULE__), "my_workspace")
    end
  end

  describe "create_datastore/5" do
    test "returns {:ok, name} on 201" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "my_store"} =
               Datastores.create_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "postgis",
                 %{host: "localhost", port: 5432, database: "db", user: "u", passwd: "p"}
               )
    end

    test "returns {:error, trimmed_string} when GeoServer responds 500 with plain text" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(500, "  Store already exists  ")
      end)

      assert {:error, "Store already exists"} =
               Datastores.create_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "duplicate",
                 "postgis",
                 %{host: "localhost", port: 5432, database: "db", user: "u", passwd: "p"}
               )
    end

    test "supports enhanced PostGIS connection parameters" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      params = %{
        host: "localhost",
        port: 5432,
        database: "db",
        user: "u",
        passwd: "p",
        schema: "custom_schema",
        "max connections": "20",
        "Loose bbox": "true"
      }

      assert {:ok, "enhanced_store"} =
               Datastores.create_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "enhanced_store",
                 "postgis",
                 params
               )
    end

    test "supports GeoPackage with table parameter" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "gpkg_store"} =
               Datastores.create_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "gpkg_store",
                 "geopkg",
                 %{database: "file:///path/to/file.gpkg", table: "my_table"}
               )
    end

    test "supports shapefile with charset parameter" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "shape_store"} =
               Datastores.create_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "shape_store",
                 "shapefile",
                 %{url: "file:///path/to/shapes", charset: "ISO-8859-1"}
               )
    end
  end

  describe "delete_datastore/4" do
    test "returns {:ok, name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "my_store"} =
               Datastores.delete_datastore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 true
               )
    end

    test "returns {:ok, name} without recurse flag (default false)" do
      Req.Test.stub(__MODULE__, fn conn ->
        # Req parses the query string out of request_path; check conn.query_string
        assert String.contains?(conn.query_string, "recurse=false")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "my_store"} =
               Datastores.delete_datastore(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "returns {:skipped, name} on 404 (idempotent delete)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:skipped, "my_store"} =
               Datastores.delete_datastore(test_conn(__MODULE__), "my_workspace", "my_store")
    end
  end
end
