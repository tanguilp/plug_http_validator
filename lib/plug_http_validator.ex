defmodule PlugHTTPValidator do
  @moduledoc """
  Documentation for `PlugHTTPValidator`.
  """

  @default_updated_at_field :updated_at

  @type opts :: [opt()]
  @type opt :: {:updated_at_field, any()} | {:etag_field, any()} | {:etag_strength, :weak | :strong}

  @type objects :: [object()]
  @type object :: %{optional(:updated_at) => DateTime.t(), any() => any()}

  @doc """
  Sets HTTP validators using the object(s) passed into parameter

  Call this plug before sending the response, for example:

      def index(conn, _params) do
        posts = MyApp.list_posts()

        conn
        |> PlugHTTPValidator.set(posts)
        |> render("index.json", posts: posts)
      end

      def create(conn, params) do
        with {:ok, post} <- MyApp.create_post(params) do
          conn
          |> put_status(:created)
          |> put_resp_header("location", Routes.post_path(conn, :show, post))
          |> PlugHTTPValidator.set(post)
          |> render("show.json", post: post)
        end
      end

      def show(conn, %{"id" => id}) do
        with {:ok, post} = MyApp.get_post(id) do
          conn
          |> PlugHTTPValidator.set(post)
          |> render("show.txt", post: post)
        end
      end

  By default, this function sets the `last-modified` response header using the `:updated_at`
  field of the object(s), taking the most recent if there are more than one object.

  ## Options

  - `:updated_at_field`: the date field to use to set the `last-modified` header. Defaults to
  `:update_at`. The field **must** be a `t:DateTime.t/0` struct
  - `:etag_field`: the field to set the etag from. No default, that is by default no `etag`
  response header is set. The etag field must be present in the object(s) passed as a parameter,
  otherwise the call will crash. Make sure to understand what an etag is before using it
  - `:etag_strength`: the strenght of the etag, `:weak` or `:strong`. Defaults to `:weak`
  """
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
        |> Base.encode64(padding: false)
        |> set_etag_strength(opts)

      Plug.Conn.put_resp_header(conn, "etag", etag)
    else
      conn
    end
  end

  defp set_etag_strength(etag, opts) do
    if opts[:etag_strength] == :strong, do: ~s|"#{etag}"|, else: ~s|W/"#{etag}"|
  end
end
