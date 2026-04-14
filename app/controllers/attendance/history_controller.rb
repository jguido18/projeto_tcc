class Attendance::HistoryController < Attendance::BaseController
  def index
    scope = QueueEntry
      .includes(triage_session: :user)
      .where(status: :completed)
      .order(service_finished_at: :desc)

    if params[:patient_name].present?
      scope = scope.joins(triage_session: :user)
                   .where("users.name ILIKE ?", "%#{params[:patient_name].strip}%")
    end

    if params[:demand].present?
      scope = scope.joins(:triage_session)
                   .where("triage_sessions.initial_demand ILIKE ?", "%#{params[:demand].strip}%")
    end

    if params[:date_from].present?
      scope = scope.where("queue_entries.service_finished_at >= ?", params[:date_from].to_date.beginning_of_day)
    end

    if params[:date_to].present?
      scope = scope.where("queue_entries.service_finished_at <= ?", params[:date_to].to_date.end_of_day)
    end

    count  = scope.count
    @pagy  = Pagy::Offset.new(count: count, page: params[:page], limit: 20, request: request)
    @entries = @pagy.records(scope)
  end
end
