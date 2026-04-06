module ApplicationHelper
  def urgency_label(level)
    return "-" if level.blank?

    TriageSetting.current.urgency_label_for(level)
  end

  def urgency_color(level)
    return "#718096" if level.blank?

    TriageSetting.current.urgency_color_for(level)
  end

  def urgency_badge_style(level)
    color = urgency_color(level)
    "background: #{color}; color: #{contrast_text_color(color)};"
  end

  def urgency_soft_style(level, alpha = 0.14)
    color = urgency_color(level)
    "background: #{hex_to_rgba(color, alpha)}; color: #{color};"
  end

  private

  def contrast_text_color(hex)
    raw = hex.to_s.delete("#")
    raw = raw.chars.map { |char| "#{char}#{char}" }.join if raw.length == 3
    return "#FFFFFF" unless raw.length == 6

    r = raw[0..1].to_i(16)
    g = raw[2..3].to_i(16)
    b = raw[4..5].to_i(16)
    luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
    luminance > 160 ? "#1A202C" : "#FFFFFF"
  end

  def hex_to_rgba(hex, alpha)
    raw = hex.to_s.delete("#")
    raw = raw.chars.map { |char| "#{char}#{char}" }.join if raw.length == 3
    return "rgba(113, 128, 150, #{alpha})" unless raw.length == 6

    r = raw[0..1].to_i(16)
    g = raw[2..3].to_i(16)
    b = raw[4..5].to_i(16)
    "rgba(#{r}, #{g}, #{b}, #{alpha})"
  end
end
