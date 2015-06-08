#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class AdvancedRTUControlsEplus < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AdvancedRTUControlsEplus"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
     
    ems_path = '../AdvancedRTUControls/ems_advanced_rtu_controls.ems'
    json_path = '../AdvancedRTUControls/ems_results.json'
    if File.exist? ems_path
      ems_string = File.read(ems_path)
      json = JSON.parse(File.read(json_path))
    else
      ems_path2 = Dir.glob('../../*/ems_advanced_rtu_controls.ems')
      ems_path1 = ems_path2[0]
      json_path2 = Dir.glob('../../*/ems_results.json')
      json_path1 = json_path2[0]
      if ems_path2.size > 1
        runner.registerWarning("more than one ems_advanced_rtu_controls.ems file found.  Using first one found.")
      end
      if !ems_path1.nil? 
        if File.exist? ems_path1
          ems_string = File.read(ems_path1)
          json = JSON.parse(File.read(json_path))
        else
          runner.registerError("ems_advanced_rtu_controls.ems file not located")
        end  
      else
        runner.registerError("ems_advanced_rtu_controls.ems file not located")    
      end
    end

    ##testing code
    # ems_string1 = "EnergyManagementSystem:Actuator,
    # PSZ0_FanPressure, ! Name 
    # Perimeter_ZN_4 ZN PSZ-AC Fan, ! Actuated Component Unique Name
    # Fan, ! Actuated Component Type
    # Fan Pressure Rise; ! Actuated Component Control Type"
    
    # idf_file1 = OpenStudio::IdfFile::load(ems_string1, 'EnergyPlus'.to_IddFileType).get
    # runner.registerInfo("Adding test EMS code to workspace")
    # workspace.addObjects(idf_file1.objects)
    
    #get all emsActuators in model to test if there is an EMS conflict
    emsActuator = workspace.getObjectsByType("EnergyManagementSystem:Actuator".to_IddObjectType)

    if emsActuator.size == 0
      runner.registerInfo("The model does not contain any emsActuators, continuing")
    else
      runner.registerInfo("The model contains #{emsActuator.size} emsActuators, checking if any are attached to Fans.")
      emsActuator.each_with_index do |emsActuatorObject|
        emsActuatorObject_name =  emsActuatorObject.getString(1).to_s # Name
        runner.registerInfo("EMS string: #{emsActuatorObject_name}")
        json.each do |js|
          if (emsActuatorObject_name.eql? js[1]["fan"].to_s) && (emsActuatorObject.getString(2).to_s.eql? "Fan") && (emsActuatorObject.getString(3).to_s.eql? "Fan Pressure Rise")
            runner.registerInfo("Actuated Component Unique Name: #{emsActuatorObject.getString(1).to_s}")
            runner.registerInfo("Actuated Component Type: #{emsActuatorObject.getString(2).to_s}")
            runner.registerInfo("Actuated Component Control Type: #{emsActuatorObject.getString(3).to_s}")
            runner.registerInfo("EMS control logic modifying fan pressure rise  already exists in the model. EEM not applied")
            runner.registerAsNotApplicable("EMS control logic modifying fan pressure rise  already exists in the model. EEM not applied")
            return true
          else
            runner.registerInfo("EMS string: #{js[1]["fan"].to_s} has no EMS conflict")
          end
        end
      end
    end
    
    idf_file = OpenStudio::IdfFile::load(ems_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding EMS code to workspace")
    workspace.addObjects(idf_file.objects)
    
    #unique initial conditions based on
    #runner.registerInitialCondition("The building has #{emsProgram.size} EMS objects.")

    #reporting final condition of model
    #runner.registerFinalCondition("The building finished with #{emsProgram.size} EMS objects.")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AdvancedRTUControlsEplus.new.registerWithApplication