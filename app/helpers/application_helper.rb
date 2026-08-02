# frozen_string_literal: true

# One partial per icon under app/views/icons, the way docuseal does it. Anything the
# caller passes lands on the <svg> itself, so `class` and the `data-` hooks the
# stylesheet and the custom elements look for both go through here.
module ApplicationHelper
  def svg_icon(name, **attributes)
    render "icons/#{name}", attributes: attributes
  end
end
