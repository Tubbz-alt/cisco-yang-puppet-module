# Copyright (c) 2015 Cisco and/or its affiliates.
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

require_relative '../../../util/node_util' if Puppet.features.node_util?
require_relative '../../../util/yang_accessor' if Puppet.features.node_util?

Puppet::Type.type(:cisco_yang).provide(:cisco) do
  desc 'IOS-XR configuration management via YANG.'
  defaultfor operatingsystem: [:ios_xr]

  confine feature: :json
  confine feature: :node_util

  def initialize(value={})
    super(value)
    @node = Cisco::Node.instance(Cisco::Client::GRPC)
    debug 'Created provider instance of cisco_yang.'
  end

  def exists?
    activate
    source && source != :absent
  end

  def create
    setyang(@resource[:source])
  end

  def destroy
    @source = nil # clear the cached value
    src = @resource[:source] || @resource[:target]
    debug '**************** REMOVING CONFIG ****************'
    @node.delete_yang(src)
    debug '**************** REMOVE SUCCESSFUL ****************'
  end

  def resource_mode
    @resource && @resource[:mode] == :replace ? :replace : :merge
  end

  def resource_force
    @resource && @resource[:force] ? true : false
  end

  # Return the current source YANG
  def source
    return @source if @source # return the cached value, if it's there

    if resource_force
      # If instructed to force the configuration, then there is no reason
      # to query the current configuration; just return :unknown.
      source_yang = :unknown
    else
      source_yang = @node.get_yang(@resource[:target])

      debug '**************** CURRENT CONFIG ****************'
      debug source_yang

      source_yang = :absent if !source_yang || source_yang.empty?
    end

    @source = source_yang
  rescue StandardError => e
    unless e.message =~ /unknown-namespace/ ||
           e.message =~ /not recognized or supported/
      raise
    end
    error e.message
    @source = nil
  end

  # Set the source YANG.
  def source=(value)
    setyang(value)
  end

  def setyang(value)
    @source = nil # clear the cached value
    debug '**************** SETTING CONFIG ****************'
    debug "Value: #{value}"
    debug "Resource Mode #{resource_mode}"
    if resource_mode == :replace
      @node.replace_yang(value)
    else
      @node.merge_yang(value)
    end
    debug '**************** SET SUCCESSFUL ****************'
  end

  def self.instances
    ya = Cisco::YangAccessor.new
    targets = ya.targets(client_class: Cisco::Client::GRPC)

    targets.map do |target|
      new(name: target)
    end
  end

  def activate
    @active = true
  end

  def active?
    !@active.nil?
  end
end
