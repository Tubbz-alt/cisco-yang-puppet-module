#!/usr/bin/env ruby
#
# January 2016, Glenn F. Matthews
#
# Copyright (c) 2015-2016 Cisco and/or its affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative '../constants'
require_relative '../logger'

# Utility methods for clients of various RPC formats
class Cisco::Client
  # Make a best effort to convert a given input value to an Array.
  # Strings are split by newlines, and nil becomes an empty Array.
  def self.munge_to_array(val)
    val = [] if val.nil?
    val = val.split("\n") if val.is_a?(String)
    val
  end

  def munge_to_array(val)
    self.class.munge_to_array(val)
  end

  # Helper function that subclasses may use with get(data_format: :cli)
  # Method for working with hierarchical show command output such as
  # "show running-config". Searches the given multi-line string
  # for all matches to the given value query. If context is provided,
  # the matches will be filtered to only those that are located "under"
  # the given context sequence (as determined by indentation).
  #
  # @param cli_output [String] The body of text to search
  # @param context [*Regex] zero or more regular expressions defining
  #                the parent configs to filter by.
  # @param value [Regex] The regular expression to match
  # @return [[String], nil] array of matching (sub)strings, else nil.
  #
  # @example Find all OSPF router names in the running-config
  #   ospf_names = filter_cli(cli_output: running_cfg,
  #                           value:      /^router ospf (\d+)/)
  #
  # @example Find all address-family types under the given BGP router
  #   bgp_afs = filter_cli(cli_output: show_run_bgp,
  #                        context:    [/^router bgp #{ASN}/],
  #                        value:      /^address-family (.*)/)
  def self.filter_cli(cli_output: nil,
                      context:    nil,
                      value:      nil)
    return cli_output if cli_output.nil?
    context ||= []
    context.each { |filter| cli_output = find_subconfig(cli_output, filter) }
    return nil if cli_output.nil? || cli_output.empty?
    return cli_output if value.nil?
    value = to_regexp(value)
    match = cli_output.scan(value)
    return nil if match.empty?
    # find matches and return as array of String if it only does one match.
    # Otherwise return array of array.
    match.flatten! if match[0].is_a?(Array) && match[0].length == 1
    match
  end

  # Returns the subsection associated with the given
  # line of config
  # @param [String] the body of text to search
  # @param [Regex] the regex key of the config for which
  # to retrieve the subsection
  # @return [String, nil] the subsection of body, de-indented
  # appropriately, or nil if no such subsection exists.
  def self.find_subconfig(body, regexp_query)
    return nil if body.nil? || regexp_query.nil?
    regexp_query = to_regexp(regexp_query)

    rows = body.split("\n")
    match_row_index = rows.index { |row| regexp_query =~ row }
    return nil if match_row_index.nil?

    cur = match_row_index + 1
    subconfig = []

    until (/\A\s+.*/ =~ rows[cur]).nil? || cur == rows.length
      subconfig << rows[cur]
      cur += 1
    end
    return nil if subconfig.empty?
    # Strip an appropriate minimal amount of leading whitespace from
    # all lines in the subconfig
    min_leading = subconfig.map { |line| line[/\A */].size }.min
    subconfig = subconfig.map { |line| line[min_leading..-1] }
    subconfig.join("\n")
  end

  # Helper method for CLI getters
  #
  # Convert a string or array of strings to a Regexp or array thereof
  def self.to_regexp(input)
    if input.is_a?(Regexp)
      return input
    elsif input.is_a?(Array)
      return input.map { |item| to_regexp(item) }
    else
      # The string might be explicitly formatted as a regexp
      if input[0] == '/' && input[-1] == '/'
        # '/foo/' => %r{foo}
        return Regexp.new(input[1..-2])
      elsif input[0] == '/' && input[-2..-1] == '/i'
        # '/foo/i' => %r{foo}i
        return Regexp.new(input[1..-3], Regexp::IGNORECASE)
      else
        # 'foo' => %r{^foo$}i
        return Regexp.new("^#{input}$", Regexp::IGNORECASE)
      end
    end
  end

  # Helper method for calls into third-party code - suppresses Ruby warnings
  # for the given block since we have no control over that code.
  def self.silence_warnings(&block)
    warn_level = $VERBOSE
    $VERBOSE = nil
    result = block.call
    $VERBOSE = warn_level
    result
  end
end
