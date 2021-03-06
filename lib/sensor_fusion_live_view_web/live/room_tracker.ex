defmodule SensorFusionLiveViewWeb.RoomTracker do
  use SensorFusionLiveViewWeb, :live_view

  @width 10
  @room_height 600
  @room_width 600
  @precision_cm 1

  def render(assigns) do
    ~L"""
    <div class="room-container"
        style="width: <%= @room_width + @width %>px;
                height: <%= @room_height + @width %>px">
      <%= coef = if @coef_x > @coef_y, do: @coef_y, else: @coef_x %>
      <%= for obj <- @object_pos do %>
        <%= for {pos_x,pos_y} <- obj[:pos] do %>
          <%= if length(obj[:pos]) == 1 do %>
            <div class="block object"
              style="left: <%= x(pos_x, coef, @min_x) %>px;
                      top: <%= x(pos_y, coef, @min_y) %>px;
                      width: <%= @width %>px;
                      height: <%= @width %>px;"></div>
          <%= else %>
            <div class="block two_objects"
              style="left: <%= x(pos_x, coef, @min_x) %>px;
                      top: <%= x(pos_y, coef, @min_y) %>px;
                      width: <%= @width %>px;
                      height: <%= @width %>px;"></div>
          <% end %>
        <% end %>
      <% end %>
      <%= for s <- @sonars do %>
        <div class="block sonar"
            style="left: <%= x(s[:x], coef, @min_x) %>px;
                    top: <%= x(s[:y], coef, @min_y) %>px;
                    width: <%= @width %>px;
                    height: <%= @width %>px;"></div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(SensorFusionLiveView.PubSub, "position:calculations")
    Phoenix.PubSub.subscribe(SensorFusionLiveView.PubSub, "room:pos")

    {:ok, socket |> build_room() |> place_sonars() |> place_object()}
  end

  def handle_info(pos = [pos: map], socket) do
    {:noreply, place_sonars(socket, pos)}
  end

  def handle_info(calculation = [position: map], socket) do
    {:noreply, place_object(socket, calculation)}
  end

  def handle_event("nav", _path, socket) do
    {:noreply, socket}
  end

  defp build_room(socket) do
    defaults = %{
      room_width: @room_width,
      room_height: @room_height,
      coef_x: 1,
      coef_y: 1,
      width: @width
    }
    assign(socket, defaults)
  end

  defp x(x_idx, coef, min_x), do: (x_idx-min_x)*coef
  defp y(y_odx, coef, min_y), do: (y_odx-min_y)*coef

  defp sonar(x_idx, y_idx, width) do
    %{type: :sonar, x: x_idx * width, y: y_idx * width, width: width}
  end

  defp object(x_idx, y_idx, width) do
    %{type: :object, x: x_idx * width, y: y_idx * width, width: width}
  end

  defp place_sonars(socket, sonars \\ [pos: %{node@nohost: {-1, {%{x: -1, y: -1, node_id: -1}, -1}}}]) do
    positions = for node <- Map.keys(sonars[:pos]) do
      {_, {%{x: x, y: y, node_id: _}, _}} = sonars[:pos][node]
      %{x: x, y: y}
    end
    socket
    |> coef_x(positions)
    |> coef_y(positions)
    |> assign(:sonars, positions)
  end

  defp coef_x(socket, positions) do
    max_x = List.foldl(positions, 1, fn pos, acc -> if pos[:x] > acc, do: pos[:x], else: acc end)
    min_x = List.foldl(positions, @room_width, fn pos, acc -> if pos[:x] < acc, do: pos[:x], else: acc end)
    max_x = if max_x == 1, do: 600, else: max_x
    min_x = if min_x == @room_width, do: 0, else: min_x
    assign(socket, coef_x: @room_width / (max_x - min_x), min_x: min_x)
  end

  defp coef_y(socket, positions) do
    max_y = List.foldl(positions, 1, fn pos, acc -> if pos[:y] > acc, do: pos[:y], else: acc end)
    min_y = List.foldl(positions, @room_height, fn pos, acc -> if pos[:y] < acc, do: pos[:y], else: acc end)
    max_y = if max_y == 1, do: 600, else: max_y
    min_y = if min_y == @room_height, do: 0, else: min_y
    assign(socket, coef_y: @room_height / (max_y - min_y), min_y: min_y)
  end

  defp place_object(socket, object_positions \\ [position: %{node@nohost: {-1, [{10.5,20.5}]}}]) do
    positions = object_positions[:position]
    object_pos = for k <- Map.keys(positions) do
      {_, pos} = positions[k]
      %{pos: pos, width: @width}
    end
    assign(socket, :object_pos, object_pos)
  end
end
