require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ExteriorLightingControlsTest < MiniTest::Unit::TestCase

  def test_ExteriorLightingControl

    # Create an instance of the measure
    measure = ExteriorLightingControl.new

    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SecondarySchool-DOE Ref 1980-2004-ASHRAE 169-2006-3B.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Create an empty argument map (this measure has no arguments)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")

    # ensure that all objects were changed #TODO
#    assert(ext_ltg_count == ext_ltg_changed)
#    assert_equal(ext_ltg_count, ext_ltg_changed)

  end

end
