# frozen_string_literal: true

require "test_helper"

class GtfsTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::GtfsData::VERSION
  end

  def test_it_does_something_useful
    assert false
  end
end
