defmodule CoAP.Message.Option do
  @repeatable_options [
    :if_match,
    :etag,
    :location_path,
    :uri_path,
    :uri_query,
    :location_query
  ]

  @unsigned_options [
    :uri_port,
    :max_age,
    :accept,
    :size1,
    :observe,
    :content_format
  ]

  def decode(option_id, value) do
    __MODULE__.Decoder.to_tuple(option_id, value)
  end

  def encode({key, value}) do
    __MODULE__.Encoder.encode({key, value})
  end

  defguard is_unsigned(key) when key in @unsigned_options

  def unsigned?(key) when is_unsigned(key), do: true
  def unsigned?(_key), do: false

  defguard is_repeatable(key) when key in @repeatable_options

  def repeatable?(key) when is_repeatable(key), do: true
  def repeatable?(_key), do: false
end
