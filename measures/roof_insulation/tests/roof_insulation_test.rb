require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class RoofInsulation_Test < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  def test_RoofInsulation_NewConstruction_FullyCosted

    # create an instance of the measure
    measure = RoofInsulation.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "run_measure" => 1,
    "r_value" => 50.0
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val),"Could not set '#{name}' to '#{val}'.")
      argument_map[name] = arg
      i += 1
    end

    # test initial model conditions    
    surface1_found = false
    surface2_found = false
    model.getSurfaces.each do |surface|
      if surface.name.get == "Surface 20"
        surface1_found = true
        construction = surface.construction #should use "ASHRAE_189.1-2009_ExtWall_Mass_ClimateZone_alt-res 5"
        assert((not construction.empty?))
        construction = construction.get.to_Construction
        assert((not construction.empty?))
        assert(construction.get.layers.size == 4)
        assert(construction.get.layers[2].name.get == "Wall Insulation [42]")
        assert(construction.get.layers[2].thickness == 0.091400)

      elsif surface.name.get == "Surface 14"
        # this is the one that doesnt get changed
        surface2_found = true
        construction = surface.construction #should use "Test_No Insulation"
        assert((not construction.empty?))
        construction = construction.get.to_Construction
        assert((not construction.empty?))
        assert(construction.get.layers.size == 3)
        assert(construction.get.layers[0].name.get == "000_M01 100mm brick")
        assert(construction.get.layers[1].name.get == "8IN CONCRETE HW_RefBldg")
        assert(construction.get.layers[2].name.get == "1/2IN Gypsum")
      end
    end
    assert(surface1_found)
    assert(surface2_found)

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result) #this displays the output when you run the test
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)

    # test final model conditions

    # loop over info warnings

    # loop over warnings

  end

  def test_IncreaseInsulationRValueForExteriorWalls_EmptySpaceNoLoadsOrSurfaces

    # create an instance of the measure
    measure = RoofInsulation.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # add a space to the model without any geometry or loads, want to make sure measure works or fails gracefully
    new_space = OpenStudio::Model::Space.new(model)

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

    # Set argument values
    arg_values = {
    "run_measure" => 1,
    "r_value" => 50.0
    }
    
    i = 0
    arg_values.each do |name, val|
      arg = arguments[i].clone
      assert(arg.setValue(val),"Could not set '#{name}' to '#{val}'.")
      argument_map[name] = arg
      i += 1
    end

    measure.run(model, runner, argument_map)
    result = runner.result
    #show_output(result) #this displays the output when you run the test
    assert(result.value.valueName == "NA")
    assert(result.info.size == 1)
    assert(result.warnings.size == 0)

  end

end