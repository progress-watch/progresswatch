# frozen_string_literal: true

# Renaming is web-only on purpose: a browser has to create a space before anyone can
# name it, while a CLI or an agent already knows the name and the icon at creation time.
class SpacesController < WebController
  def show
    @space = Space.find(params[:uuid])
    @tasks = Spaces::ReadActiveTasks.call(@space)
    @history = Spaces::ReadFinishedTasks.call(@space)
    @page = 0
  end

  def new
    render layout: !turbo_frame_request?
  end

  def edit
    @space = Space.find(params[:uuid])

    render layout: !turbo_frame_request?
  end

  def create
    space = Spaces::Create.call(title: params[:title].presence, icon: params[:icon])

    redirect_to space_path(space.uuid)
  end

  def update
    space = Space.find(params[:uuid])

    Spaces::Update.call(space, title: params[:title], icon: params[:icon])

    redirect_to space_path(space.uuid)
  end
end
