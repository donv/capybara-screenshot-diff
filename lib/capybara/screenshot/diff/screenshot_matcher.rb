# frozen_string_literal: true

require "capybara_screenshot_diff/snap_manager"
require_relative "screenshoter"
require_relative "stable_screenshoter"
require_relative "browser_helpers"
require_relative "vcs"
require_relative "area_calculator"

module Capybara
  module Screenshot
    module Diff
      class ScreenshotMatcher
        attr_reader :screenshot_full_name, :driver_options, :screenshot_format

        def initialize(screenshot_full_name, options = {})
          @screenshot_full_name = screenshot_full_name
          @driver_options = Diff.default_options.merge(options)

          @screenshot_format = @driver_options[:screenshot_format]
          @snapshot = CapybaraScreenshotDiff::SnapManager.snapshot(screenshot_full_name, @screenshot_format)
        end

        def build_screenshot_matches_job
          # TODO: Move this into screenshot stage, in order to re-evaluate coordinates after page updates
          return if BrowserHelpers.window_size_is_wrong?(Screenshot.window_size)

          # TODO: Move this into screenshot stage, in order to re-evaluate coordinates after page updates
          area_calculator = AreaCalculator.new(driver_options.delete(:crop), driver_options[:skip_area])
          driver_options[:crop] = area_calculator.calculate_crop

          # TODO: Move this into screenshot stage, in order to re-evaluate coordinates after page updates
          # Allow nil or single or multiple areas
          driver_options[:skip_area] = area_calculator.calculate_skip_area
          driver_options[:driver] = Drivers.for(driver_options[:driver])

          @snapshot.checkout_base_screenshot

          # When fail_if_new is true no need to create screenshot if base screenshot is missing
          return if Capybara::Screenshot::Diff.fail_if_new && !@snapshot.base_path.exist?

          capture_options, comparison_options = extract_capture_and_comparison_options!(driver_options)

          # Load new screenshot from Browser
          take_comparison_screenshot(capture_options, comparison_options, @snapshot)

          # Pre-computation: No need to compare without base screenshot
          return unless @snapshot.base_path.exist?

          # Add comparison job in the queue
          [screenshot_full_name, ImageCompare.new(@snapshot.path, @snapshot.base_path, comparison_options)]
        end

        private

        def extract_capture_and_comparison_options!(driver_options = {})
          [
            {
              # screenshot options
              capybara_screenshot_options: driver_options[:capybara_screenshot_options],
              crop: driver_options.delete(:crop),
              # delivery options
              screenshot_format: driver_options[:screenshot_format],
              # stability options
              stability_time_limit: driver_options.delete(:stability_time_limit),
              wait: driver_options.delete(:wait)
            },
            driver_options
          ]
        end

        # Try to get screenshot from browser.
        # On `stability_time_limit` it checks that page stop updating by comparison several screenshot attempts
        # On reaching `wait` limit then it has been failed. On failing we annotate screenshot attempts to help to debug
        def take_comparison_screenshot(capture_options, comparison_options, snapshot = nil)
          screenshoter = build_screenshoter_for(capture_options, comparison_options)
          screenshoter.take_comparison_screenshot(snapshot)
        end

        def build_screenshoter_for(capture_options, comparison_options = {})
          if capture_options[:stability_time_limit]
            StableScreenshoter.new(capture_options, comparison_options)
          else
            Diff.screenshoter.new(capture_options, comparison_options[:driver])
          end
        end
      end
    end
  end
end
