# frozen_string_literal: true

# Just the task list, for the frame the space page polls. No layout: Turbo splices the
# frame's contents into the page it already has.
#
# Opened directly in a browser, that same response is a bare fragment with no stylesheet
# and no JavaScript — an unstyled wall of text that reads as a broken site rather than as
# the wrong URL. Turbo names the frame it is fetching for in a header, so anything
# without one is a person and belongs on the real page.
class SpaceTasksController < WebController
  def index
    @space = Space.find(params[:uuid])

    return redirect_to space_path(@space.uuid) unless turbo_frame_request?

    @tasks = Tasks::PrepareForDashboard.call(Spaces::SerializeForApi.call(@space)['tasks'])

    render layout: false
  end
end
