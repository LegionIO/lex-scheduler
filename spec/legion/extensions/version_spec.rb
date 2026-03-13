# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Scheduler do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  it 'version is a string' do
    expect(described_class::VERSION).to be_a(String)
  end
end
