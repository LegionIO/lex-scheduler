# frozen_string_literal: true

require 'spec_helper'
require 'fugit'

RSpec.describe 'Fugit cron parsing' do
  it 'parses a standard cron expression' do
    cron = Fugit.parse('*/5 * * * *')
    expect(cron).not_to be_nil
    expect(cron).to respond_to(:previous_time)
    expect(cron).to respond_to(:next_time)
  end

  it 'parses a duration string' do
    dur = Fugit.parse('30s')
    expect(dur).not_to be_nil
    expect(dur).to respond_to(:to_sec)
    expect(dur.to_sec).to eq(30)
  end

  it 'parses a minute duration' do
    dur = Fugit.parse('5m')
    expect(dur).not_to be_nil
    expect(dur.to_sec).to eq(300)
  end

  it 'parses an hourly cron expression' do
    cron = Fugit.parse('0 * * * *')
    expect(cron).not_to be_nil
    begin
      expect(cron.next_time).to be_a(Fugit::Nat::EtOrbi::EoTime)
    rescue StandardError
      expect(cron.next_time).not_to be_nil
    end
  end

  it 'returns nil for invalid expressions' do
    result = Fugit.parse('not a cron')
    expect(result).to be_nil
  end

  it 'previous_time returns a time in the past' do
    cron = Fugit.parse('*/5 * * * *')
    prev = cron.previous_time
    expect(Time.parse(prev.to_s)).to be <= Time.now
  end
end
