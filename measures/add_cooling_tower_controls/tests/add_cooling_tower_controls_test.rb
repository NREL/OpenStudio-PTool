require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AddCoolingTowerControlsTest < MiniTest::Unit::TestCase

 def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = AddCoolingTowerControls.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_min_flow_rate_largeOffice
   
    result, model = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "This measure is not applicable. All existing cooling tower objects in the model are all already configured for variable airflow operation.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_largehotel
   
    result, model = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_secschool
   
    result, model = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_primaryschool
   
    result, model = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_smalloffice
   
    result, model = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_mediumoffice
   
    result, model = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_smallhotel
   
    result, model = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Model does not contain any plantloops where Loop Type = Condenser. This measure will not alter the model.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def applytotestmodel(model_file)
  
  measure = AddCoolingTowerControls.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
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


  
  return result, model
  end  
  
end
