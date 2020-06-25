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
  defstruct multipart: false,
            description: nil,
            control: nil,
            more: false,
            number: 0,
            size: 0,
            requested_size: 0,
            requested_number: 0

  @type t :: %__MODULE__{
          multipart: boolean,
          description: CoAP.Block.t(),
          control: CoAP.Block.t(),
          more: boolean,
          number: integer,
          size: integer,
          requested_size: integer,
          requested_number: integer
        }

  @doc """
  Does this message contain a block1 or block2 option

  Examples

      iex> CoAP.Multipart.build(%CoAP.Message{request_response: {:request, :put}, options: %{block1: {1, true, 1024}, block2: {0, false, 512}}})
      %CoAP.Multipart{
        control: %CoAP.Block{number: 0, more: false, size: 512},
        description: %CoAP.Block{number: 1, more: true, size: 1024},
        multipart: true,
        more: true,
        number: 1,
        size: 1024,
        requested_size: 512
      }

      iex> CoAP.Multipart.build(%CoAP.Message{request_response: {:request, :put}, options: %{}})
      %CoAP.Multipart{multipart: false}

  """
  @spec build(CoAP.Message.t()) :: t()
  def build(%CoAP.Message{request_response: request_response, options: options})
      when is_map_key(options, :block1) or is_map_key(options, :block2) do
    case request_response do
      {:request, _} -> do_build(Block.build(options[:block1]), Block.build(options[:block2]))
      {:response, _} -> do_build(Block.build(options[:block2]), Block.build(options[:block1]))
    end
  end

  def build(%CoAP.Message{}) do
    %__MODULE__{}
  end

  defp do_build(%Block{} = description, %Block{} = control) do
    %__MODULE__{
      multipart: true,
      description: description,
      control: control,
      more: description.more,
      number: description.number,
      size: description.size,
      requested_number: control.number,
      requested_size: control.size
    }
  end

  defp do_build(nil, %Block{} = control) do
    %__MODULE__{
      multipart: true,
      description: nil,
      control: control,
      requested_number: control.number,
      requested_size: control.size
    }
  end

  defp do_build(%Block{} = description, nil) do
    case {description.more, description.number} do
      {false, 0} ->
        # Return nil if this is the first block, and there are no more
        # as this is not a multipart payload
        nil

      _ ->
        %__MODULE__{
          multipart: true,
          description: description,
          control: nil,
          more: description.more,
          number: description.number,
          size: description.size
        }
    end
  end

  defp do_build(nil, nil) do
    %__MODULE__{}
  end

  @spec as_blocks(CoAP.Message.request_response(), CoAP.Multipart.t()) :: %{
          block1: CoAP.Block.t(),
          block2: CoAP.Block.t()
        }
  def as_blocks({:request, _}, multipart) do
    %{
      block1: multipart.description |> Block.to_tuple(),
      block2: multipart.control |> Block.to_tuple()
    }
    |> reject_nil_values()
  end

  # TODO: if we get nil here, that's wrong
  def as_blocks({:response, _}, multipart) do
    %{
      block1: multipart.control |> Block.to_tuple(),
      block2: multipart.description |> Block.to_tuple()
    }
    |> reject_nil_values()
  end

  defp reject_nil_values(blocks) do
    blocks
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
