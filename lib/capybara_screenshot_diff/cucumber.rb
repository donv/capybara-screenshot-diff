# frozen_string_literal: true

require "capybara/screenshot/diff"
require "capybara/screenshot/diff/test_methods"

module Capybara::Screenshot::Diff
  ASSERTION = ::StandardError unless defined?(::Capybara::Screenshot::Diff::ASSERTION)
end

World(Capybara::Screenshot::Diff::TestMethods)

Before do
  Capybara::Screenshot::Diff.delayed = false
  if Capybara::Screenshot.active? && Capybara::Screenshot.window_size
    Capybara::Screenshot::BrowserHelpers.resize_to(Capybara::Screenshot.window_size)
  end
end
