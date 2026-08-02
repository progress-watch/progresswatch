# frozen_string_literal: true

# Static pages, one route and one template each — no action methods, because Rails
# renders app/views/pages/<action>.html.erb when it finds no method to call. A page that
# needs nothing but its own prose should not need a controller of its own.
class PagesController < WebController
end
