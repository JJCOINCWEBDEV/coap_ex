defmodule CoAP.Message.Option.Decoder do
  import CoAP.Message.Option, only: [is_unsigned: 1]

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

  @content_formats %{
    0 => "text/plain",
    40 => "application/link-format",
    41 => "application/xml",
    42 => "application/octet-stream",
    47 => "application/exi",
    50 => "application/json",
    60 => "application/cbor"
  }

  def to_tuple(option_id, value) do
    decode_option(option_id, value)
  end

  defp decode_option(option_id, value) when is_integer(option_id) do
    decode_option(@options[option_id], value)
  end

  defp decode_option(key, value) when is_atom(key), do: {key, decode_value(key, value)}

  defp decode_value(:if_none_match, <<>>), do: true
  defp decode_value(:block1, value), do: CoAP.Block.decode(value)
  defp decode_value(:block2, value), do: CoAP.Block.decode(value)

  defp decode_value(:content_format, value) do
    content_id = :binary.decode_unsigned(value)
    @content_formats[content_id] || content_id
  end

  defp decode_value(key, value) when is_unsigned(key), do: :binary.decode_unsigned(value)
  defp decode_value(_key, value), do: value
end
