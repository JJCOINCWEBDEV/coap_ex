defmodule CoAP.Message.Option.Encoder do
  import CoAP.Message.Option, only: [is_unsigned: 1, is_repeatable: 1]

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
  defp encode_option({:block2, value}), do: {CoAP.Message.Option.key_to_num(:block2), CoAP.Block.encode(value)}
  defp encode_option({:block1, value}), do: {CoAP.Message.Option.key_to_num(:block1), CoAP.Block.encode(value)}
  defp encode_option({:if_none_match, true}), do: {CoAP.Message.Option.key_to_num(:if_none_match), <<>>}

  defp encode_option({:content_format, value}) when is_binary(value) do
    {:content_format, @content_formats[value]}
    |> encode_option
  end

  # Encode unsigned integer values
  defp encode_option({key, value}) when is_unsigned(key) do
    {CoAP.Message.Option.key_to_num(key), :binary.encode_unsigned(value)}
  end

  # Encode everything else
  # binary
  defp encode_option({key, value}) when is_atom(key), do: {CoAP.Message.Option.key_to_num(key), value}
  defp encode_option({key, value}) when is_integer(key), do: {key, value}
end
