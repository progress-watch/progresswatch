# frozen_string_literal: true

module Spaces
  # Paths and a module count, not an <svg>: `standalone: true` emits an XML declaration
  # that is invalid inside HTML.
  module QrCode
    QUIET_ZONE = 4

    module_function

    def call(url)
      code = RQRCode::QRCode.new(url)
      paths = code.as_svg(module_size: 1, offset: QUIET_ZONE, standalone: false, use_path: true, color: '000')

      [paths, code.modules.size + (QUIET_ZONE * 2)]
    end
  end
end
