defmodule PlugHTTPValidator do
  @moduledoc """
  Documentation for `PlugHTTPValidator`.
  """

  @default_updated_at_field :updated_at

  @type opts :: [opt()]
  @type opt :: {:updated_at_field, any()} | {:etag_field, any()}

  @type objects :: [object()]
  @type object :: %{optional(:updated_at) => DateTime.t(), any() => any()}

  @spec set(Plug.Conn.t(), objects() | object(), opts()) :: Plug.Conn.t()
  def set(conn, object_or_objects, opts \\ [])

  def set(conn, [], _opts) do
    conn
  end

  def set(conn, [_ | _] = objects, opts) do
    conn
    |> set_last_modified(objects, opts)
    |> set_etag(objects, opts)
  end

  def set(conn, object, opts) do
    set(conn, [object], opts)
  end

  defp set_last_modified(conn, objects, opts) do
    updated_at_field = opts[:updated_at_field] || @default_updated_at_field

    objects
    |> Enum.map(&Map.get(&1, updated_at_field))
    |> Enum.filter(&match?(%DateTime{}, &1))
    |> case do
      [] ->
        conn

      updated_at_list ->
        most_recent = Enum.max(updated_at_list, DateTime)

        last_modified =
          most_recent
          |> DateTime.shift_zone!("Etc/UTC")
          |> Calendar.strftime("%a, %d %b %Y %X GMT")

        Plug.Conn.put_resp_header(conn, "last-modified", last_modified)
    end
  end

  defp set_etag(conn, objects, opts) do
    if opts[:etag_field] do
      etag =
        objects
        |> Enum.map(&Map.fetch!(&1, opts[:etag_field]))
        |> :erlang.term_to_binary()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode64()

      Plug.Conn.put_resp_header(conn, "etag", ~s|"#{etag}"|)
    else
      conn
    end
  end
end
