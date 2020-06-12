defmodule CoAP.Message.Encoder do
  @payload_marker 0xFF

  @doc """
  Encode a Message struct, with a multipart/block-wise transfer options, as a binary coap
  """
  @spec encode(CoAP.Message.t()) :: binary
  def encode(%CoAP.Message{multipart: %CoAP.Multipart{}} = message) do
    # Always check code_detail in case the message was made directly, not decoded
    blocks =
      CoAP.Multipart.as_blocks(CoAP.Message.Code.request?({message.code_class, message.code_detail}), message.multipart)

    %{message | options: Map.merge(message.options, blocks), multipart: nil}
    |> encode()
  end

  @doc """
  Encode a Message struct as binary coap

  Examples

      iex> message = %CoAP.Message{
      iex>   version: 1,
      iex>   type: :con,
      iex>   code: {0, 3},
      iex>   message_id: 12796,
      iex>   token: <<123, 92, 211, 222>>,
      iex>   options: %{
      iex>     uri_path: ["resource"],
      iex>     uri_query: ["who=world"]
      iex>   },
      iex>   payload: "payload",
      iex>   method: :put,
      iex>   request: true
      iex> }
      iex> CoAP.Message.encode(message)
      <<0x44, 0x03, 0x31, 0xfc, 0x7b, 0x5c, 0xd3, 0xde, 0xb8, 0x72, 0x65, 0x73, 0x6f, 0x75, 0x72, 0x63, 0x65, 0x49, 0x77, 0x68, 0x6f, 0x3d, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0xff, 0x70, 0x61, 0x79, 0x6c, 0x6f, 0x61, 0x64>>

  """
  @spec encode(CoAP.Message.t()) :: binary
  def encode(%CoAP.Message{
        version: version,
        type: type,
        code: {code_class, code_detail},
        message_id: message_id,
        token: token,
        payload: payload,
        options: options
      }) do
    token_length = byte_size(token)

    # ensure at least an empty binary
    payload = payload || <<>>

    <<
      version::unsigned-integer-size(2),
      CoAP.Message.Type.encode(type)::unsigned-integer-size(2),
      token_length::unsigned-integer-size(4),
      code_class::unsigned-integer-size(3),
      code_detail::unsigned-integer-size(5),
      message_id::unsigned-integer-size(16),
      token::binary,
      CoAP.Message.Options.encode(options)::binary,
      @payload_marker,
      payload::binary
    >>
  end
end
