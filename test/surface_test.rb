# frozen_string_literal: true

require_relative "test_helper"
require "shapeup_cli/surface"

class SurfaceTest < Minitest::Test
  SNAPSHOT = File.expand_path("../SURFACE.txt", __dir__)

  def test_cli_surface_matches_the_committed_snapshot
    if ENV["GENERATE_SURFACE"]
      File.write(SNAPSHOT, ShapeupCli::Surface.render)
      skip "SURFACE.txt regenerated"
    end

    assert File.exist?(SNAPSHOT), "SURFACE.txt missing. Generate it with: GENERATE_SURFACE=1 ruby test/surface_test.rb"

    committed = File.read(SNAPSHOT).lines(chomp: true)
    current = ShapeupCli::Surface.lines

    added = current - committed
    removed = committed - current

    message = +"CLI surface has changed.\n"
    message << "\nAdded:\n#{added.map { |l| "  #{l}" }.join("\n")}\n" if added.any?
    message << "\nRemoved (BREAKING):\n#{removed.map { |l| "  #{l}" }.join("\n")}\n" if removed.any?
    message << "\nIf intentional, regenerate with: GENERATE_SURFACE=1 ruby test/surface_test.rb"

    assert_equal committed, current, message
  end
end
