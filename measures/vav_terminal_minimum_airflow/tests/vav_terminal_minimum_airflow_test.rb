require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class VAVTerminalMinimumAirflowTest < MiniTest::Unit::TestCase


 
def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = VAVTerminalMinimumAirflow.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end


  
  def test_min_flow_rate_mediumOffice
   
    result, model = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Minimum Airflow rate for Single duct VAV with reheat named 'Perimeter_mid_ZN_1 ZN VAV Term' with area 2,231.77 sqft, & zone minimum air flow input method as 'Constant' =  0.70 has been changed to a minimum fixed flow rate of 892.71 cfm.")
	assert_equal("Success", result.value.valueName)
	
  end
  
  def test_min_flow_rate_largeOffice
   
    result, model = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Minimum Airflow rate for Single duct VAV with reheat named 'Perimeter_bot_ZN_2 ZN VAV Term' with area 2,174.04 sqft, & zone minimum air flow input method as 'Constant' =  0.71 has been changed to a minimum fixed flow rate of 869.62 cfm.")
	assert_equal("Success", result.value.valueName)
	
  end
  
  def test_min_flow_rate_primaryschool
   
    result, model = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Minimum Airflow rate for Single duct VAV with reheat named 'Corner_Class_1_Pod_1_ZN_1_FLR_1 ZN VAV Term' with area 1,065.63 sqft, & zone minimum air flow input method as 'Constant' =  0.70 has been changed to a minimum fixed flow rate of 426.25 cfm.")
	assert_equal("Success", result.value.valueName)
	
  end
  
  def test_min_flow_rate_secschool
   
    result, model = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Minimum Airflow rate for Single duct VAV with reheat named 'Corner_Class_1_Pod_3_ZN_1_FLR_1 ZN VAV Term' with area 1,065.63 sqft, & zone minimum air flow input method as 'Constant' =  0.70 has been changed to a minimum fixed flow rate of 426.25 cfm.")
	assert_equal("Success", result.value.valueName)
	
  end
  
  def test_min_flow_rate_largehotel
   
    result, model = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "Minimum Airflow rate for Single duct VAV with reheat named 'Basement ZN VAV Term' with area 21,299.95 sqft, & zone minimum air flow input method as 'Constant' =  0.69 has been changed to a minimum fixed flow rate of 8,519.98 cfm.")
	assert_equal("Success", result.value.valueName)
	
  end
  
  def test_min_flow_rate_smalloffice
   
    result, model = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "The building contains no qualified single duct VAV objects. Measure is not applicable.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def test_min_flow_rate_smallhotel
   
    result, model = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
    assert(result.warnings.size == 0)
	assert_equal(result.info.first.logMessage, "The building contains no qualified single duct VAV objects. Measure is not applicable.")
	assert_equal("NA", result.value.valueName)
	
  end
  
  def applytotestmodel(model_file)
  
  measure = VAVTerminalMinimumAirflow.new

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

