defmodule GeoserverConfig.LayerGroupsTest do
  use ExUnit.Case, async: true

  import GeoserverConfig.Test.ConnHelper

  alias GeoserverConfig.LayerGroups

  describe "list_layer_groups/1" do
    test "returns {:ok, list} when groups exist" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "layerGroups" => %{
            "layerGroup" => [
              %{"name" => "group_a", "href" => "http://example.com/group_a"},
              %{"name" => "group_b", "href" => "http://example.com/group_b"}
            ]
          }
        })
      end)

      assert {:ok, groups} = LayerGroups.list_layer_groups(test_conn(__MODULE__))
      assert length(groups) == 2
    end

    test "returns {:ok, []} when there are no groups" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"layerGroups" => %{}})
      end)

      assert {:ok, []} = LayerGroups.list_layer_groups(test_conn(__MODULE__))
    end
  end

  describe "add_layer_to_group/4" do
    test "appends the new layer to an existing list and PUT the result" do
      parent = self()

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{
              "layerGroup" => %{
                "publishables" => %{
                  "published" => [
                    %{"@type" => "layer", "name" => "ws:existing_layer"}
                  ]
                }
              }
            })

          "PUT" ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            send(parent, {:put_body, Jason.decode!(body)})

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "{}")
        end
      end)

      assert {:ok, _} =
               LayerGroups.add_layer_to_group(test_conn(__MODULE__), "my_group", "ws:new_layer")

      assert_receive {:put_body, body}
      published = get_in(body, ["layerGroup", "publishables", "published"])
      assert length(published) == 2
      assert List.last(published)["name"] == "ws:new_layer"
    end

    test "handles a group that has no layers yet (empty publishables)" do
      parent = self()

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"layerGroup" => %{"publishables" => %{}}})

          "PUT" ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            send(parent, {:put_body, Jason.decode!(body)})

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "{}")
        end
      end)

      assert {:ok, _} =
               LayerGroups.add_layer_to_group(test_conn(__MODULE__), "my_group", "ws:first_layer", "ws:style1")

      assert_receive {:put_body, body}
      published = get_in(body, ["layerGroup", "publishables", "published"])
      assert length(published) == 1
      assert hd(published)["name"] == "ws:first_layer"
    end

    test "handles a group with a single layer returned as a map (GeoServer quirk)" do
      parent = self()

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.method do
          "GET" ->
            # GeoServer returns a map, not a list, when only one layer is in the group
            Req.Test.json(conn, %{
              "layerGroup" => %{
                "publishables" => %{
                  "published" => %{"@type" => "layer", "name" => "ws:only_layer"}
                }
              }
            })

          "PUT" ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            send(parent, {:put_body, Jason.decode!(body)})

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "{}")
        end
      end)

      assert {:ok, _} =
               LayerGroups.add_layer_to_group(test_conn(__MODULE__), "my_group", "ws:new_layer")

      assert_receive {:put_body, body}
      published = get_in(body, ["layerGroup", "publishables", "published"])
      # The single-map case must be normalised to a list before appending
      assert length(published) == 2
    end
  end

  describe "remove_layer_from_group/3" do
    test "removes the layer and PUT the result" do
      parent = self()

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{
              "layerGroup" => %{
                "publishables" => %{
                  "published" => [
                    %{"@type" => "layer", "name" => "ws:keep_me"},
                    %{"@type" => "layer", "name" => "ws:remove_me"}
                  ]
                }
              }
            })

          "PUT" ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            send(parent, {:put_body, Jason.decode!(body)})

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, "{}")
        end
      end)

      assert {:ok, _} =
               LayerGroups.remove_layer_from_group(test_conn(__MODULE__), "my_group", "ws:remove_me")

      assert_receive {:put_body, body}
      published = get_in(body, ["layerGroup", "publishables", "published"])
      assert length(published) == 1
      assert hd(published)["name"] == "ws:keep_me"
    end

    test "returns {:error, :layer_not_found} when layer is not in the group" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "layerGroup" => %{
            "publishables" => %{
              "published" => [%{"@type" => "layer", "name" => "ws:other_layer"}]
            }
          }
        })
      end)

      assert {:error, :layer_not_found} =
               LayerGroups.remove_layer_from_group(test_conn(__MODULE__), "my_group", "ws:ghost")
    end

    test "returns {:error, :layer_not_found} for an empty group" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"layerGroup" => %{"publishables" => %{}}})
      end)

      assert {:error, :layer_not_found} =
               LayerGroups.remove_layer_from_group(test_conn(__MODULE__), "my_group", "ws:any")
    end
  end
end
