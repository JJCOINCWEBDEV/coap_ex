defmodule CoAP.Message.Decoder do
  @doc """
  Decode binary coap message into a struct

  Examples:

      iex> message = <<0x44, 0x03, 0x31, 0xfc, 0x7b, 0x5c, 0xd3, 0xde, 0xb8, 0x72, 0x65, 0x73, 0x6f, 0x75, 0x72, 0x63, 0x65, 0x49, 0x77, 0x68, 0x6f, 0x3d, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0xff, 0x70, 0x61, 0x79, 0x6c, 0x6f, 0x61, 0x64>>
      iex> CoAP.Message.decode(message)
      %CoAP.Message{
        version: 1,
        type: :con,
        request: true,
        code_class: 0,
        code_detail: 3,
        message_id: 12796,
        token: <<123, 92, 211, 222>>,
        options: %{
          uri_path: ["resource"],
          uri_query: ["who=world"]
        },
        payload: "payload",
        multipart: %CoAP.Multipart{control: nil, description: nil, more: false, multipart: false, number: 0},
        method: :put,
        raw_size: 35
      }

      iex> message = <<68, 1, 0, 1, 163, 249, 107, 129, 57, 108, 111, 99, 97, 108, 104, 111, 115,
      iex>              116, 131, 97, 112, 105, 0, 17, 0, 57, 119, 104, 111, 61, 119, 111, 114, 108,
      iex>              100, 255, 100, 97, 116, 97>>
      iex> CoAP.Message.decode(message)
      %CoAP.Message{
        version: 1,
        type: :con,
        request: true,
        code_class: 0,
        code_detail: 1,
        message_id: 1,
        token: <<163, 249, 107, 129>>,
        options: %{
           uri_path: ["api", ""],
           uri_query: ["who=world"],
           content_format: "text/plain",
           uri_host: "localhost"
        },
        payload: "data",
        multipart: %CoAP.Multipart{control: nil, description: nil, more: false, multipart: false, number: 0},
        method: :get,
        raw_size: 40
      }

      iex> data = <<0x40, 0x01, 0x21, 0x27, 0xB3, 0x61, 0x70, 0x69, 0xC1, 0x15, 0xFF, 0x32, 0x24, 0x0A, 0x0C, 0x0A, 0x0A, 0x33, 0x30, 0x30, 0x30, 0x30, 0x30, 0x30, 0x31, 0x36, 0x34, 0x12, 0x14, 0x30, 0x31, 0x30, 0x39, 0x32, 0x34, 0x35, 0x30, 0x46, 0x30, 0x41, 0x46, 0x6D, 0x63, 0x75, 0x2D, 0x65, 0x76, 0x74, 0x32>>
      iex> message = CoAP.Message.decode(data)
      iex> message.multipart
      %CoAP.Multipart{
        description: nil,
        control: %CoAP.Block{more: false, number: 1, size: 512},
        multipart: true,
        requested_number: 1,
        requested_size: 512
      }
  """
  @spec decode(binary) :: CoAP.Message.t()
  def decode(raw_data) do
    <<
      version::unsigned-integer-size(2),
      type::unsigned-integer-size(2),
      token_length::unsigned-integer-size(4),
      code_class::unsigned-integer-size(3),
      code_detail::unsigned-integer-size(5),
      message_id::unsigned-integer-size(16),
      token::binary-size(token_length),
      options_payload::binary
    >> = raw_data

    {options, payload} = CoAP.Message.Options.decode(options_payload)
    code = {code_class, code_detail}

    request = CoAP.Message.Code.request?(code)

    %CoAP.Message{
      version: version,
      type: CoAP.Message.Type.decode(type),
      request: request,
      method: CoAP.Message.Code.decode_request(code),
      status: CoAP.Message.Code.decode_response(code),
      code_class: code_class,
      code_detail: code_detail,
      message_id: message_id,
      token: token,
      options: options,
      multipart: multipart(request, options),
      payload: payload,
      raw_size: byte_size(raw_data)
    }
  end

  @doc """
  Does this message contain a block1 or block2 option

  Examples

      iex> CoAP.Message.Decoder.multipart(true, %{block1: {1, true, 1024}, block2: {0, false, 512}})
      %CoAP.Multipart{
        control: %CoAP.Block{number: 0, more: false, size: 512},
        description: %CoAP.Block{number: 1, more: true, size: 1024},
        multipart: true,
        more: true,
        number: 1,
        size: 1024,
        requested_size: 512
      }

      iex> CoAP.Message.Decoder.multipart(true, %{})
      %CoAP.Multipart{multipart: false}

  """
  # TODO: test if either block1 or block2 is nil
  @spec multipart(boolean, %{block1: CoAP.Block.tuple_t(), block2: CoAP.Block.tuple_t()}) ::
          CoAP.Multipart.t()
  def multipart(request, options) do
    CoAP.Multipart.build(request, options[:block1], options[:block2])
  end
end
