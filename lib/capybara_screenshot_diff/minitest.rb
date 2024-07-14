# frozen_string_literal: true

require "minitest"
require "capybara_screenshot_diff/dsl"

module CapybaraScreenshotDiff
  module Minitest
    module Assertions
      include ::CapybaraScreenshotDiff::DSL

      def screenshot(name, skip_stack_frames: 0, **options)
        super(name, skip_stack_frames: skip_stack_frames + 1, **options)
      rescue CapybaraScreenshotDiff::ExpectationNotMet => e
        raise ::Minitest::Assertion, e.message
      end

      alias_method :assert_matches_screenshot, :screenshot

      def self.included(klass)
        klass.setup do
          if ::Capybara::Screenshot.window_size
            ::Capybara::Screenshot::BrowserHelpers.resize_to(::Capybara::Screenshot.window_size)
          end
        end

        klass.teardown do
          errors = validate_screenshots!(@test_screenshots)

          failures << ::Minitest::Assertion.new(errors.join("\n\n")) if errors && !errors.empty?
        end
      end
    end
  end
end
