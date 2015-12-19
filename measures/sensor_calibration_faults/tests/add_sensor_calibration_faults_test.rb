require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class SensorCalibrationFaults_Test < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = SensorCalibrationFaults.new

    # make an empty model
    model = OpenStudio::Model::Model.new

	# Convert to workspace
	f_trans = OpenStudio::EnergyPlus::ForwardTranslator.new
	workspace = f_trans.translateModel(model)
	
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    assert_equal(1, arguments.size)
  end

  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName, m)
	end
  end
        
  def test_is_not_applicable_to_test_models
  
	["PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("NA", result.value.valueName, m)
	end
  end
        
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the DifferentialDryBulb controlled airside economizer associated with the Controller:Outdoor air object named DOAS OA Controller. The fault availability is scheduled using the 'Always On Discrete' schedule."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the DifferentialDryBulb controlled airside economizer associated with the Controller:Outdoor air object named VAV_bot WITH REHEAT OA Controller. The fault availability is scheduled using the 'Always On Discrete' schedule."})
	refute_nil(result.info.find {|m| m.logMessage == "The Controller:Outdoor air object named DataCenter_top_ZN_6 ZN PSZ Data Center OA Sys Controller has a disabled airside economizer. Economizer sensor faults will not be added."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the DifferentialDryBulb controlled airside economizer associated with the Controller:Outdoor air object named Controller Outdoor Air 2. The fault availability is scheduled using the 'Always On Discrete' schedule."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The Controller:Outdoor air object named Controller Outdoor Air 4 has a disabled airside economizer. Economizer sensor faults will not be added."})
	refute_nil(result.info.find {|m| m.logMessage == "Measure not applicable because the model contains no OutdoorAir:Controller objects with operable economizers."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "To model enthalpy sensor drift, a FaultModel:EnthalpySensorOffset:ReturnAir object with an offset of -2 Btu/lb and a FaultModel:EnthalpySensorOffset:OutdoorAir object with an offset of +2 Btu/lb have been added to the DifferentialEnthalpy controlled airside economizer associated with the Controller:Outdoor air object named PSZ-AC_3-7 OA Sys Controller. The fault availability is scheduled using the 'Always On Discrete' schedule."})
  end
    
  def test_small_hotel_info
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "To model dry bulb sensor drift, a FaultModel:TemperatureSensorOffset:ReturnAir object with an offset of -2 deg F and a FaultModel:TemperatureSensorOffset:OutdoorAir object with an offset of +2 deg F has been added to the DifferentialDryBulb controlled airside economizer associated with the Controller:Outdoor air object named FrontLoungeFlr1 ZN SAC OA Sys Controller. The fault availability is scheduled using the 'Always On Discrete' schedule."})
	refute_nil(result.info.find {|m| m.logMessage == "The Controller:Outdoor air object named MeetingRoomFlr1 ZN SAC OA Sys Controller has a disabled airside economizer. Economizer sensor faults will not be added."})
  end
    
  def test_small_office_info
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The Controller:Outdoor air object named PSZ-AC-2 OA Sys Controller has a disabled airside economizer. Economizer sensor faults will not be added."})
	refute_nil(result.info.find {|m| m.logMessage == "Measure not applicable because the model contains no OutdoorAir:Controller objects with operable economizers."})
  end
    
  def applytotestmodel(model_file)
  
    measure = SensorCalibrationFaults.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/#{model_file}")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Convert to workspace
    f_trans = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = f_trans.translateModel(model)
    
    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

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
    
    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)
    
    return result, model
  end  

end
