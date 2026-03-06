defmodule GeoserverConfig.WorkspacesTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.Workspaces

  describe "fetch_workspaces/1" do
    test "returns {:ok, list} when workspaces exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "workspaces" => %{
            "workspace" => [
              %{"name" => "ws1", "href" => "http://geoserver.test/rest/workspaces/ws1.json"},
              %{"name" => "ws2", "href" => "http://geoserver.test/rest/workspaces/ws2.json"}
            ]
          }
        })
      end)

      assert {:ok, workspaces} = Workspaces.fetch_workspaces(test_conn(__MODULE__))
      assert length(workspaces) == 2
      assert Enum.any?(workspaces, &(&1["name"] == "ws1"))
    end

    test "returns {:ok, []} when there are no workspaces" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"workspaces" => %{}})
      end)

      assert {:ok, []} = Workspaces.fetch_workspaces(test_conn(__MODULE__))
    end

    test "returns {:error, {:http_error, status, body}} on non-200 response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => "Unauthorized"}))
      end)

      assert {:error, {:http_error, 401, _}} = Workspaces.fetch_workspaces(test_conn(__MODULE__))
    end

    test "returns {:error, {:request_failed, _}} on transport error" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} = Workspaces.fetch_workspaces(test_conn(__MODULE__))
    end
  end

  describe "create_workspace/2" do
    test "returns {:ok, name} on 201 Created" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, "")
      end)

      assert {:ok, "new_ws"} = Workspaces.create_workspace(test_conn(__MODULE__), "new_ws")
    end

    test "returns {:error, {:http_error, 409, _}} on conflict" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(409, Jason.encode!(%{"error" => "Workspace already exists"}))
      end)

      assert {:error, {:http_error, 409, _}} =
               Workspaces.create_workspace(test_conn(__MODULE__), "existing_ws")
    end
  end

  describe "delete_workspace/2" do
    test "returns {:ok, name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "old_ws"} = Workspaces.delete_workspace(test_conn(__MODULE__), "old_ws")
    end

    test "returns {:error, {:http_error, 404, _}} when workspace not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not found"}))
      end)

      assert {:error, {:http_error, 404, _}} =
               Workspaces.delete_workspace(test_conn(__MODULE__), "ghost_ws")
    end
  end

  describe "update_workspace/3" do
    test "returns {:ok, new_name} on 200" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, "")
      end)

      assert {:ok, "new_name"} =
               Workspaces.update_workspace(test_conn(__MODULE__), "old_name", "new_name")
    end
  end
end
