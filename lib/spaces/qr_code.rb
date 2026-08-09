# frozen_string_literal: true

module Spaces
  # Returns the paths and the module count, not an <svg>: writing the element is the
  # template's job, and `standalone: true` would emit an XML declaration that is invalid
  # inside HTML anyway.
  module QrCode
    # The quiet zone the format asks for, carried in the viewBox rather than as CSS padding
    # so it scales with the image instead of depending on how big the box happens to be.
    QUIET_ZONE = 4

    module_function

    def call(url)
      code = RQRCode::QRCode.new(url)
      paths = code.as_svg(module_size: 1, offset: QUIET_ZONE, standalone: false, use_path: true, color: '000')

      [paths, code.modules.size + (QUIET_ZONE * 2)]
    end
  end
end
