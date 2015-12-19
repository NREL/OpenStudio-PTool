require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class CloseOutdoorAirDamperDuringUnoccupiedPeriodsTest < MiniTest::Unit::TestCase

  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = CloseOutdoorAirDamperDuringUnoccupiedPeriods.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
  end

  # This measure is applicable to all models
  def test_is_applicable_to_test_models
  
	["LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm", "MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm", "PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm", "SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm", "SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm"].each do |m|
		result,_ = applytotestmodel(m)
		assert_equal("Success", result.value.valueName)
	end
  end
    
  def test_large_hotel_info
	result,_ = applytotestmodel("LargeHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named VAV WITH REHEAT has an outdoor air controller named VAV WITH REHEAT OA Controller. The minimum outdoor air schedule name of HotelLarge MinOA_MotorizedDamper_Sched has been replaced with a new schedule named VAV WITH REHEAT Occ Sch."})
	refute_nil(result.info.find {|m| m.logMessage == "No outdoor air schedule was associated with the Zone HVAC Equipment 4-Pipe FCU object named Room_1_Flr_3 ZNFCU. A new schedule named Room_1_Flr_3 ZN Occ Sch has been assigned representing closing the outdoor air damper when less than 5 percent of peak people are present in the thermal zone."})
  end
    
  def test_large_office_info
	result,_ = applytotestmodel("LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named DataCenter_top_ZN_6 ZN PSZ Data Center has an outdoor air controller named DataCenter_top_ZN_6 ZN PSZ Data Center OA Sys Controller. The minimum outdoor air schedule name of OfficeLarge MinOA_MotorizedDamper_Sched has been replaced with a new schedule named DataCenter_top_ZN_6 ZN PSZ Data Center Occ Sch."})
  end
    
  def test_medium_office_info
	result,_ = applytotestmodel("MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named 5 Zone PVAV 1 has an outdoor air controller named Controller Outdoor Air 2. The minimum outdoor air schedule name of OfficeMedium MinOA_MotorizedDamper_Sched has been replaced with a new schedule named 5 Zone PVAV 1 Occ Sch."})
  end
    
  def test_primary_school_info
	result,_ = applytotestmodel("PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named PVAV_POD_1 has an outdoor air controller named Controller Outdoor Air 1. The minimum outdoor air schedule name of SchoolPrimary MinOA_MotorizedDamper_Sched has been replaced with a new schedule named PVAV_POD_1 Occ Sch."})
  end
  
  def test_secondary_school_info
	result,_ = applytotestmodel("SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named VAV_POD_3 has an outdoor air controller named VAV_POD_3 OA Controller. The minimum outdoor air schedule name of SchoolSecondary MinOA_MotorizedDamper_Sched has been replaced with a new schedule named VAV_POD_3 Occ Sch."})
  end
    
  def test_small_hotel_info_and_warning
	result,_ = applytotestmodel("SmallHotel-90.1-2010-ASHRAE 169-2006-3B.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named FrontLoungeFlr1 ZN SAC has an outdoor air controller named FrontLoungeFlr1 ZN SAC OA Sys Controller. The minimum outdoor air schedule name of SmallHotel Split-AC OA Damper has been replaced with a new schedule named FrontLoungeFlr1 ZN SAC Occ Sch."})
	refute_nil(result.warnings.find {|m| m.logMessage == "Any outside air damper controls associated with the Zone HVAC Equipment PTAC object named CorridorFlr1 ZN PTAC serving the thermal zone named CorridorFlr1 ZN are fixed position dampers and cannot be changed."})
  end
    
  def test_small_office_info_and_warning
	result,_ = applytotestmodel("SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
	refute_nil(result.info.find {|m| m.logMessage == "The airloop named PSZ-AC-4 has an outdoor air controller named PSZ-AC-4 OA Sys Controller. The minimum outdoor air schedule name of OfficeSmall MinOA_MotorizedDamper_Sched has been replaced with a new schedule named PSZ-AC-4 Occ Sch."})
	refute_nil(result.warnings.find {|m| m.logMessage == "Any outside air damper controls associated with the Zone HVAC Equipment PTHP object named PTHP serving the thermal zone named Core_ZN ZN are fixed position dampers and cannot be changed."})
  end
    
  def applytotestmodel(model_file)
  
	measure = CloseOutdoorAirDamperDuringUnoccupiedPeriods.new

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
