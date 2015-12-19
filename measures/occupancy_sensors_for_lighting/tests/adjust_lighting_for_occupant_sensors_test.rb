require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class OccupancySensorsForLighting_Test < MiniTest::Unit::TestCase

  def test_OccupancySensorsForLighting

    # Create an instance of the measure
    measure = OccupancySensorsForLighting.new

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
    arguments = measure.arguments(model)
    
    # Set argument values
    arg_values = {
    "run_measure" => 1
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val))
      argument_map[name] = arg
      i += 1
    end    
    
    # Run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")

  end

end
