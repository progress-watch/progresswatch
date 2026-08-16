# frozen_string_literal: true

# Two frames, split so that only the running half is on the fast poll.
#
# Opened directly in a browser, either response is a bare fragment with no stylesheet and
# no JavaScript — an unstyled wall of text that reads as a broken site rather than as the
# wrong URL. Turbo names the frame it is fetching for in a header, so anything without
# one is a person and belongs on the real page.
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
