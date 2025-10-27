#!/usr/bin/env ruby
# frozen_string_literal: true

# Extract translatable strings from Markdown into YAML catalogs and
# compile localized Markdown from locale YAML catalogs.
#
# Usage:
#   ruby scripts/docs_i18n.rb extract   # builds i18n/src/en/*.yml + tokens
#   ruby scripts/docs_i18n.rb compile   # reads i18n/locales/<locale>/*.yml → docs/_i18n/<locale>/*.md
#
# Notes:
# - We protect fragile Markdown constructs in the body (code fences, inline code,
#   links, images) with placeholders so translators don't alter them. The placeholders
#   are restored during compilation.
# - We currently keep front matter intact except for selected string fields (title, description)
#   which we allow overriding via YAML keys if present.

require 'yaml'
require 'json'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
DOCS_DIR = File.join(ROOT, 'docs')
I18N_DIR = File.join(ROOT, 'i18n')
SRC_EN_DIR = File.join(I18N_DIR, 'src', 'en')
TOKENS_DIR = File.join(I18N_DIR, 'tokens')
LOCALES_DIR = File.join(I18N_DIR, 'locales')
OUTPUT_DIR = File.join(DOCS_DIR, '_i18n')

PAGES = %w[index usage adapters configuration]

class MdProtect
  def initialize(text)
    @text = text.dup
    @tokens = {}
    @seq = Hash.new(0)
  end

  # Returns [protected_body, tokens_map]
  def protect
    t = @text
    t = replace_fenced_code(t)
    t = replace_inline_code(t)
    t = replace_images(t)
    t = replace_links(t)
    t = replace_atx_headings(t)
    [t, @tokens]
  end

  def self.unprotect(text, tokens)
    # Replace tokens in reverse insertion order to avoid accidental re-substitution
    # But tokens are unique, so order does not strictly matter.
    out = text.dup
    tokens.each do |k, v|
      out = out.gsub(k, v)
    end
    out
  end

  private

  def next_token(type)
    @seq[type] += 1
    "[[T:#{type}:#{@seq[type]}]]"
  end

  def replace_fenced_code(text)
    text.gsub(/(^```[\w-]*\n[\s\S]*?^```\s*$)/m) do |block|
      tok = next_token('CODE')
      @tokens[tok] = block
      tok
    end
  end

  def replace_inline_code(text)
    text.gsub(/`([^`\n]+)`/) do |m|
      tok = next_token('ICODE')
      @tokens[tok] = m
      tok
    end
  end

  def replace_images(text)
    text.gsub(/!\[[^\]]*\]\([^\)]+\)/) do |m|
      tok = next_token('IMG')
      @tokens[tok] = m
      tok
    end
  end

  def replace_links(text)
    text.gsub(/\[[^\]]+\]\([^\)]+\)/) do |m|
      tok = next_token('LINK')
      @tokens[tok] = m
      tok
    end
  end

  # Protect ATX-style headings by tokenizing only the marker parts (# ... [#])
  # This allows translators to change heading text but not the number of # or spacing.
  # - Supports up to 3 leading spaces before the hashes (per CommonMark)
  # - Supports 1–6 leading # followed by at least one space
  # - Preserves optional trailing # and spaces by placing them into a closing token
  def replace_atx_headings(text)
    lines = text.split("\n", -1)
    lines.map! do |line|
      # indent (0-3 spaces), hashes (1-6), at least one space, inner text (non-greedy), optional trailing spaces/#
      if (m = line.match(/\A(\s{0,3})(\#{1,6})([ \t]+)(.*?)([ \t#]*)\z/))
        indent, hashes, space_after, inner, trail = m.captures
        open_str = "#{indent}#{hashes}#{space_after}"
        tok_open = next_token('HOPEN')
        @tokens[tok_open] = open_str

        tok_close = nil
        if trail && !trail.empty?
          tok_close = next_token('HCLOSE')
          @tokens[tok_close] = trail
        end

        "#{tok_open}#{inner}#{tok_close || ''}"
      else
        line
      end
    end
    lines.join("\n")
  end
end

module Util
  module_function

  # Returns [front_matter_hash_or_nil, body]
  def split_front_matter(content)
    return [nil, content] unless content.start_with?("---\n")
    parts = content.split(/^---\s*$\n/, -1)
    if parts.length >= 3
      fm_yaml = parts[1]
      body = parts[2..].join("---\n").lstrip
      [YAML.safe_load(fm_yaml) || {}, body]
    else
      [nil, content]
    end
  end

  def build_front_matter(hash)
    return "" if hash.nil? || hash.empty?
    "---\n" + hash.to_yaml + "---\n"
  end
end

# Extract English YAML catalogs from Markdown sources
def extract
  FileUtils.mkdir_p(SRC_EN_DIR)
  FileUtils.mkdir_p(TOKENS_DIR)

  PAGES.each do |page|
    md_path = File.join(DOCS_DIR, "#{page}.md")
    unless File.exist?(md_path)
      warn "Skipping missing #{md_path}"
      next
    end

    content = File.read(md_path)
    fm, body = Util.split_front_matter(content)

    protected_body, tokens = MdProtect.new(body).protect

    data = {
      'body' => protected_body
    }
    # Allow translating common front matter strings if present
    %w[title description].each do |k|
      data["fm.#{k}"] = fm[k] if fm && fm[k].is_a?(String) && !fm[k].strip.empty?
    end

    yml_path = File.join(SRC_EN_DIR, "#{page}.yml")
    File.write(yml_path, data.to_yaml)

    # Save tokens per page (shared by all locales)
    File.write(File.join(TOKENS_DIR, "#{page}.tokens.json"), JSON.pretty_generate(tokens))
  end

  puts "Extracted YAML catalogs to #{SRC_EN_DIR} and tokens to #{TOKENS_DIR}"
end

# Compile localized Markdown from YAML catalogs
# For each i18n/locales/<locale>/<page>.yml → docs/_i18n/<locale>/<page>.md
# Falls back to English text if a key is missing.

def compile
  FileUtils.mkdir_p(OUTPUT_DIR)

  # Load English catalogs for fallback
  en_catalogs = {}
  PAGES.each do |page|
    en_path = File.join(SRC_EN_DIR, "#{page}.yml")
    en_catalogs[page] = File.exist?(en_path) ? (YAML.safe_load(File.read(en_path)) || {}) : {}
  end

  # Iterate locales that have at least one page catalog
  locales = Dir.exist?(LOCALES_DIR) ? Dir.children(LOCALES_DIR).select { |d| File.directory?(File.join(LOCALES_DIR, d)) } : []
  locales.each do |locale|
    out_dir = File.join(OUTPUT_DIR, locale)
    FileUtils.mkdir_p(out_dir)

    PAGES.each do |page|
      loc_path = File.join(LOCALES_DIR, locale, "#{page}.yml")
      next unless File.exist?(loc_path)

      cat = YAML.safe_load(File.read(loc_path)) || {}
      fallback = en_catalogs[page] || {}

      # Compose front matter using English as base, overridden by localized fm keys if present
      md_src = File.read(File.join(DOCS_DIR, "#{page}.md"))
      fm_hash, _body_src = Util.split_front_matter(md_src)
      fm_hash ||= {}

      %w[title description].each do |k|
        v = cat["fm.#{k}"]
        fm_hash[k] = v if v.is_a?(String) && !v.strip.empty?
      end

      front = Util.build_front_matter(fm_hash)

      protected_body = (cat['body'] || fallback['body'] || '')

      # Load tokens to unprotect
      tokens_path = File.join(TOKENS_DIR, "#{page}.tokens.json")
      tokens = File.exist?(tokens_path) ? JSON.parse(File.read(tokens_path)) : {}
      body = MdProtect.unprotect(protected_body, tokens)

      File.write(File.join(out_dir, "#{page}.md"), front + body)
    end
  end

  puts "Compiled localized Markdown to #{OUTPUT_DIR}"
end

cmd = ARGV.shift
case cmd
when 'extract'
  extract
when 'compile'
  compile
else
  warn "Unknown command: #{cmd}. Use 'extract' or 'compile'."
  exit 1
end
