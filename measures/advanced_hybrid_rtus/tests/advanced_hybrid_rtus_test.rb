require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class AdvancedHybridRTUsTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end

  def test_small_office
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallOffice-90.1-2010-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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

    # Ensure the measure N/A as expected
    assert(result.value.valueName == "NA")    
      
  end  
  
  def test_secondary_school
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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

    # Convert the model to energyplus idf
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.osm"), true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{Dir.pwd}/output/SecondarySchool-90.1-2010-ASHRAE 169-2006-4A.idf")
    idf.save(idf_path,true)      
      
  end
 
  def test_primary_school
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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

    # Convert the model to energyplus idf
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.osm"), true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{Dir.pwd}/output/PrimarySchool-90.1-2007-ASHRAE 169-2006-2A.idf")
    idf.save(idf_path,true)      
      
  end

  def test_retail_stripmall
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/RetailStripmall-90.1-2010-ASHRAE 169-2006-2A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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

    # Convert the model to energyplus idf
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/RetailStripmall-90.1-2010-ASHRAE 169-2006-2A.osm"), true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{Dir.pwd}/output/RetailStripmall-90.1-2010-ASHRAE 169-2006-2A.idf")
    idf.save(idf_path,true)      
      
  end  
  
  def test_medium_office
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/MediumOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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

    # Ensure the measure finished NA
    # because the model has no PSZ-AC systems
    assert(result.value.valueName == "NA")      
      
  end

  def test_large_office
     
    # Create an instance of the measure
    measure = AdvancedHybridRTUs.new
    
    # Create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # Create an empty argument map
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new

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
   
    # Convert the model to energyplus idf
    model.save(OpenStudio::Path.new("#{Dir.pwd}/output/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.osm"), true)
    forward_translator = OpenStudio::EnergyPlus::ForwardTranslator.new
    idf = forward_translator.translateModel(model)
    idf_path = OpenStudio::Path.new("#{Dir.pwd}/output/LargeOffice-90.1-2010-ASHRAE 169-2006-5A.idf")
    idf.save(idf_path,true)  
  
  end  
 
end
