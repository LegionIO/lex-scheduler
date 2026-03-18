# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Scheduler do
  describe '.data_required?' do
    it 'returns true' do
      expect(described_class.data_required?).to eq(true)
    end

    it 'is a class method' do
      expect(described_class).to respond_to(:data_required?)
    end
  end

  describe 'VERSION constant' do
    it 'is defined' do
      expect(described_class::VERSION).not_to be_nil
    end

    it 'is a String' do
      expect(described_class::VERSION).to be_a(String)
    end

    it 'follows semver format' do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
