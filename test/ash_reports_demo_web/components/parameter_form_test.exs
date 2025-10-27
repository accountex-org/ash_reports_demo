defmodule AshReportsDemoWeb.Components.ParameterFormTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias AshReportsDemoWeb.Components.ParameterForm

  describe "parameter_form/1" do
    test "renders empty state when no parameters" do
      assigns = %{
        parameters: [],
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
          on_change={@on_change}
          disabled={@disabled}
        />
        """)

      assert html =~ "This report has no parameters"
    end

    test "renders string parameter with text input" do
      params = [
        %{name: :customer_name, type: :string, description: "Customer name"}
      ]

      assigns = %{
        parameters: params,
        values: %{customer_name: "John Doe"},
        errors: %{},
        on_change: "param_changed",
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
          on_change={@on_change}
          disabled={@disabled}
        />
        """)

      assert html =~ "Customer Name"
      assert html =~ "Customer name"
      assert html =~ "John Doe"
      assert html =~ ~s(type="text")
    end

    test "renders integer parameter with number input" do
      params = [
        %{name: :max_results, type: :integer, default: 100}
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Max Results"
      assert html =~ ~s(type="number")
      assert html =~ ~s(step="1")
      assert html =~ "Default: 100"
    end

    test "renders decimal parameter with decimal input" do
      params = [
        %{name: :min_amount, type: :decimal}
      ]

      assigns = %{
        parameters: params,
        values: %{min_amount: "99.99"},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Min Amount"
      assert html =~ ~s(type="number")
      assert html =~ ~s(step="0.01")
      assert html =~ "99.99"
    end

    test "renders boolean parameter with checkbox" do
      params = [
        %{name: :include_inactive, type: :boolean, default: false}
      ]

      assigns = %{
        parameters: params,
        values: %{include_inactive: true},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Include Inactive"
      assert html =~ ~s(type="checkbox")
      assert html =~ "checked"
    end

    test "renders date parameter with date input" do
      params = [
        %{name: :start_date, type: :date}
      ]

      assigns = %{
        parameters: params,
        values: %{start_date: "2025-01-01"},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Start Date"
      assert html =~ ~s(type="date")
      assert html =~ "2025-01-01"
    end

    test "renders atom parameter with one_of constraint as dropdown" do
      params = [
        %{
          name: :status,
          type: :atom,
          constraints: %{one_of: [:active, :inactive, :pending]}
        }
      ]

      assigns = %{
        parameters: params,
        values: %{status: :active},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Status"
      assert html =~ "<select"
      assert html =~ "Active"
      assert html =~ "Inactive"
      assert html =~ "Pending"
      assert html =~ "selected"
    end

    test "renders required indicator for parameters without defaults" do
      params = [
        %{name: :required_field, type: :string}
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Required Field"
      assert html =~ ~s(<span class="text-red-500">*</span>)
    end

    test "displays validation errors" do
      params = [
        %{name: :email, type: :string}
      ]

      assigns = %{
        parameters: params,
        values: %{email: "invalid"},
        errors: %{email: "Must be a valid email address"},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Must be a valid email address"
      assert html =~ ~s(class="text-sm text-red-600")
    end

    test "disables all inputs when disabled is true" do
      params = [
        %{name: :field1, type: :string},
        %{name: :field2, type: :boolean}
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: true
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
          disabled={@disabled}
        />
        """)

      assert html =~ "disabled"
      assert html =~ "disabled:bg-gray-100"
    end

    test "renders multiple parameters" do
      params = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer},
        %{name: :active, type: :boolean}
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Name"
      assert html =~ "Age"
      assert html =~ "Active"
    end
  end

  describe "validate_parameter/2" do
    test "validates required string parameter" do
      param = %{name: :email, type: :string}

      assert {:error, "Email is required"} = ParameterForm.validate_parameter(param, nil)
      assert {:error, "Email is required"} = ParameterForm.validate_parameter(param, "")
      assert :ok = ParameterForm.validate_parameter(param, "test@example.com")
    end

    test "validates optional parameter with default" do
      param = %{name: :limit, type: :integer, default: 10}

      assert :ok = ParameterForm.validate_parameter(param, nil)
      assert :ok = ParameterForm.validate_parameter(param, "")
      assert :ok = ParameterForm.validate_parameter(param, 20)
    end

    test "validates integer type" do
      param = %{name: :count, type: :integer}

      assert :ok = ParameterForm.validate_parameter(param, 42)
      assert :ok = ParameterForm.validate_parameter(param, "42")
      assert {:error, "Must be a valid integer"} = ParameterForm.validate_parameter(param, "abc")

      assert {:error, "Must be a valid integer"} =
               ParameterForm.validate_parameter(param, "12.34")
    end

    test "validates decimal type" do
      param = %{name: :amount, type: :decimal}

      assert :ok = ParameterForm.validate_parameter(param, 99.99)
      assert :ok = ParameterForm.validate_parameter(param, "99.99")

      assert {:error, "Must be a valid decimal number"} =
               ParameterForm.validate_parameter(param, "abc")
    end

    test "validates boolean type" do
      param = %{name: :enabled, type: :boolean}

      assert :ok = ParameterForm.validate_parameter(param, true)
      assert :ok = ParameterForm.validate_parameter(param, false)
      assert :ok = ParameterForm.validate_parameter(param, "true")
      assert :ok = ParameterForm.validate_parameter(param, "false")
    end

    test "validates date type" do
      param = %{name: :start_date, type: :date}

      assert :ok = ParameterForm.validate_parameter(param, ~D[2025-01-01])
      assert :ok = ParameterForm.validate_parameter(param, "2025-01-01")

      assert {:error, "Must be a valid date (YYYY-MM-DD)"} =
               ParameterForm.validate_parameter(param, "invalid")

      assert {:error, "Must be a valid date (YYYY-MM-DD)"} =
               ParameterForm.validate_parameter(param, "2025-13-01")
    end

    test "validates one_of constraint" do
      param = %{
        name: :status,
        type: :atom,
        constraints: %{one_of: [:active, :inactive]}
      }

      assert :ok = ParameterForm.validate_parameter(param, :active)
      assert :ok = ParameterForm.validate_parameter(param, :inactive)
      assert {:error, message} = ParameterForm.validate_parameter(param, :unknown)
      assert message =~ "Must be one of"
      assert message =~ "active"
      assert message =~ "inactive"
    end

    test "validates min/max constraints for integers" do
      param = %{
        name: :age,
        type: :integer,
        constraints: %{min: 0, max: 150}
      }

      assert :ok = ParameterForm.validate_parameter(param, 25)
      assert :ok = ParameterForm.validate_parameter(param, 0)
      assert :ok = ParameterForm.validate_parameter(param, 150)
      assert {:error, "Must be at least 0"} = ParameterForm.validate_parameter(param, -1)
      assert {:error, "Must be at most 150"} = ParameterForm.validate_parameter(param, 151)
    end

    test "validates string length constraints" do
      param = %{
        name: :username,
        type: :string,
        constraints: %{min_length: 3, max_length: 20}
      }

      assert :ok = ParameterForm.validate_parameter(param, "john")
      assert :ok = ParameterForm.validate_parameter(param, "abc")

      assert {:error, "Must be at least 3 characters"} =
               ParameterForm.validate_parameter(param, "ab")

      assert {:error, "Must be at most 20 characters"} =
               ParameterForm.validate_parameter(param, String.duplicate("x", 21))
    end
  end

  describe "validate_all_parameters/2" do
    test "validates all parameters successfully" do
      params = [
        %{name: :name, type: :string},
        %{name: :age, type: :integer},
        %{name: :active, type: :boolean, default: true}
      ]

      values = %{
        name: "John Doe",
        age: 30
      }

      assert {:ok, ^values} = ParameterForm.validate_all_parameters(params, values)
    end

    test "returns all validation errors" do
      params = [
        %{name: :email, type: :string},
        %{name: :age, type: :integer},
        %{name: :amount, type: :decimal}
      ]

      values = %{
        email: "",
        age: "invalid",
        amount: "not a number"
      }

      assert {:error, errors} = ParameterForm.validate_all_parameters(params, values)
      assert Map.has_key?(errors, :email)
      assert Map.has_key?(errors, :age)
      assert Map.has_key?(errors, :amount)
      assert errors.email =~ "required"
      assert errors.age =~ "integer"
      assert errors.amount =~ "decimal"
    end

    test "validates only provided values" do
      params = [
        %{name: :optional, type: :string, default: "default"},
        %{name: :required, type: :string}
      ]

      values = %{
        required: "provided"
      }

      assert {:ok, ^values} = ParameterForm.validate_all_parameters(params, values)
    end

    test "returns empty error map when all validations pass" do
      params = [
        %{name: :name, type: :string}
      ]

      values = %{
        name: "Valid Name"
      }

      assert {:ok, ^values} = ParameterForm.validate_all_parameters(params, values)
    end
  end

  describe "helper functions" do
    test "formats parameter labels correctly" do
      # This is tested indirectly through rendering
      params = [
        %{name: :first_name, type: :string},
        %{name: :email_address, type: :string}
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "First Name"
      assert html =~ "Email Address"
    end

    test "formats option labels correctly" do
      params = [
        %{
          name: :priority,
          type: :atom,
          constraints: %{one_of: [:low, :medium, :high]}
        }
      ]

      assigns = %{
        parameters: params,
        values: %{},
        errors: %{},
        on_change: nil,
        disabled: false
      }

      html =
        rendered_to_string(~H"""
        <ParameterForm.parameter_form
          parameters={@parameters}
          values={@values}
          errors={@errors}
        />
        """)

      assert html =~ "Low"
      assert html =~ "Medium"
      assert html =~ "High"
    end
  end
end
