# frozen_string_literal: true

class SpaceTasksController < WebController
  def index
    @space = Space.find(params[:uuid])

    return redirect_to space_path(@space.uuid) unless turbo_frame_request?

    params[:state] == 'finished' ? finished : active
  end

  private

  def active
    @tasks = Spaces::ReadActiveTasks.call(@space)

    render :index, layout: false
  end

  def finished
    @history = Spaces::ReadFinishedTasks.call(@space, before: params[:before])
    @page = params[:page].to_i.clamp(0, 999)

    render :finished, layout: false
  rescue Spaces::ReadTasks::InvalidWindow
    head :bad_request
  end
end
