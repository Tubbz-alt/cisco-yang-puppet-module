###############################################################################
# Copyright (c) 2016 Cisco and/or its affiliates.
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
###############################################################################
require File.expand_path('../../../../lib/utilitylib.rb', __FILE__)
require File.expand_path('../../../../lib/yang_util.rb', __FILE__)

# Test hash top-level keys
tests = {
  master:        master,
  agent:         agent,
  resource_name: 'cisco_yang',
  os:            'ios_xr',
  os_version:    '6.1.1',
}

# skip entire file if os, version, etc. don't match
skip_unless_supported(tests)

# define a test (or tests)
# (e.g. description, title, manifest)
tests[:vrf_groups] = {
  desc:           'Configure VRFs',
  title:          '{"Cisco-IOS-XR-infra-rsi-cfg:vrf-groups": [null]}',
  manifest_props: {
    source: '
      {"Cisco-IOS-XR-infra-rsi-cfg:vrf-groups":
        {
          "vrf-group": [
            {
              "vrf-group-name": "TEST-GROUP",
              "enable": [null],
              "vrfs": {
                "vrf": [
                  {
                    "vrf-name": "ORANGE"
                  }
                ]
              }
            }
          ]
        }
      }',
    mode:   'replace',
  },
}

#################################################################
# Execute the test
#################################################################

test_name 'Model Test' do
  # a simple run with pre/post clean
  # (reference our test above using the key)
  test_harness_run_clean(tests, :vrf_groups)
end

# report on skipped tests
skipped_tests_summary(tests)
