defmodule GoogleCloudTracePlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defp call(conn, opts) do
    GoogleCloudTracePlug.call(conn, GoogleCloudTracePlug.init(opts))
  end

  test "generates new trace context if none exists" do
    conn = call(conn(:get, "/"), [])
    [res_trace_context] = get_resp_header(conn, "x-cloud-trace-context")

    assert meta_trace = Logger.metadata()[:"logging.googleapis.com/trace"]
    {_project_id, trace_id} = parse_trace(meta_trace)

    assert meta_span_id = Logger.metadata()[:"logging.googleapis.com/spanId"]

    assert res_trace_context =~ trace_id
    assert res_trace_context =~ meta_span_id
  end

  test "uses existing trace context" do
    trace_id = "4f535edc4efa0e8ac7394c58d0e2acf8"
    span_id = "6600be06d0b2b630"

    conn =
      conn(:get, "/")
      |> put_req_header("x-cloud-trace-context", "#{trace_id}/#{span_id};o=0")
      |> call([])

    [res_trace_context] = get_resp_header(conn, "x-cloud-trace-context")
    meta_trace = Logger.metadata()[:"logging.googleapis.com/trace"]
    meta_span_id = Logger.metadata()[:"logging.googleapis.com/spanId"]

    assert meta_trace =~ trace_id
    assert meta_span_id =~ span_id

    assert res_trace_context =~ trace_id
    assert res_trace_context =~ span_id
  end

  test "uses existing trace context without options" do
    trace_id = "4f535edc4efa0e8ac7394c58d0e2acf8"
    span_id = "6600be06d0b2b630"

    conn =
      conn(:get, "/")
      |> put_req_header("x-cloud-trace-context", "#{trace_id}/#{span_id}")
      |> call([])

    [res_trace_context] = get_resp_header(conn, "x-cloud-trace-context")
    meta_trace = Logger.metadata()[:"logging.googleapis.com/trace"]
    meta_span_id = Logger.metadata()[:"logging.googleapis.com/spanId"]

    assert meta_trace =~ trace_id
    assert meta_span_id =~ span_id

    assert res_trace_context =~ trace_id
    assert res_trace_context =~ span_id
  end

  test "uses project id passed in as option" do
    project_id = "fantag-c0979"

    call(conn(:get, "/"), project_id: project_id)

    meta_trace = Logger.metadata()[:"logging.googleapis.com/trace"]

    assert meta_trace =~ project_id
  end

  defp parse_trace(trace) do
    ["projects", project_id, "traces", trace_id] = String.split(trace, "/")
    {project_id, trace_id}
  end
end
