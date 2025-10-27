#!/usr/bin/env ruby
# frozen_string_literal: true

# Tokenize Markdown for safe translation and reconstruct after pull.
#
# Usage:
#   ruby scripts/phrase_md_tokenizer.rb generate   # builds .phrase_sources/*.txt + mappings
#   ruby scripts/phrase_md_tokenizer.rb apply      # detokenizes docs/_i18n/<locale>/*.md in place
#
# Strategy:
# - We strip front matter from sources and protect fragile Markdown constructs via tokens:
#   - fenced code blocks ```...```
#   - inline code `...`
#   - images ![...](...)
#   - links  [...](...)
# - We push tokenized .txt to Phrase (see .phrase.yml push sources).
# - After pulling translations into docs/_i18n/<locale>/*.md, we replace tokens with the original
#   constructs and reattach the original front matter so Jekyll can render normally.

require 'json'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
DOCS = File.join(ROOT, 'docs')
PHRASE_SOURCES_DIR = File.join(ROOT, '.phrase_sources')
MAPPINGS_DIR = File.join(PHRASE_SOURCES_DIR, 'mappings')
LOCALES_DIR = File.join(DOCS, '_i18n')

PAGES = %w[index usage adapters configuration]

class Tokenizer
  Token = Struct.new(:type, :value)

  def initialize(markdown)
    @markdown = markdown.dup
    @tokens = {}
    @seq = Hash.new(0)
  end

  def tokenize
    body, front_matter = extract_front_matter(@markdown)

    # Order matters: fence -> inline code -> images -> links
    body = replace_fenced_code(body)
    body = replace_inline_code(body)
    body = replace_images(body)
    body = replace_links(body)

    return body, front_matter, @tokens
  end

  private

  def next_token(type)
    @seq[type] += 1
    "[[T:#{type}:#{@seq[type]}]]"
  end

  def extract_front_matter(content)
    return [content, nil] unless content.start_with?("---\n")
    parts = content.split(/^---\s*$\n/, -1) # split on lines with just '---'
    # parts[0] is empty before the first '---' line
    # parts[1] is front matter, parts[2..] joined is body
    if parts.length >= 3
      front = parts[1]
      body = parts[2..].join("---\n")
      [body.lstrip, "---\n#{front}---\n"]
    else
      [content, nil]
    end
  end

  def replace_fenced_code(text)
    # Match triple backtick code fences including language; non-greedy
    text.gsub(/(^```[\w-]*\n[\s\S]*?^```\s*$)/m) do |block|
      tok = next_token('CODE')
      @tokens[tok] = block
      tok
    end
  end

  def replace_inline_code(text)
    # Avoid crossing lines; simple backtick groups
    text.gsub(/`([^`\n]+)`/) do |m|
      tok = next_token('ICODE')
      @tokens[tok] = m
      tok
    end
  end

  def replace_images(text)
    # ![alt](url)
    text.gsub(/!\[[^\]]*\]\([^\)]+\)/) do |m|
      tok = next_token('IMG')
      @tokens[tok] = m
      tok
    end
  end

  def replace_links(text)
    # [text](url) — do this after images so we don't catch starts with '!'
    text.gsub(/\[[^\]]+\]\([^\)]+\)/) do |m|
      tok = next_token('LINK')
      @tokens[tok] = m
      tok
    end
  end
end

class Detokenizer
  def initialize(body, tokens)
    @body = body.dup
    @tokens = tokens
  end

  def apply
    # Replace longer tokens first (defensive, though all tokens same length pattern)
    @tokens.keys.sort_by { |k| -k.length }.each do |tok|
      @body.gsub!(tok, @tokens[tok])
    end
    @body
  end
end


def generate_sources
  FileUtils.mkdir_p(PHRASE_SOURCES_DIR)
  FileUtils.mkdir_p(MAPPINGS_DIR)

  PAGES.each do |page|
    src_path = File.join(DOCS, "#{page}.md")
    unless File.exist?(src_path)
      warn "Missing source: #{src_path}, skipping"
      next
    end

    content = File.read(src_path, encoding: 'UTF-8')
    tokenizer = Tokenizer.new(content)
    tokenized_body, front_matter, tokens = tokenizer.tokenize

    # Save tokenized body as .txt for Phrase push
    out_txt = File.join(PHRASE_SOURCES_DIR, "#{page}.txt")
    File.write(out_txt, tokenized_body, mode: 'w', encoding: 'UTF-8')

    # Save mapping (front matter + tokens)
    map_path = File.join(MAPPINGS_DIR, "#{page}.json")
    map_obj = { 'front_matter' => front_matter, 'tokens' => tokens }
    File.write(map_path, JSON.pretty_generate(map_obj), mode: 'w', encoding: 'UTF-8')

    puts "Generated #{out_txt} and mapping #{map_path}"
  end
end


def detokenize_locales
  unless Dir.exist?(LOCALES_DIR)
    warn "No locales directory at #{LOCALES_DIR}; nothing to detokenize"
    return
  end

  Dir.children(LOCALES_DIR).each do |locale|
    locale_dir = File.join(LOCALES_DIR, locale)
    next unless File.directory?(locale_dir)

    PAGES.each do |page|
      map_path = File.join(MAPPINGS_DIR, "#{page}.json")
      unless File.exist?(map_path)
        warn "Mapping not found for #{page} at #{map_path}; skip detokenize for this page"
        next
      end

      target_md = File.join(locale_dir, "#{page}.md")
      next unless File.exist?(target_md)

      map = JSON.parse(File.read(map_path, encoding: 'UTF-8'))
      front = map['front_matter']
      tokens = map['tokens'] || {}

      body_translated = File.read(target_md, encoding: 'UTF-8')
      detok = Detokenizer.new(body_translated, tokens).apply

      final = String.new
      final << front if front
      final << detok

      File.write(target_md, final, mode: 'w', encoding: 'UTF-8')
      puts "Detokenized #{target_md}"
    end
  end
end

cmd = ARGV[0]
case cmd
when 'generate'
  generate_sources
when 'apply'
  detokenize_locales
else
  warn "Unknown command: #{cmd}\nUsage: ruby scripts/phrase_md_tokenizer.rb [generate|apply]"
  exit 1
end
