defmodule PlugHTTPValidatorTest do
  use ExUnit.Case
  use Plug.Test

  test "sets last-modified header for single object" do
    object = %{updated_at: ~U[2022-08-07 01:02:03.133742Z]}

    conn = conn(:get, "/") |> PlugHTTPValidator.set(object)

    last_modified = Enum.find_value(conn.resp_headers, fn
      {"last-modified", last_modified} -> last_modified
      _ -> nil
    end)

    assert last_modified == "Sun, 07 Aug 2022 01:02:03 GMT"
  end

  test "sets last-modified header for list of objects object" do
    object = [
      %{updated_at: ~U[2017-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2021-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2020-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2022-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2019-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2018-08-07 01:02:03.133742Z]},
      %{updated_at: ~U[2016-08-07 01:02:03.133742Z]}
    ]

    conn = conn(:get, "/") |> PlugHTTPValidator.set(object)

    last_modified = Enum.find_value(conn.resp_headers, fn
      {"last-modified", last_modified} -> last_modified
      _ -> nil
    end)

    assert last_modified == "Sun, 07 Aug 2022 01:02:03 GMT"
  end

  test "sets last-modified header for single object with custom field" do
    object = %{
      :updated_at => ~U[2021-08-07 01:02:03.133742Z],
      "the_field" => ~U[2022-08-07 01:02:03.133742Z]
    }

    conn = conn(:get, "/") |> PlugHTTPValidator.set(object, updated_at_field: "the_field")

    last_modified = Enum.find_value(conn.resp_headers, fn
      {"last-modified", last_modified} -> last_modified
      _ -> nil
    end)

    assert last_modified == "Sun, 07 Aug 2022 01:02:03 GMT"
  end

  test "sets weak etag by default from one object" do
    object = %{revision_uuid: "some-uuid-that-changes-on-each-update"}

    conn = conn(:get, "/") |> PlugHTTPValidator.set(object, etag_field: :revision_uuid)

    etag = Enum.find_value(conn.resp_headers, fn
      {"etag", last_modified} -> last_modified
      _ -> nil
    end)

    assert Regex.match?(~r|W/".+"|, etag)
  end

  test "sets weak etag by default from several object" do
    objects = [
      %{revision_uuid: "some-uuid-that-changes-on-each-update"},
      %{revision_uuid: "some-other-uuid-that-changes-on-each-update"}
    ]

    conn = conn(:get, "/") |> PlugHTTPValidator.set(objects, etag_field: :revision_uuid)

    etag = Enum.find_value(conn.resp_headers, fn
      {"etag", last_modified} -> last_modified
      _ -> nil
    end)

    assert Regex.match?(~r|W/".+"|, etag)
  end

  test "sets strong etag by default from one object" do
    object = %{revision_uuid: "some-uuid-that-changes-on-each-update"}

    conn = conn(:get, "/") |> PlugHTTPValidator.set(object, etag_field: :revision_uuid, etag_strength: :strong)

    etag = Enum.find_value(conn.resp_headers, fn
      {"etag", last_modified} -> last_modified
      _ -> nil
    end)

    assert Regex.match?(~r|".+"|, etag)
  end
end
