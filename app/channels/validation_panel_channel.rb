class ValidationPanelChannel < ApplicationCable::Channel
  def subscribed
    if current_user&.staff?
      stream_from "validation_panel"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_update
    ActionCable.server.broadcast(
      "validation_panel",
      { type: "panel_update" }
    )
  end
end
