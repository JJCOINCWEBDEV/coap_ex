defmodule CoAP.Message.Option do
  @options %{
    1 => :if_match,
    3 => :uri_host,
    4 => :etag,
    5 => :if_none_match,
    # draft-ietf-core-observe-16
    6 => :observe,
    7 => :uri_port,
    8 => :location_path,
    11 => :uri_path,
    12 => :content_format,
    14 => :max_age,
    15 => :uri_query,
    17 => :accept,
    20 => :location_query,
    # draft-ietf-core-block-17
    23 => :block2,
    27 => :block1,
    35 => :proxy_uri,
    39 => :proxy_scheme,
    60 => :size1
  }
  @options_map Enum.into(@options, %{}, fn {k, v} -> {v, k} end)

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

  def num_to_key(num) when is_integer(num), do: @options[num]
  def key_to_num(key) when is_atom(key), do: @options_map[key]

  @spec decode(CoAP.Message.Decoder.State.t()) :: CoAP.Message.Decoder.State.t()
  def decode(%CoAP.Message.Decoder.State{} = state) do
    __MODULE__.Decoder.decode(state)
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
