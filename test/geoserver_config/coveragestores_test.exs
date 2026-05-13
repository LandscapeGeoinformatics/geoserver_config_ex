defmodule GeoserverConfig.CoveragestoresTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.Coveragestores

  describe "list_coveragestores/2" do
    test "returns {:ok, list} when multiple stores exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "coverageStores" => %{
            "coverageStore" => [
              %{"name" => "store_a", "href" => "http://example.com/store_a"},
              %{"name" => "store_b", "href" => "http://example.com/store_b"}
            ]
          }
        })
      end)

      assert {:ok, stores} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")

      assert length(stores) == 2
    end

    test "normalises a single coverage store map to a one-element list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "coverageStores" => %{
            "coverageStore" => %{"name" => "lone_store", "href" => "http://example.com/lone_store"}
          }
        })
      end)

      assert {:ok, [store]} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")

      assert store["name"] == "lone_store"
    end

    test "returns {:ok, []} when there are no stores" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"coverageStores" => %{}})
      end)

      assert {:ok, []} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")
    end

    test "returns {:error, :unexpected_format, body} on unrecognised response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"something" => "else"})
      end)

      assert {:error, :unexpected_format, _} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Coveragestores.list_coveragestores(test_conn(__MODULE__), "my_workspace")
    end
  end

  describe "get_coveragestore/3" do
    test "returns {:ok, store} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "coverageStore" => %{
            "name" => "dem_store",
            "type" => "GeoTIFF",
            "enabled" => true,
            "workspace" => %{"name" => "my_workspace"}
          }
        })
      end)

      assert {:ok, store} =
               Coveragestores.get_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")

      assert store["name"] == "dem_store"
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coveragestores.get_coveragestore(test_conn(__MODULE__), "my_workspace", "missing")
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               Coveragestores.get_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")
    end
  end

  describe "create_coveragestore/6" do
    test "returns {:ok, store_name} on 201" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "dem_store"} =
               Coveragestores.create_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "dem_store",
                 "file:///path/to/dem.tif",
                 "A DEM store"
               )
    end

    test "returns {:ok, store_name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "dem_store"} =
               Coveragestores.create_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "dem_store",
                 "file:///path/to/dem.tif"
               )
    end

    test "supports COG store with extra opts" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      opts = %{
        metadata: %{
          "entry" => %{
            "@key" => "CogSettings.Key",
            "cogSettings" => %{"useCachingStream" => false}
          }
        },
        disableOnConnFailure: false
      }

      assert {:ok, "cog_store"} =
               Coveragestores.create_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "cog_store",
                 "cog://https://example.com/file.tif",
                 "COG store",
                 opts
               )
    end

    test "returns {:error, {:http_error, status, body}} on failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Already exists"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               Coveragestores.create_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "duplicate",
                 "file:///path/to/dem.tif"
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               Coveragestores.create_coveragestore(
                 test_conn(__MODULE__), "my_workspace", "fail", "file:///path.tif")
    end
  end

  describe "update_coveragestore/4" do
    test "returns {:ok, store_name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      updated = %{
        type: "GeoTIFF",
        enabled: true,
        url: "file:///new/path.tif",
        description: "Updated"
      }

      assert {:ok, "dem_store"} =
               Coveragestores.update_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "dem_store",
                 updated
               )
    end

    test "returns {:error, {:http_error, status, body}} on failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coveragestores.update_coveragestore(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "missing",
                 %{type: "GeoTIFF"}
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Coveragestores.update_coveragestore(
                 test_conn(__MODULE__), "my_workspace", "dem_store", %{type: "GeoTIFF"})
    end
  end

  describe "delete_coveragestore/3" do
    test "returns {:ok, name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "dem_store"} =
               Coveragestores.delete_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")
    end

    test "returns {:skipped, name} on 404 (idempotent delete)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:skipped, "dem_store"} =
               Coveragestores.delete_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")
    end

    test "returns {:error, {:http_error, status, body}} on other failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               Coveragestores.delete_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               Coveragestores.delete_coveragestore(test_conn(__MODULE__), "my_workspace", "dem_store")
    end
  end
end
