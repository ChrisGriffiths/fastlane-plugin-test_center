require 'plist'

module Fastlane
  module Actions
    class TestsFromXctestrunAction < Action
      def self.run(params)
        UI.verbose("Getting tests from xctestrun file at '#{params[:xctestrun]}'")
        return xctestrun_tests(params[:xctestrun])
      end

      def self.xctestrun_tests(xctestrun_path)
        xctestrun = Plist.parse_xml(xctestrun_path)
        xctestrun_rootpath = File.dirname(xctestrun_path)
        tests = Hash.new([])
        xctestrun.each do |testable_name, xctestrun_config|
          next if testable_name == '__xctestrun_metadata__'

          test_identifiers = XCTestList.tests(xctest_bundle_path(xctestrun_rootpath, xctestrun_config))
          test_identifiers_string = test_identifiers.join("\n\t")
          UI.verbose("Found the following tests: #{test_identifiers_string}")
          if xctestrun_config.key?('SkipTestIdentifiers')
            skipped_tests_string = xctestrun_config['SkipTestIdentifiers'].join("\n\t")
            UI.verbose("Removing skipped tests: #{skipped_tests_string}")
            test_identifiers.reject! { |test_identifier| xctestrun_config['SkipTestIdentifiers'].include?(test_identifier) }
          end
          tests[testable_name] = test_identifiers.map do |test_identifier|
            "#{testable_name.shellescape}/#{test_identifier}"
          end
        end
        tests
      end

      def self.xctest_bundle_path(xctestrun_rootpath, xctestrun_config)
        xctest_host_path = xctestrun_config['TestHostPath'].sub('__TESTROOT__', xctestrun_rootpath)
        xctestrun_config['TestBundlePath'].sub('__TESTHOST__', xctest_host_path).sub('__TESTROOT__', xctestrun_rootpath)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Retrieves all of the tests from xctest bundles referenced by the xctestrun file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :xctestrun,
            env_name: "FL_SUPPRESS_TESTS_FROM_XCTESTRUN_FILE",
            description: "The xctestrun file to use to find where the xctest bundle file is for test retrieval",
            verify_block: proc do |path|
              UI.user_error!("Error: cannot find the xctestrun file '#{path}'") unless File.exist?(path)
            end
          )
        ]
      end

      def self.return_value
        "A Hash of testable => tests, where testable is the name of the test target and tests is an array of test identifiers"
      end

      def self.example_code
        [
          "
          require 'fastlane/actions/scan'

          UI.important(
            'example: ' \\
            'get list of tests that are referenced from an xctestrun file'
          )
          # build the tests so that we have a xctestrun file to parse
          scan(
            build_for_testing: true,
            workspace: File.absolute_path('../AtomicBoy/AtomicBoy.xcworkspace'),
            scheme: 'AtomicBoy'
          )

          # find the xctestrun file
          derived_data_path = Scan.config[:derived_data_path]
          xctestrun_file = Dir.glob(\"\#{derived_data_path}/Build/Products/*.xctestrun\").first

          # get the tests from the xctestrun file
          tests = tests_from_xctestrun(xctestrun: xctestrun_file)
          UI.header('xctestrun file contains the following tests')
          tests.values.flatten.each { |test_identifier| puts test_identifier }
          "
        ]
      end

      def self.authors
        ["lyndsey-ferguson/lyndseydf"]
      end

      def self.category
        :testing
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end
    end
  end
end
