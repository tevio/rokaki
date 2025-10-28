# frozen_string_literal: true
require 'spec_helper'

RSpec.shared_examples "FilterModel::InequalityFilters" do |selected_db|
  describe 'inequality and nullability filters (top-level and nested)' do
    let!(:a1_auth) { Author.create!(first_name: 'Ada',  last_name: 'Lovelace') }
    let!(:a2_auth) { Author.create!(first_name: 'Alan', last_name: 'Turing') }

    let!(:a1) { Article.create!(title: 'One',   content: 'alpha', published: Time.utc(2024,1,1,12),  author: a1_auth) }
    let!(:a2) { Article.create!(title: 'Two',   content: 'beta',  published: Time.utc(2024,6,1,12),  author: a1_auth) }
    let!(:a3) { Article.create!(title: 'Three', content: nil,     published: Time.utc(2024,12,1,12), author: a2_auth) }

    let(:klass) do
      Class.new do
        include Rokaki::FilterModel
        filter_key_prefix :__
        filter_model :article, db: selected_db
        filter_map do
          filters :title, :content, :published
          nested :author do
            filters :first_name
          end
        end
        attr_accessor :filters
        def initialize(filters: {}) ; @filters = filters ; end
      end
    end

    it 'supports neq' do
      res = klass.new(filters: { title: { neq: 'One' } }).results
      expect(res).to include(a2, a3)
      expect(res).not_to include(a1)
    end

    it 'supports not_in' do
      res = klass.new(filters: { title: { not_in: ['One', 'Three'] } }).results
      expect(res).to include(a2)
      expect(res).not_to include(a1, a3)
    end

    it 'supports is_null' do
      res = klass.new(filters: { content: { is_null: true } }).results
      expect(res).to include(a3)
      expect(res).not_to include(a1, a2)
    end

    it 'supports is_not_null' do
      res = klass.new(filters: { content: { is_not_null: true } }).results
      expect(res).to include(a1, a2)
      expect(res).not_to include(a3)
    end

    it 'supports gt/gte' do
      cutoff = Time.utc(2024,3,1,0)
      res_gt  = klass.new(filters: { published: { gt: cutoff } }).results
      res_gte = klass.new(filters: { published: { gte: cutoff } }).results
      expect(res_gt).to include(a2, a3)
      expect(res_gt).not_to include(a1)
      expect(res_gte).to include(a2, a3)
      expect(res_gte).not_to include(a1)
    end

    it 'supports lt/lte' do
      cutoff = Time.utc(2024,6,1,12)
      res_lt  = klass.new(filters: { published: { lt: cutoff } }).results
      res_lte = klass.new(filters: { published: { lte: cutoff } }).results
      expect(res_lt).to include(a1)
      expect(res_lt).not_to include(a2, a3)
      expect(res_lte).to include(a1, a2)
      expect(res_lte).not_to include(a3)
    end

    it 'supports nested neq on author.first_name' do
      res = klass.new(filters: { author: { first_name: { neq: 'Ada' } } }).results
      expect(res).to include(a3)
      expect(res).not_to include(a1, a2)
    end
  end
end
