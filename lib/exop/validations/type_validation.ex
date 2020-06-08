defmodule Exop.TypeValidation do
  @known_types ~w(boolean integer float string tuple struct map list atom function keyword module uuid)a

  Enum.each(@known_types, fn type ->
    def type_supported?(unquote(type), _opts), do: :ok
  end)

  def type_supported?(nil, nil), do: :ok

  def type_supported?(nil, []), do: :ok

  def type_supported?(nil, opts) when is_list(opts) do
    if Keyword.has_key?(opts, :struct) do
      opts
      |> Keyword.get(:struct)
      |> check_struct_exists()
    else
      :ok
    end
  end

  def type_supported?(nil, _opts) do
    :ok
  end

  def type_supported?(unknown_type, _opts) do
    {:error, {:unknown_type, unknown_type}}
  end

  def known_types, do: @known_types

  def check_value(check_item, :boolean) when is_boolean(check_item), do: true

  def check_value(check_item, :integer) when is_integer(check_item), do: true

  def check_value(check_item, :float) when is_float(check_item), do: true

  def check_value(check_item, :string) when is_binary(check_item), do: true

  def check_value(check_item, :tuple) when is_tuple(check_item), do: true

  def check_value(check_item, :map) when is_map(check_item), do: true

  def check_value(check_item, :list) when is_list(check_item), do: true

  def check_value(check_item, :atom) when is_atom(check_item), do: true

  def check_value(check_item, :function) when is_function(check_item), do: true

  def check_value([] = _check_item, :keyword), do: true

  def check_value([{atom, _} | _] = _check_item, :keyword) when is_atom(atom), do: true

  def check_value(check_item, :module) when is_atom(check_item) do
    Code.ensure_loaded?(check_item)
  end

  def check_value(check_item, :uuid) when is_binary(check_item), do: validate_uuid(check_item)

  def check_value(_, _), do: false

  @spec validate_uuid(binary()) :: boolean()
  defp validate_uuid(
         <<a1, a2, a3, a4, a5, a6, a7, a8, ?-, b1, b2, b3, b4, ?-, c1, c2, c3, c4, ?-, d1, d2, d3,
           d4, ?-, e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11, e12>>
       ) do
    <<c(a1), c(a2), c(a3), c(a4), c(a5), c(a6), c(a7), c(a8), ?-, c(b1), c(b2), c(b3), c(b4), ?-,
      c(c1), c(c2), c(c3), c(c4), ?-, c(d1), c(d2), c(d3), c(d4), ?-, c(e1), c(e2), c(e3), c(e4),
      c(e5), c(e6), c(e7), c(e8), c(e9), c(e10), c(e11), c(e12)>>
  catch
    :error -> false
  else
    _ -> true
  end

  defp validate_uuid(_), do: false

  defp c(?0), do: ?0
  defp c(?1), do: ?1
  defp c(?2), do: ?2
  defp c(?3), do: ?3
  defp c(?4), do: ?4
  defp c(?5), do: ?5
  defp c(?6), do: ?6
  defp c(?7), do: ?7
  defp c(?8), do: ?8
  defp c(?9), do: ?9
  defp c(?A), do: ?a
  defp c(?B), do: ?b
  defp c(?C), do: ?c
  defp c(?D), do: ?d
  defp c(?E), do: ?e
  defp c(?F), do: ?f
  defp c(?a), do: ?a
  defp c(?b), do: ?b
  defp c(?c), do: ?c
  defp c(?d), do: ?d
  defp c(?e), do: ?e
  defp c(?f), do: ?f
  defp c(_), do: throw(:error)

  defp check_struct_exists(struct_name) when is_atom(struct_name) do
    with {:module, _} <- Code.ensure_compiled(struct_name),
         true <- function_exported?(struct_name, :__struct__, 0) do
      :ok
    else
      _ -> {:error, {:unknown_struct, struct_name}}
    end
  end

  defp check_struct_exists(%_{}), do: :ok
  defp check_struct_exists(unknown_struct), do: {:error, {:unknown_struct, unknown_struct}}
end
