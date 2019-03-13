defmodule CoAP.Multipart do
  # Normalize block1/block2 depending on if this is a request or response

  # In a request:
  # block1 => is the transfer description (number, is there more, size)
  # block2 => "control", or what size the response should be chunked into, client preference, which part of # the response that the server should send back used in subsequent requests
  #
  # In a response:
  # block2 => is the transfer description (number, is there more, size)
  # block1 => "control", or what size subsequent requests should be made at; server preference

  alias CoAP.Block

  # TODO: redefine as description/control based on request/response
  defstruct multipart: false, description: %Block{}, control: %Block{}, more: false, number: 0

  def build(_request, nil, nil), do: %__MODULE__{}

  # Request variation
  def build(true, block1, block2) do
    description = Block.build(block1)
    control = Block.build(block2)

    %__MODULE__{
      multipart: true,
      description: description,
      control: control,
      more: description.more,
      number: description.number
    }
  end

  # Response variation
  def build(false, block1, block2) do
    control = Block.build(block1)
    description = Block.build(block2)

    %__MODULE__{
      multipart: true,
      description: description,
      control: control,
      more: description.more,
      number: description.number
    }
  end
end
