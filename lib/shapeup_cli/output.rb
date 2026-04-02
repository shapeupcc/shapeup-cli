# frozen_string_literal: true

module ShapeupCli
  module Output
    # Parse output mode flags from args, returns [mode, remaining_args]
    def self.parse_mode(args)
      mode = nil
      remaining = []

      args.each do |arg|
        case arg
        when "--json"  then mode = :json
        when "--md", "-m" then mode = :markdown
        when "--agent" then mode = :agent
        when "--quiet", "-q" then mode = :agent
        when "--ids-only" then mode = :ids_only
        else remaining << arg
        end
      end

      # Default: auto-detect from TTY. Piped output → JSON, terminal → styled.
      mode ||= Config.piped? ? :json : :styled

      [ mode, remaining ]
    end

    # Render a tool result with breadcrumbs in the specified output mode
    def self.render(result, breadcrumbs: [], mode: :styled, summary: nil)
      # Extract text content from MCP tool result
      data = extract_data(result)

      case mode
      when :json
        render_json(data, breadcrumbs: breadcrumbs, summary: summary)
      when :agent
        render_agent(data)
      when :markdown
        render_markdown(data, summary: summary)
      when :ids_only
        render_ids_only(data)
      else
        render_styled(data, breadcrumbs: breadcrumbs, summary: summary)
      end
    end

    def self.extract_data(result)
      return result unless result.is_a?(Hash)

      # MCP tool results come wrapped: { content: [{ type: "text", text: "..." }] }
      if result["content"]&.is_a?(Array)
        text = result["content"].filter_map { |c| c["text"] if c["type"] == "text" }.join
        JSON.parse(text) rescue text
      else
        result
      end
    end

    def self.render_json(data, breadcrumbs: [], summary: nil)
      envelope = { ok: true, data: data }
      envelope[:summary] = summary if summary
      envelope[:breadcrumbs] = breadcrumbs if breadcrumbs.any?
      puts JSON.pretty_generate(envelope)
    end

    def self.render_agent(data)
      # Minimal: just the data, no envelope
      if data.is_a?(String)
        puts data
      else
        puts JSON.generate(data)
      end
    end

    def self.render_ids_only(data)
      items = case data
      when Array then data
      when Hash then data.values.find { |v| v.is_a?(Array) } || [ data ]
      else [ data ]
      end

      items.each do |item|
        puts item.is_a?(Hash) ? item["id"] : item
      end
    end

    def self.render_markdown(data, summary: nil)
      puts "**#{summary}**\n" if summary

      case data
      when Array
        render_markdown_table(data)
      when Hash
        render_markdown_hash(data)
      else
        puts data.to_s
      end
    end

    def self.render_styled(data, breadcrumbs: [], summary: nil)
      puts summary if summary
      puts

      case data
      when Array
        render_styled_list(data)
      when Hash
        render_styled_hash(data)
      else
        puts data.to_s
      end

      if breadcrumbs.any?
        puts
        puts "Next:"
        breadcrumbs.each do |b|
          puts "  #{b[:cmd]}  # #{b[:description]}"
        end
      end
    end

    # --- Styled renderers ---

    def self.render_styled_list(items)
      return puts("  (none)") if items.empty?

      items.each do |item|
        case item
        when Hash
          render_styled_list_item(item)
        else
          puts "  #{item}"
        end
      end
    end

    def self.render_styled_list_item(item)
      # Smart display: detect common fields
      id = item["id"]
      title = item["title"] || item["name"] || item["description"]
      status = item["status"]

      line = "  #{id}"
      line += "  #{title}" if title
      line += "  (#{status})" if status
      puts line
    end

    def self.render_styled_hash(data)
      max_key = data.keys.map { |k| k.to_s.length }.max || 0

      data.each do |key, value|
        label = key.to_s.ljust(max_key)
        case value
        when Array
          puts "  #{label}  (#{value.length} items)"
          value.first(5).each { |v| puts "    #{format_list_value(v)}" }
          puts "    ... and #{value.length - 5} more" if value.length > 5
        when Hash
          puts "  #{label}  #{format_value(value)}"
        else
          puts "  #{label}  #{value}"
        end
      end
    end

    def self.format_value(value)
      case value
      when Hash
        value["title"] || value["name"] || value["description"] || value.to_json
      else
        value.to_s
      end
    end

    def self.format_list_value(value)
      case value
      when Hash
        id = value["id"]
        label = value["title"] || value["name"] || value["description"]
        [id, label].compact.join("  ")
      else
        value.to_s
      end
    end

    # --- Markdown renderers ---

    def self.render_markdown_table(items)
      return puts("_No results_") if items.empty?
      return items.each { |i| puts "- #{i}" } unless items.first.is_a?(Hash)

      keys = items.first.keys.reject { |k| k.is_a?(String) && items.first[k].is_a?(Array) }
      keys = keys.first(6) # Keep tables readable

      # Header
      puts "| #{keys.map { |k| k.to_s.gsub("_", " ").capitalize }.join(" | ")} |"
      puts "| #{keys.map { |_| "---" }.join(" | ")} |"

      # Rows
      items.each do |item|
        values = keys.map { |k| truncate(item[k].to_s, 40) }
        puts "| #{values.join(" | ")} |"
      end
    end

    def self.render_markdown_hash(data)
      data.each do |key, value|
        case value
        when Array
          puts "### #{key.to_s.gsub("_", " ").capitalize} (#{value.length})"
          render_markdown_table(value)
          puts
        when Hash
          puts "### #{key}"
          render_markdown_hash(value)
        else
          puts "- **#{key}**: #{value}"
        end
      end
    end

    def self.truncate(str, length)
      str.length > length ? "#{str[0...length - 1]}…" : str
    end

    private_class_method :render_json, :render_agent, :render_ids_only, :render_markdown, :render_styled,
      :render_styled_list, :render_styled_list_item, :render_styled_hash,
      :render_markdown_table, :render_markdown_hash, :format_value, :format_list_value, :truncate
  end
end
