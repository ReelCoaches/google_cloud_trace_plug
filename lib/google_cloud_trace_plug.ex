defmodule GoogleCloudTracePlug do
  @moduledoc """
  A plug for generating a unique trace context for each request.

  The generated trace id will be a 32-character hexadecimal encoding of an
  16-byte array, such as `4bf92f3577b34da6a3ce929d0e0e4736`.

  The generated trace context will be  a 16-character hexadecimal encoding of an
  8-byte array, such as `00f067aa0ba902b7`.

  The trace option is either 0 or 1 depending on whether this reuqest should be
  traced or not.

  If a trace context already exists as the "X-Cloud-Trace-Context" HTTP request header,
  then that value will be used.
  """

  require Logger
  alias Plug.Conn
  @behaviour Plug

  @impl Plug
  @spec init(keyword) :: keyword
  def init(opts), do: opts

  @impl Plug
  @spec call(Plug.Conn.t(), keyword) :: Plug.Conn.t()
  def call(conn, opts) do
    trace_context_header = Keyword.get(opts, :trace_context_header, "x-cloud-trace-context")
    project_id = Keyword.get(opts, :project_id, "my-project")

    conn
    |> get_trace_context(trace_context_header)
    |> set_trace_context(trace_context_header, project_id)
  end

  defp get_trace_context(conn, header) do
    case Conn.get_req_header(conn, header) do
      [] -> {conn, {generate_trace_id(), generate_span_id(), should_trace?()}}
      [val | _] -> {conn, parse_trace_header(val)}
    end
  end

  defp set_trace_context({conn, {trace_id, span_id, should_trace?}}, header, project_id) do
    # Log Entry trace format: projects/my-projectid/traces/06796866738c859f2f19b7cfb3214824
    trace = "projects/#{project_id}/traces/#{trace_id}"

    # Special Fields: https://cloud.google.com/logging/docs/agent/configuration
    Logger.metadata("logging.googleapis.com/trace": trace)
    Logger.metadata("logging.googleapis.com/spanId": span_id)
    Logger.metadata("logging.googleapis.com/trace_sampled": parse_boolean(should_trace?))

    # Cloud Trace context header format: TRACE_ID/SPAN_ID;o=TRACE_TRUE
    Conn.put_resp_header(conn, header, "#{trace_id}/#{span_id};o=#{should_trace?}")
  end

  defp generate_trace_id do
    generate_hex_bytes(16)
  end

  defp generate_span_id do
    generate_hex_bytes(8)
  end

  defp generate_hex_bytes(num_bytes) do
    num_bytes
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
    |> Integer.to_string(16)
    |> String.downcase()
  end

  defp parse_trace_header(header) do
    # Cloud Trace context header format: TRACE_ID/SPAN_ID;o=TRACE_TRUE
    # Where:
    #
    # TRACE_ID is a 32-character hexadecimal value representing a 128-bit number.
    # SPAN_ID is the decimal representation of the (unsigned) span ID.
    # TRACE_TRUE must be 1 to trace this request. Specify 0 to not trace the request.
    [trace_id, rest] = String.split(header, "/")

    if String.contains?(rest, ";") do
      [span_id, options] = String.split(rest, ";")
      [_, should_trace?] = String.split(options, "=")

      {trace_id, span_id, should_trace?}
    else
      {trace_id, rest, "0"}
    end
  end

  defp should_trace?, do: "0"

  defp parse_boolean("1"), do: true
  defp parse_boolean("0"), do: false
end
