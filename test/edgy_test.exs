defmodule EdgyTest do
  use ExUnit.Case
  doctest Edgy

  test "greets the world" do
    assert Edgy.hello() == :world
  end
end
