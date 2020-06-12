defmodule CoAP.Message.Options do
  @doc """

  Examples

      iex> message = <<57, 108, 111, 99, 97, 108, 104, 111, 115, 116, 131, 97, 112, 105,
      iex>             0, 17, 0, 57, 119, 104, 111, 61, 119, 111, 114, 108, 100>>
      iex> CoAP.Message.Options.decode(message)
      {%{
        uri_path: ["api", ""],
        uri_query: ["who=world"],
        content_format: "text/plain",
        uri_host: "localhost"
      }, <<>>}
  """
  def decode(message) do
    __MODULE__.Decoder.options_and_payload(message)
  end

  @doc """

  Examples

      iex> options = %{
      iex>   uri_path: ["api", ""],
      iex>   uri_query: ["who=world"],
      iex>   content_format: "text/plain",
      iex>   uri_host: "localhost"
      iex> }
      iex> CoAP.Message.Options.encode(options)
      <<57, 108, 111, 99, 97, 108, 104, 111, 115, 116, 131, 97, 112, 105,
        0, 17, 0, 57, 119, 104, 111, 61, 119, 111, 114, 108, 100>>
  """
  def encode(options) do
    __MODULE__.Encoder.to_binary(options)
  end
end
