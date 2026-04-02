# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "shapeup-cli"
  s.version     = "0.3.1"
  s.summary     = "ShapeUp CLI — manage pitches, scopes, tasks, and cycles from the terminal"
  s.description = "Command-line interface for ShapeUp, the Shape Up methodology platform. " \
                  "Works with any AI agent that can execute shell commands. " \
                  "Zero dependencies — pure Ruby stdlib."
  s.authors     = ["ShapeUp"]
  s.email       = ["hello@shapeup.cc"]
  s.homepage    = "https://github.com/shapeupcc/shapeup-cli"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1"

  s.files       = Dir["lib/**/*", "skills/**/*", "install.md"]
  s.bindir      = "bin"
  s.executables = ["shapeup"]

  s.metadata = {
    "homepage_uri" => s.homepage,
    "source_code_uri" => s.homepage,
    "bug_tracker_uri" => "#{s.homepage}/issues"
  }
end
