defmodule EliudsEggs do
  @doc """
  This is a decimal to binary converter, then getting a sum of 1s

  As seen here: https://www.wikihow.com/Convert-from-Decimal-to-Binary
  """

  def egg_count(0) do
    0
  end

  def egg_count(number) do
    number
    |> recurse("")
    |> String.split("", trim: true)
    |> Enum.map(fn
      "0" -> 0
      "1" -> 1
    end)
    |> Enum.sum()
  end

  # base case
  defp recurse(0, binary) do
    binary
  end

  # recursion
  defp recurse(target, binary) do
    divided = div(target, 2)
    remainder = rem(target, 2)

    recurse(divided, "#{remainder}" <> binary)
  end
end
