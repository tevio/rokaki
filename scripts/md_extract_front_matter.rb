#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract all human-visible Markdown text items into named key/value pairs
# suitable for translation catalogs (YAML). Keys are deterministic and
# sequential by document order. We cover headings, paragraphs, lists, tables,
# code blocks (by default marked as translatable content too, though you may
# exclude them on the translation platform), and also collect link texts and
# image alt texts as separate keys.
#
# Usage:
#   ruby scripts/md_extract_front_matter.rb [page ...]
#   # If no pages are given, defaults to docs/index.md, usage.md, adapters.md, configuration.md
#
# Output:
#   i18n/src/en/<page>.yml — flat map of keys to values
#   (Creates directories if missing)
#
# Notes:
# - Requires kramdown + kramdown-parser-gfm (already referenced in docs/Gemfile).
# - This script does not modify the source Markdown files; it only generates the YAML catalogs.

require 'yaml'
require 'fileutils'
begin
  require 'kramdown'
  require 'kramdown-parser-gfm'
rescue LoadError => e
  warn "Missing kramdown dependencies. Please run: (cd docs && bundle install)\n  And execute with: BUNDLE_GEMFILE=docs/Gemfile bundle exec ruby scripts/md_extract_front_matter.rb"
  raise
end

ROOT = File.expand_path('..', __dir__)
DOCS_DIR = File.join(ROOT, 'docs')
I18N_EN_DIR = File.join(ROOT, 'i18n', 'src', 'en')

DEFAULT_PAGES = %w[index usage adapters configuration]

# Simple counter registry for deterministic keys
class Counters
  def initialize
    @c = Hash.new(0)
  end

  def next(key)
    @c[key] += 1
  end

  def format(prefix, n)
    sprintf('%s_%03d', prefix, n)
  end
end

# Renderer that converts a Kramdown inline element array into Markdown text.
# This is intentionally conservative: it preserves emphasis and links/images
# as Markdown so translators see context. URLs are included in the text here;
# we also collect link text / image alt separately in dedicated keys.
module InlineRenderer
  module_function

  def render_children(el)
    (el.children || []).map { |c| render(c) }.join
  end

  def render(el)
    case el.type
    when :text
      el.value.to_s
    when :codespan
      "`#{el.value}`"
    when :em
      "*#{render_children(el)}*"
    when :strong
      "**#{render_children(el)}**"
    when :kbd
      "<kbd>#{render_children(el)}</kbd>"
    when :br
      "  \n"
    when :a
      label = (el.children || []).map { |c| render(c) }.join
      href  = el.attr && el.attr['href']
      title = el.attr && el.attr['title']
      title_part = title && !title.empty? ? " \"#{title}\"" : ''
      href ? "[#{label}](#{href}#{title_part})" : label
    when :img
      alt = el.attr && el.attr['alt']
      src = el.attr && el.attr['src']
      title = el.attr && el.attr['title']
      title_part = title && !title.empty? ? " \"#{title}\"" : ''
      src ? "![#{alt}](#{src}#{title_part})" : (alt || '')
    when :html_element, :html_raw
      el.value.to_s
    else
      # Fallback: render children
      render_children(el)
    end
  end
end

# Extract plain text from inline nodes (for link text / image alt separate keys)
module InlinePlain
  module_function

  def text_of(el)
    case el.type
    when :text
      el.value.to_s
    when :codespan
      el.value.to_s # treat codespan as plain
    when :em, :strong, :kbd, :a
      (el.children || []).map { |c| text_of(c) }.join
    when :img
      el.attr && el.attr['alt'] || ''
    else
      (el.children || []).map { |c| text_of(c) }.join
    end
  end
end

class Extractor
  def initialize(doc_text)
    @doc = Kramdown::Document.new(doc_text, input: 'GFM')
    @counters = Counters.new
    @result = {}
  end

  attr_reader :result

  def extract
    traverse(@doc.root)
    @result
  end

  private

  def add_key(prefix, value)
    n = @counters.next(prefix)
    key = @counters.format(prefix, n)
    @result[key] = normalize(value)
  end

  def normalize(s)
    s = s.to_s
    # Normalize newlines
    s = s.gsub("\r\n", "\n").gsub("\r", "\n")
    # Trim trailing whitespace on lines
    s = s.lines.map { |ln| ln.rstrip }.join("\n")
    s
  end

  def traverse(node)
    node.children.each do |el|
      case el.type
      when :header
        txt = InlineRenderer.render_children(el)
        add_key("h#{el.options[:level]}", txt)
        collect_inline_extras(el)
      when :p
        txt = InlineRenderer.render_children(el)
        add_key('p', txt)
        collect_inline_extras(el)
      when :ul
        top_index = @counters.next('ul')
        list_key = sprintf('ul_%03d', top_index)
        list_map = extract_list(el, :ul)
        @result[list_key] = list_map unless list_map.empty?
      when :ol
        top_index = @counters.next('ol')
        list_key = sprintf('ol_%03d', top_index)
        list_map = extract_list(el, :ol)
        @result[list_key] = list_map unless list_map.empty?
      when :codeblock
        code = el.value.to_s
        add_key('code', code)
      when :blockquote
        # Extract paragraphs within blockquote as normal paragraphs
        traverse(el)
      when :table
        extract_table(el)
      else
        # Recurse into children for any other container types (e.g., dl, html)
        traverse(el) if el.children && !el.children.empty?
      end
    end
  end

  def render_li(li_el)
    # Legacy: produce a flattened textual representation of an li, including nested lists summarized.
    # Kept for backward compatibility if needed elsewhere; not used by new nested-list extraction.
    parts = []
    (li_el.children || []).each do |child|
      case child.type
      when :p
        parts << InlineRenderer.render_children(child)
      when :header
        parts << InlineRenderer.render_children(child)
      when :codeblock
        parts << "\n" + child.value.to_s + "\n"
      when :ul, :ol
        # Nested list: summarize as plain text lines
        (child.children || []).each do |subli|
          next unless subli.type == :li
          parts << "- " + InlinePlain.text_of(subli)
        end
      else
        parts << InlineRenderer.render(child)
      end
    end
    parts.reject(&:empty?).join("\n\n")
  end

  # Render only the immediate content of an li (excluding nested lists), preserving code/headers/paragraphs.
  def render_li_text(li_el)
    parts = []
    (li_el.children || []).each do |child|
      case child.type
      when :p
        parts << InlineRenderer.render_children(child)
      when :header
        parts << InlineRenderer.render_children(child)
      when :codeblock
        parts << child.value.to_s
      when :ul, :ol
        # skip here; handled as nested lists
      else
        parts << InlineRenderer.render(child)
      end
    end
    parts.map { |s| s.to_s.strip }.reject(&:empty?).join("\n\n")
  end

  # Recursively extract a list (:ul or :ol) into a nested hash structure with li_* children and nested lists.
  def extract_list(list_el, kind)
    list_map = {}
    li_idx = 0
    (list_el.children || []).each do |li|
      next unless li.type == :li
      li_idx += 1
      item = {}
      text = render_li_text(li)
      item['text'] = normalize(text) unless text.strip.empty?

      # collect inline link/image extras from this list item
      collect_inline_extras(li)

      # Handle nested lists within this li, numbering per type starting from 1
      nested_counts = Hash.new(0)
      (li.children || []).each do |child|
        next unless child.type == :ul || child.type == :ol
        n_kind = (child.type == :ul ? :ul : :ol)
        nested_counts[n_kind] += 1
        nested_key = sprintf('%s_%03d', n_kind, nested_counts[n_kind])
        item[nested_key] = extract_list(child, n_kind)
      end

      li_key = sprintf('li_%03d', li_idx)
      list_map[li_key] = item
    end
    list_map
  end

  def format(kind, list_index, li_el)
    # list item counter per list
    key_base = sprintf('%s_%03d', kind, list_index)
    per_list_counter_key = "#{key_base}_li"
    n = @counters.next(per_list_counter_key)
    sprintf('%s_li_%03d', key_base, n)
  end

  def collect_inline_extras(el)
    walk_inline(el) do |inline|
      case inline.type
      when :a
        label = InlinePlain.text_of(inline).strip
        add_key('link', label) unless label.empty?
      when :img
        alt = inline.attr && inline.attr['alt']
        add_key('img', alt.to_s) unless alt.to_s.empty?
      end
    end
  end

  def walk_inline(el, &blk)
    (el.children || []).each do |c|
      yield c
      walk_inline(c, &blk) if c.children && !c.children.empty?
    end
  end

  def extract_table(table_el)
    table_index = @counters.next('table')
    # Header
    thead = table_el.children.find { |c| c.type == :thead }
    if thead
      thead.children.each_with_index do |tr, r_idx|
        next unless tr.type == :tr
        tr.children.each_with_index do |th, c_idx|
          next unless th.type == :th
          val = InlineRenderer.render_children(th)
          key = sprintf('table_%03d_th_r%02d_c%02d', table_index, r_idx + 1, c_idx + 1)
          @result[key] = normalize(val)
          collect_inline_extras(th)
        end
      end
    end
    # Body
    tbodies = table_el.children.select { |c| c.type == :tbody }
    row_num = 0
    tbodies.each do |tbody|
      tbody.children.each do |tr|
        next unless tr.type == :tr
        row_num += 1
        tr.children.each_with_index do |td, c_idx|
          next unless td.type == :td
          val = InlineRenderer.render_children(td)
          key = sprintf('table_%03d_td_r%02d_c%02d', table_index, row_num, c_idx + 1)
          @result[key] = normalize(val)
          collect_inline_extras(td)
        end
      end
    end
  end
end

# ----- Main -----

pages = ARGV.empty? ? DEFAULT_PAGES : ARGV
FileUtils.mkdir_p(I18N_EN_DIR)

pages.each do |page|
  md_path = File.join(DOCS_DIR, page.end_with?('.md') ? page : "#{page}.md")
  unless File.exist?(md_path)
    warn "[md-extract] Missing source: #{md_path}, skipping"
    next
  end
  content = File.read(md_path, encoding: 'UTF-8')
  # Strip front matter if present (do not include in extraction). We keep only the body here.
  body = if content.start_with?("---\n")
           parts = content.split(/^---\s*$\n/, -1)
           parts.length >= 3 ? parts[2..].join("---\n").lstrip : content
         else
           content
         end

  extractor = Extractor.new(body)
  map = extractor.extract

  yml_path = File.join(I18N_EN_DIR, File.basename(md_path, '.md') + '.yml')
  # Write with stable key order
  File.open(yml_path, 'w', encoding: 'UTF-8') do |f|
    f.write(map.to_yaml)
  end
  puts "[md-extract] Wrote #{yml_path} (#{map.size} keys)"
end
