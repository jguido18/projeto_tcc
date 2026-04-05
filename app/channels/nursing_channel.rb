class NursingChannel < ApplicationCable::Channel
  def subscribed
    if current_user&.staff?
      stream_from "nursing_establishment_#{current_user.establishment_id}"
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def self.broadcast_panel_update(establishment)
    ActionCable.server.broadcast(
      "nursing_establishment_#{establishment.id}",
      { type: "panel_update" }
    )
  end
end
