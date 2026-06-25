defmodule CLIX.SpecTest do
  use ExUnit.Case, async: true

  alias CLIX.Spec

  test "requirement of short and long" do
    assert_raise ArgumentError,
                 "opt :mode under the cmd path [:example] - expected :short or :long to be set",
                 fn ->
                   Spec.new({:example, %{opts: [mode: %{}]}})
                 end
  end

  test "the length of short" do
    assert_raise ArgumentError,
                 "opt :mode under the cmd path [:example] - expected :short to be an one-char string, got: \"mod\"",
                 fn ->
                   Spec.new({:example, %{opts: [mode: %{short: "mod"}]}})
                 end

    assert {_, _} = Spec.new({:example, %{opts: [mode: %{short: "m"}]}})
  end

  test "the length of long" do
    assert_raise ArgumentError,
                 "opt :mode under the cmd path [:example] - expected :long to be a multi-chars string, got: \"m\"",
                 fn ->
                   Spec.new({:example, %{opts: [mode: %{long: "m"}]}})
                 end

    assert {_, _} = Spec.new({:example, %{opts: [mode: %{long: "mode"}]}})
  end

  test ":count action requires :boolean type" do
    assert_raise ArgumentError,
                 "opt :verbose under the cmd path [:example] - expected :type to be :boolean when :action is :count, got: :string",
                 fn ->
                   Spec.new({:example, %{opts: [verbose: %{short: "v", action: :count}]}})
                 end

    assert_raise ArgumentError,
                 "opt :verbose under the cmd path [:example] - expected :type to be :boolean when :action is :count, got: :integer",
                 fn ->
                   Spec.new({:example, %{opts: [verbose: %{short: "v", type: :integer, action: :count}]}})
                 end

    assert {_, _} = Spec.new({:example, %{opts: [verbose: %{short: "v", type: :boolean, action: :count}]}})
  end
end
