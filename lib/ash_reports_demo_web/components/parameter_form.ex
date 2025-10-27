defmodule AshReportsDemoWeb.Components.ParameterForm do
  @moduledoc """
  Dynamic form component that generates input fields from report parameter definitions.

  This component provides:
  - Auto-generated forms from parameter definitions
  - Type-specific input widgets (string, integer, date, atom, boolean, decimal)
  - Validation with inline error messages
  - Default value support
  - Required/optional field handling

  ## Usage

      <.parameter_form
        parameters={@report.parameters}
        values={@parameter_values}
        errors={@parameter_errors}
      />

  ## With change tracking

      <.parameter_form
        parameters={@report.parameters}
        values={@parameter_values}
        errors={@parameter_errors}
        on_change="param_changed"
      />

  """

  use Phoenix.Component

  attr :parameters, :list,
    required: true,
    doc: "List of parameter definitions from report"

  attr :values, :map,
    default: %{},
    doc: "Map of current parameter values"

  attr :errors, :map,
    default: %{},
    doc: "Map of parameter names to error messages"

  attr :on_change, :string,
    default: nil,
    doc: "Event name to trigger on parameter change"

  attr :disabled, :boolean,
    default: false,
    doc: "Disable all form inputs"

  @doc """
  Render a dynamic parameter form based on report parameter definitions.
  """
  def parameter_form(assigns) do
    ~H"""
    <div class="parameter-form space-y-4">
      <%= if Enum.empty?(@parameters) do %>
        <div class="text-sm text-gray-500 italic">
          This report has no parameters.
        </div>
      <% else %>
        <div :for={param <- @parameters} class="parameter-field">
          <%= render_parameter_field(
            Map.merge(assigns, %{
              param: param,
              value: Map.get(@values, param.name, get_default_value(param)),
              error: Map.get(@errors, param.name)
            })
          ) %>
        </div>
      <% end %>
    </div>
    """
  end

  # Render a single parameter field based on its type
  defp render_parameter_field(%{param: param} = assigns) do
    assigns = assign(assigns, :field_id, "param_#{param.name}")
    assigns = assign(assigns, :is_required, !Map.has_key?(param, :default))

    ~H"""
    <div class="space-y-1">
      <label for={@field_id} class="block text-sm font-medium text-gray-700">
        <%= format_label(@ param.name) %>
        <%= if @is_required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= render_input_by_type(@param, @value, @field_id, @on_change, @disabled) %>

      <%= if Map.get(@param, :description) do %>
        <p class="text-xs text-gray-500">
          <%= Map.get(@param, :description) %>
        </p>
      <% end %>

      <%= if @error do %>
        <p class="text-sm text-red-600">
          <%= @error %>
        </p>
      <% end %>

      <%= if !@is_required && Map.has_key?(@param, :default) do %>
        <p class="text-xs text-gray-400">
          Default: <%= format_default_value(@param.default) %>
        </p>
      <% end %>
    </div>
    """
  end

  # Render input widget based on parameter type
  defp render_input_by_type(param, value, field_id, on_change, disabled) do
    type = param.type
    constraints = Map.get(param, :constraints, %{})

    cond do
      # Boolean checkbox
      type == :boolean ->
        render_checkbox(param, value, field_id, on_change, disabled)

      # Atom with one_of constraint -> dropdown
      type == :atom && constraints[:one_of] ->
        render_select(param, value, field_id, on_change, disabled, constraints[:one_of])

      # String type
      type == :string ->
        render_text_input(param, value, field_id, on_change, disabled)

      # Integer type
      type == :integer ->
        render_number_input(param, value, field_id, on_change, disabled, "1")

      # Decimal type
      type == :decimal ->
        render_number_input(param, value, field_id, on_change, disabled, "0.01")

      # Date type
      type == :date ->
        render_date_input(param, value, field_id, on_change, disabled)

      # Fallback to text input
      true ->
        render_text_input(param, value, field_id, on_change, disabled)
    end
  end

  defp render_text_input(param, value, field_id, on_change, disabled) do
    assigns = %{
      field_id: field_id,
      param: param,
      value: value || "",
      on_change: on_change,
      disabled: disabled
    }

    ~H"""
    <input
      type="text"
      id={@field_id}
      name={@param.name}
      value={@value}
      phx-change={@on_change}
      disabled={@disabled}
      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
    />
    """
  end

  defp render_number_input(param, value, field_id, on_change, disabled, step) do
    assigns = %{
      field_id: field_id,
      param: param,
      value: value || "",
      on_change: on_change,
      disabled: disabled,
      step: step
    }

    ~H"""
    <input
      type="number"
      id={@field_id}
      name={@param.name}
      value={@value}
      step={@step}
      phx-change={@on_change}
      disabled={@disabled}
      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
    />
    """
  end

  defp render_date_input(param, value, field_id, on_change, disabled) do
    assigns = %{
      field_id: field_id,
      param: param,
      value: format_date_value(value),
      on_change: on_change,
      disabled: disabled
    }

    ~H"""
    <input
      type="date"
      id={@field_id}
      name={@param.name}
      value={@value}
      phx-change={@on_change}
      disabled={@disabled}
      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
    />
    """
  end

  defp render_checkbox(param, value, field_id, on_change, disabled) do
    assigns = %{
      field_id: field_id,
      param: param,
      checked: value == true || value == "true",
      on_change: on_change,
      disabled: disabled
    }

    ~H"""
    <div class="flex items-center">
      <input
        type="checkbox"
        id={@field_id}
        name={@param.name}
        checked={@checked}
        phx-click={@on_change}
        disabled={@disabled}
        class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
      />
      <label for={@field_id} class="ml-2 text-sm text-gray-600">
        Enable
      </label>
    </div>
    """
  end

  defp render_select(param, value, field_id, on_change, disabled, options) do
    assigns = %{
      field_id: field_id,
      param: param,
      value: value,
      options: options,
      on_change: on_change,
      disabled: disabled
    }

    ~H"""
    <select
      id={@field_id}
      name={@param.name}
      phx-change={@on_change}
      disabled={@disabled}
      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
    >
      <option value="">-- Select --</option>
      <%= for option <- @options do %>
        <option value={option} selected={to_string(@value) == to_string(option)}>
          <%= format_option_label(option) %>
        </option>
      <% end %>
    </select>
    """
  end

  # Helper functions

  defp get_default_value(param) do
    Map.get(param, :default)
  end

  defp format_label(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_label(name), do: to_string(name)

  defp format_option_label(option) when is_atom(option) do
    option
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp format_option_label(option), do: to_string(option)

  defp format_default_value(nil), do: "None"
  defp format_default_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_default_value(value) when is_binary(value), do: value
  defp format_default_value(value), do: inspect(value)

  defp format_date_value(nil), do: ""
  defp format_date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp format_date_value(value) when is_binary(value), do: value
  defp format_date_value(_), do: ""

  @doc """
  Validate a parameter value against its definition.

  Returns `:ok` if valid, or `{:error, message}` if invalid.
  """
  def validate_parameter(param, value) do
    with :ok <- validate_required(param, value),
         :ok <- validate_type(param.type, value),
         :ok <- validate_constraints(param, value) do
      :ok
    end
  end

  defp validate_required(param, value) do
    has_default = Map.has_key?(param, :default)
    is_blank = value == nil || value == ""

    if !has_default && is_blank do
      {:error, "#{format_label(param.name)} is required"}
    else
      :ok
    end
  end

  defp validate_type(_type, nil), do: :ok
  defp validate_type(_type, ""), do: :ok

  defp validate_type(:string, value) when is_binary(value), do: :ok

  defp validate_type(:integer, value) when is_integer(value), do: :ok

  defp validate_type(:integer, value) when is_binary(value) do
    case Integer.parse(value) do
      {_, ""} -> :ok
      _ -> {:error, "Must be a valid integer"}
    end
  end

  defp validate_type(:decimal, value) when is_number(value), do: :ok

  defp validate_type(:decimal, value) when is_binary(value) do
    case Decimal.parse(value) do
      {%Decimal{}, _} -> :ok
      _ -> {:error, "Must be a valid decimal number"}
    end
  rescue
    _ -> {:error, "Must be a valid decimal number"}
  end

  defp validate_type(:boolean, value) when is_boolean(value), do: :ok
  defp validate_type(:boolean, value) when value in ["true", "false"], do: :ok

  defp validate_type(:atom, value) when is_atom(value), do: :ok

  defp validate_type(:atom, value) when is_binary(value) do
    try do
      String.to_existing_atom(value)
      :ok
    rescue
      ArgumentError -> {:error, "Must be a valid atom"}
    end
  end

  defp validate_type(:date, %Date{}), do: :ok

  defp validate_type(:date, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, _} -> :ok
      _ -> {:error, "Must be a valid date (YYYY-MM-DD)"}
    end
  end

  defp validate_type(type, _value) do
    {:error, "Unsupported type: #{type}"}
  end

  defp validate_constraints(param, value) do
    constraints = Map.get(param, :constraints, %{})

    cond do
      # Check one_of constraint
      constraints[:one_of] && value not in [nil, ""] ->
        validate_one_of(constraints[:one_of], value)

      # Check min/max for numbers
      (param.type == :integer || param.type == :decimal) && value not in [nil, ""] ->
        validate_number_range(constraints, value)

      # Check string length
      param.type == :string && value not in [nil, ""] ->
        validate_string_length(constraints, value)

      true ->
        :ok
    end
  end

  defp validate_one_of(options, value) do
    value_str = to_string(value)
    options_str = Enum.map(options, &to_string/1)

    if value_str in options_str do
      :ok
    else
      {:error, "Must be one of: #{Enum.join(options_str, ", ")}"}
    end
  end

  defp validate_number_range(constraints, value) do
    num_value = parse_number(value)

    cond do
      constraints[:min] && num_value < constraints[:min] ->
        {:error, "Must be at least #{constraints[:min]}"}

      constraints[:max] && num_value > constraints[:max] ->
        {:error, "Must be at most #{constraints[:max]}"}

      true ->
        :ok
    end
  end

  defp validate_string_length(constraints, value) when is_binary(value) do
    length = String.length(value)

    cond do
      constraints[:min_length] && length < constraints[:min_length] ->
        {:error, "Must be at least #{constraints[:min_length]} characters"}

      constraints[:max_length] && length > constraints[:max_length] ->
        {:error, "Must be at most #{constraints[:max_length]} characters"}

      true ->
        :ok
    end
  end

  defp validate_string_length(_constraints, _value), do: :ok

  defp parse_number(value) when is_number(value), do: value

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, _} -> num
      _ -> 0
    end
  end

  @doc """
  Validate all parameters in a form.

  Returns `{:ok, validated_params}` or `{:error, error_map}`.
  """
  def validate_all_parameters(parameters, values) do
    errors =
      parameters
      |> Enum.map(fn param ->
        value = Map.get(values, param.name)
        {param.name, validate_parameter(param, value)}
      end)
      |> Enum.reject(fn {_name, result} -> result == :ok end)
      |> Enum.into(%{}, fn {name, {:error, message}} -> {name, message} end)

    if Enum.empty?(errors) do
      {:ok, values}
    else
      {:error, errors}
    end
  end
end
