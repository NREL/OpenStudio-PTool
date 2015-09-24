require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class LowerMinimumAirflowRatesForVAVTerminalTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  
 
  def test_run_measure
    # create an instance of the measure
    measure = LowerMinimumAirflowRatesForVAVTerminal.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get


    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)



    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal("Success", result.value.valueName)
	# assert(result.info.size == 1)
	# assert(result.warnings.size == 0)


    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.osm")
    model.save(output_file_path,true)
  end

end
