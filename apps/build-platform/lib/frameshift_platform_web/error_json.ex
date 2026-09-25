defmodule FrameshiftPlatformWeb.ErrorJSON do
  @moduledoc "Public errors exclude exception messages and request content."

  @spec render(String.t(), map()) :: map()
  def render(template, _) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
