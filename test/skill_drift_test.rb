# frozen_string_literal: true

require_relative "test_helper"

class SkillDriftTest < Minitest::Test
  SKILL_PATH = File.expand_path("../skills/shapeup/SKILL.md", __dir__)

  def setup
    @skill_content = File.read(SKILL_PATH)
  end

  def test_skill_file_exists
    assert File.exist?(SKILL_PATH), "SKILL.md not found at #{SKILL_PATH}"
  end

  def test_skill_has_yaml_frontmatter
    assert @skill_content.start_with?("---"), "SKILL.md must start with YAML frontmatter"
    assert @skill_content.scan("---").length >= 2, "SKILL.md must have closing --- for frontmatter"
  end

  def test_skill_has_required_frontmatter_fields
    frontmatter = @skill_content.split("---")[1]
    assert_match(/^name:\s+shapeup/m, frontmatter, "Missing name: shapeup in frontmatter")
    assert_match(/^description:/m, frontmatter, "Missing description in frontmatter")
    assert_match(/^triggers:/m, frontmatter, "Missing triggers in frontmatter")
    assert_match(/^invocable:\s+true/m, frontmatter, "Missing invocable: true in frontmatter")
  end

  # Verify every command referenced in Quick Reference actually exists in COMMAND_MAP or shortcuts
  def test_quick_reference_commands_exist
    valid_commands = %w[login logout auth orgs pitches pitch cycles cycle scopes tasks todo done issues issue watching comments me my-work search config setup --agent --json --md --quiet --ids-only --org --host]

    # Extract command names from Quick Reference table: lines like "| ... | `shapeup <command> ...` |"
    @skill_content.scan(/`shapeup ([\w-]+)/).flatten.uniq.each do |cmd|
      assert valid_commands.include?(cmd),
        "SKILL.md references 'shapeup #{cmd}' but '#{cmd}' is not a valid command"
    end
  end

  # Verify all COMMAND_MAP entries are documented in the skill
  def test_all_commands_documented_in_skill
    ShapeupCli::COMMAND_MAP.each_key do |name|
      assert_match(/shapeup #{Regexp.escape(name)}/,
        @skill_content,
        "Command '#{name}' is in COMMAND_MAP but not documented in SKILL.md")
    end
  end

  # Verify exit codes in SKILL.md match the constants
  def test_exit_codes_match
    assert_includes @skill_content, "| 0 |", "Missing exit code 0 in SKILL.md"
    assert_includes @skill_content, "| 2 |", "Missing exit code 2 in SKILL.md"
    assert_includes @skill_content, "| 3 |", "Missing exit code 3 in SKILL.md"
    assert_includes @skill_content, "| 4 |", "Missing exit code 4 in SKILL.md"
    assert_includes @skill_content, "| 5 |", "Missing exit code 5 in SKILL.md"
    assert_includes @skill_content, "| 6 |", "Missing exit code 6 in SKILL.md"
    assert_includes @skill_content, "| 130 |", "Missing exit code 130 in SKILL.md"
  end

  # Verify output modes in SKILL.md match what parse_mode accepts
  def test_output_modes_documented
    assert_includes @skill_content, "--json", "Missing --json in SKILL.md"
    assert_includes @skill_content, "--md", "Missing --md in SKILL.md"
    assert_includes @skill_content, "--agent", "Missing --agent in SKILL.md"
    assert_includes @skill_content, "--quiet", "Missing --quiet in SKILL.md"
    assert_includes @skill_content, "--ids-only", "Missing --ids-only in SKILL.md"
  end

  # Verify env vars are documented
  def test_env_vars_documented
    assert_includes @skill_content, "SHAPEUP_TOKEN", "Missing SHAPEUP_TOKEN in SKILL.md"
    assert_includes @skill_content, "SHAPEUP_ORG", "Missing SHAPEUP_ORG in SKILL.md"
    assert_includes @skill_content, "SHAPEUP_HOST", "Missing SHAPEUP_HOST in SKILL.md"
  end
end
