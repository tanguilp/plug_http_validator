# PlugHTTPValidator

Set HTTP validators to Plug responses

## When and why use it

As soon as you send cacheable content, you **should** set HTTP validators because it helps HTTP
caches **a lot**:
- it allows revalidating requests with great efficiency, with the `if-modified-since` and
`if-none-match` headers. In this case:
  - an HTTP request with one or both revalidation headers is sent
  - if a gateway on the path (especially an HTTP cache) already has a fresh copy of the object, it can
  return a `304` response code **without the body**
- `last-modified` can be used to calculate heuristic freshness, that is how long a response is
cacheable, in case there's no explicit caching directives
- it can be used to efficiently refresh cached response from HEAD requests

There are two HTTP validators:
- `etag` (might be strong or weak)
- `last-modified` (necessarily weak)

Although using a strong validator is to be preferred (more optimisations possible), it is not
always possible because you need a unique identifier for each revision of your objects (e.g
database entries). For instance, this is hard to achieve with Ecto.

However, using a weak validator like `last-modified` is very helpful for caches as well, so do it!

## Usage

`PlugHTTPValidator.set/3` sets HTTP validators using the object(s) passed into parameter.

Call it before sending the response, for example:

    def index(conn, _params) do
      posts = MyApp.list_posts()

      conn
      |> PlugHTTPValidator.set(posts)
      |> render("index.json", posts: posts)
    end

    def create(conn, params) do
      # 201 status code is not cacheable by default

      with {:ok, post} <- MyApp.create_post(params) do
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.post_path(conn, :show, post))
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

### Options

- `:updated_at_field`: the date field to use to set the `last-modified` header. Defaults to
`:update_at`. The field **must** be a `t:DateTime.t/0` struct
- `:etag_field`: the field to set the etag from. No default, that is by default no `etag`
response header is set. The etag field must be present in the object(s) passed as a parameter,
otherwise the call will crash. Make sure to understand what an etag is before using it
- `:etag_strength`: the strenght of the etag, `:weak` or `:strong`. Defaults to `:weak`

## Installation

```elixir
def deps do
  [
    {:plug_http_validator, "~> 0.1.0"}
  ]
end
```

This plug was inspired by [`phoenix_etag`](https://github.com/michalmuskala/phoenix_etag),
which seems outdated.
