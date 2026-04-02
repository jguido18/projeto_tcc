class TriageController < ApplicationController
  before_action :authenticate_user!
  before_action :require_patient!
  before_action :set_session, only: [ :chat, :message, :queue ]

  # GET /triage/identification
  def identification
    redirect_to triage_queue_path if active_triage_session
  end

  # POST /triage/start
  def start
    if active_triage_session
      redirect_to triage_queue_path and return
    end

    @triage_session = TriageSession.create!(
      user: current_user,
      establishment: current_user.establishment,
      status: :in_triage,
      chief_complaint: params[:chief_complaint],
      started_at: Time.current
    )

    # Send opening AI message
    service = TriageService.new(@triage_session)
    service.process_message(params[:chief_complaint])

    redirect_to triage_chat_path
  end

  # GET /triage/chat
  def chat
    redirect_to triage_queue_path if @triage_session.awaiting_validation? ||
                                     @triage_session.validated? ||
                                     @triage_session.in_queue?
  end

  # POST /triage/message
  def message
    unless @triage_session.in_triage?
      render json: { error: "Triage already finished" }, status: :unprocessable_entity and return
    end

    result = TriageService.new(@triage_session).process_message(params[:content])

    render json: {
      finished: result[:finished],
      redirect_to: result[:finished] ? triage_queue_path : nil
    }
  end

  # GET /triage/queue
  def queue
    @queue_entry = @triage_session.queue_entry
    @ai_classification = @triage_session.ai_classification
  end

  private

  def set_session
    @triage_session = current_user.triage_sessions
                                  .where.not(status: [ :completed, :cancelled ])
                                  .order(created_at: :desc)
                                  .first

    redirect_to triage_identification_path unless @triage_session
  end

  def active_triage_session
    current_user.triage_sessions.active.first
  end
end
