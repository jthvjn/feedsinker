defmodule FeedSink.FeedSourceAdapter do
  @type feeds_map_t :: %{String.t() => map()}
  @type source_t :: String.t()
  @type message_t :: String.t()

  @callback normalize(feeds_map_t) ::
              {:ok, [%FeedSink.Feed{}], source_t} | {:error, message_t, source_t}
  @callback get_url() :: String.t()
  @callback source() :: source_t
end
