defmodule CoAP.Message.Option.Encoder do
  import CoAP.Message.Option, only: [is_unsigned: 1, is_repeatable: 1]

  @options %{
    if_match: 1,
    uri_host: 3,
    etag: 4,
    if_none_match: 5,
    # draft-ietf-core-observe-16
    observe: 6,
    uri_port: 7,
    location_path: 8,
    uri_path: 11,
    content_format: 12,
    max_age: 14,
    uri_query: 15,
    accept: 17,
    location_query: 20,
    # draft-ietf-core-block-17
    block2: 23,
    block1: 27,
    proxy_uri: 35,
    proxy_scheme: 39,
    size1: 60
  }

  @content_formats %{
    "text/plain" => 0,
    "application/link-format" => 40,
    "application/xml" => 41,
    "application/octet-stream" => 42,
    "application/exi" => 47,
    "application/json" => 50,
    "application/cbor" => 60
  }

  def encode({key, values}) when is_repeatable(key) do
    # we must keep the order
    values
    # remove nil
    |> Enum.filter(fn v -> v end)
    |> Enum.map(&encode_option({key, &1}))
  end

  def encode({key, value}) do
    encode_option({key, value})
  end

  # Encode special cases
  defp encode_option({:block2, value}), do: {@options[:block2], CoAP.Block.encode(value)}
  defp encode_option({:block1, value}), do: {@options[:block1], CoAP.Block.encode(value)}
  defp encode_option({:if_none_match, true}), do: {@options[:if_none_match], <<>>}

  defp encode_option({:content_format, value}) when is_binary(value) do
    {:content_format, @content_formats[value]}
    |> encode_option
  end

  # Encode unsigned integer values
  defp encode_option({key, value}) when is_unsigned(key) do
    {@options[key], :binary.encode_unsigned(value)}
  end

  # Encode everything else
  # binary
  defp encode_option({key, value}) when is_atom(key), do: {@options[key], value}
  defp encode_option({key, value}) when is_integer(key), do: {key, value}
end
