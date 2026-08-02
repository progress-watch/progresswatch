# frozen_string_literal: true

class DashboardsController < WebController
  def show
    @space = find_space
    return if @space.nil?

    @tasks = Spaces::SerializeForApi.call(@space)['tasks']
  end

  # Just the task list, for the frame the page polls. No layout: Turbo splices the
  # frame's contents into the page it already has.
  #
  # Opened directly in a browser, that same response is a bare fragment with no
  # stylesheet and no JavaScript — an unstyled wall of text that reads as a broken
  # site rather than as the wrong URL. Turbo names the frame it is fetching for in a
  # header, so anything without one is a person and belongs on the real page.
  def tasks
    @space = find_space
    return if @space.nil?

    return redirect_to dashboard_path(@space.uuid) if request.headers['Turbo-Frame'].blank?

    @tasks = Spaces::SerializeForApi.call(@space)['tasks']

    render layout: false
  end

  # The web equivalent of POST /spaces, plus a rename the JSON API deliberately does
  # not have: a browser creates a space before anyone can name it, so it is the only
  # client that needs to change one afterwards.
  def create
    space = Spaces::Create.call(title: params[:title].presence, icon: params[:icon])

    redirect_to dashboard_path(space.uuid)
  end

  def update
    @space = find_space
    return if @space.nil?

    Spaces::Update.call(@space, title: params[:title], icon: params[:icon])

    redirect_to dashboard_path(@space.uuid)
  end
end
