defmodule GeoserverConfig.CoveragesTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.Coverages

  describe "list_coverages/3" do
    test "returns {:ok, list} when multiple coverages exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "coverages" => %{
            "coverage" => [
              %{"name" => "dem_a", "href" => "http://example.com/dem_a"},
              %{"name" => "dem_b", "href" => "http://example.com/dem_b"}
            ]
          }
        })
      end)

      assert {:ok, coverages} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")

      assert length(coverages) == 2
    end

    test "returns {:ok, []} when there are no coverages" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"coverages" => %{}})
      end)

      assert {:ok, []} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "returns {:ok, []} when coverages is an empty string" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"coverages" => ""})
      end)

      assert {:ok, []} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "returns {:error, :unexpected_format, body} on unrecognised response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :unexpected_format, _} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Coverages.list_coverages(test_conn(__MODULE__), "my_workspace", "my_store")
    end
  end

  describe "get_coverage/4" do
    test "returns {:ok, coverage} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "coverage" => %{
            "name" => "dem_layer",
            "title" => "DEM Layer",
            "srs" => "EPSG:4326",
            "enabled" => true
          }
        })
      end)

      assert {:ok, coverage} =
               Coverages.get_coverage(test_conn(__MODULE__), "my_workspace", "my_store", "dem_layer")

      assert coverage["name"] == "dem_layer"
    end

    test "returns {:error, {:http_error, status, body}} on non-200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coverages.get_coverage(test_conn(__MODULE__), "my_workspace", "my_store", "missing")
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Coverages.get_coverage(test_conn(__MODULE__), "my_workspace", "my_store", "dem_layer")
    end
  end

  describe "create_coverage/6" do
    test "returns {:ok, coverage_name} on 2xx" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      params = %{
        title: "DEM Layer",
        srs: "EPSG:3301",
        native_crs: "EPSG:3301",
        native_bbox: %{minx: 369_000.0, maxx: 740_000.0, miny: 6_377_000.0, maxy: 6_635_000.0},
        latlon_bbox: %{minx: 21.664, maxx: 28.275, miny: 57.471, maxy: 59.831},
        grid: %{dimension: [3710, 2580], transform: [10.0, 0.0, 369_000.0, 0.0, -10.0, 6_635_000.0]}
      }

      assert {:ok, "dem_layer"} =
               Coverages.create_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer",
                 params,
                 "file:///path/to/dem.tif"
               )
    end

    test "returns {:error, {:http_error, status, body}} on failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal error"}))
      end)

      params = %{
        title: "Bad Layer",
        srs: "EPSG:4326",
        native_bbox: %{minx: 0, maxx: 1, miny: 0, maxy: 1},
        latlon_bbox: %{minx: 0, maxx: 1, miny: 0, maxy: 1},
        grid: %{dimension: [100, 100], transform: [0.01, 0.0, 0.0, 0.0, -0.01, 1.0]}
      }

      assert {:error, {:http_error, 500, _}} =
               Coverages.create_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "bad_layer",
                 params,
                 "file:///bad/path.tif"
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      params = %{
        title: "Layer",
        srs: "EPSG:4326",
        native_bbox: %{minx: 0, maxx: 1, miny: 0, maxy: 1},
        latlon_bbox: %{minx: 0, maxx: 1, miny: 0, maxy: 1},
        grid: %{dimension: [100, 100], transform: [0.01, 0.0, 0.0, 0.0, -0.01, 1.0]}
      }

      assert {:error, {:request_failed, _}} =
               Coverages.create_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "bad_layer",
                 params,
                 "file:///path.tif"
               )
    end
  end

  describe "update_coverage/5" do
    test "returns {:ok, coverage_name} on 2xx" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      params = %{title: "Updated DEM", description: "Updated description"}

      assert {:ok, "dem_layer"} =
               Coverages.update_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer",
                 params
               )
    end

    test "returns {:error, {:http_error, status, body}} on failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Coverages.update_coverage(
                 test_conn(__MODULE__), "my_workspace", "my_store", "missing", %{title: "Nope"}
               )
    end

    test "handles bounding box and metadata in update params" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      params = %{
        title: "Updated",
        native_bbox: %{minx: 0, maxx: 100, miny: 0, maxy: 100},
        latlon_bbox: %{minx: 0, maxx: 100, miny: 0, maxy: 100},
        metadata: %{"cacheAgeMax" => 3600},
        keywords: ["raster", "elevation"]
      }

      assert {:ok, "dem_layer"} =
               Coverages.update_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer",
                 params
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               Coverages.update_coverage(
                 test_conn(__MODULE__), "my_workspace", "my_store", "dem_layer", %{title: "X"}
               )
    end
  end

  describe "delete_coverage/5" do
    test "returns {:ok, coverage_name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "dem_layer"} =
               Coverages.delete_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer",
                 true
               )
    end

    test "returns {:ok, coverage_name} without recurse flag (default false)" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.params == %{}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "dem_layer"} =
               Coverages.delete_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer"
               )
    end

    test "returns {:skipped, coverage_name} on 404 (idempotent delete)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "")
      end)

      assert {:skipped, "dem_layer"} =
               Coverages.delete_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer"
               )
    end

    test "returns {:error, {:http_error, status, body}} on other failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, {:http_error, 500, _}} =
               Coverages.delete_coverage(
                 test_conn(__MODULE__),
                 "my_workspace",
                 "my_store",
                 "dem_layer"
               )
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Coverages.delete_coverage(
                 test_conn(__MODULE__), "my_workspace", "my_store", "dem_layer"
               )
    end
  end
end
