# frozen_string_literal: true

class SpacesController < WebController
  SEARCH_FROM = 10

  def show
    @space = Space.find(params[:uuid])
    @query = params[:q].presence
    @tasks = Spaces::ReadActiveTasks.call(@space, query: @query)
    @history = Spaces::ReadFinishedTasks.call(@space, query: @query)
    @page = 0
    @searchable = @query.present? || on_the_page >= SEARCH_FROM
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

  private

  def on_the_page
    @tasks.size + @history['sections'].sum { |section| section['tasks'].size }
  end
end
