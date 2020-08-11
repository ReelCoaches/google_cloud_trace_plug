defmodule GoogleCloudTracePlugTest do
  use ExUnit.Case
  doctest GoogleCloudTracePlug

  test "greets the world" do
    assert GoogleCloudTracePlug.hello() == :world
  end
end
