#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class AdvancedRTUControls < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "AdvancedRTUControls"
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
   
     #get all emsProgram in model
#    emsProgram = workspace.getObjectsByType("EnergyManagementSystem:Program".to_IddObjectType)

  #  if emsProgram.size == 0
  #    runner.registerAsNotApplicable("The model does not contain any emsProgram. The model will not be altered.")
  #    return true
  #  end

require 'openstudio'
translator = OpenStudio::OSVersion::VersionTranslator.new
#path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallOffice_90_1-2010.osm")
path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallOffice_DOE Ref 1980-2004.osm")
#path = OpenStudio::Path.new(File.dirname(__FILE__) + "/SmallOffice_DOE Ref Pre-1980.osm")
model = translator.loadModel(path)
model = model.get
#always_on = model.alwaysOnDiscreteSchedule

# get the cooling coil and fan from a unitary heatpump

model.getAirLoopHVACs.each do |air_loop|
  found_coil = 0  #have not found any cooling coils
  found_hcoil = 0  #have not found any heating coils
  found_fan = 0   #have not found any fans 
  air_loop.supplyComponents.each do |component|
    # Get the unitary equipment
    if component.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized
      unitary = component.to_AirLoopHVACUnitaryHeatPumpAirToAir.get
      # Get the cooling coil from inside the unitary equipment
      clg_coil = unitary.coolingCoil
      if clg_coil.to_CoilCoolingDXSingleSpeed.is_initialized
        clg_coil = clg_coil.to_CoilCoolingDXSingleSpeed.get
        puts "Found #{clg_coil.name} on #{air_loop.name}"
        found_coil += 1  #found necessary cooling coil DX singlespeed
      end
      # get heating coil
      htg_coil = unitary.heatingCoil
      if htg_coil.to_CoilHeatingDXSingleSpeed.is_initialized
        puts "Found #{htg_coil.name} on #{air_loop.name}"
        found_hcoil += 1  #found necessary cooling coil DX singlespeed
      end
      # get the supply fan from inside the unitary equipment
      supply_fan = unitary.supplyAirFan
      if supply_fan.to_FanConstantVolume.is_initialized
        supply_fan = supply_fan.to_FanConstantVolume.get
        puts "Found #{supply_fan.name} on #{air_loop.name}"
        found_fan += 1  #found necessary Fan object
      elsif supply_fan.to_FanOnOff.is_initialized
        supply_fan = supply_fan.to_FanOnOff.get
        puts "Found #{supply_fan.name} on #{air_loop.name}"
        found_fan += 1  #found necessary Fan object
      else 
        puts "No OnOff or Constant Volume Fan in the Unitary system on #{air_loop.name}"      
      end        
    end
    # Get the cooling coil directly from the airloop
    if component.to_CoilCoolingDXSingleSpeed.is_initialized
      clg_coil = component.to_CoilCoolingDXSingleSpeed.get
      puts "Found #{clg_coil.name} on #{air_loop.name}"
      found_coil += 1  #found necessary cooling coil DX singlespeed
    end
    # Get the heating coil directly from the airloop
    if component.to_CoilHeatingDXSingleSpeed.is_initialized
      htg_coil = component.to_CoilHeatingDXSingleSpeed.get
      puts "Found #{htg_coil.name} on #{air_loop.name}"
      found_hcoil += 1  #found necessary heating coil DX singlespeed
    end
    # Get the heating coil directly from the airloop
    if component.to_CoilHeatingGas.is_initialized
      htg_coil = component.to_CoilHeatingGas.get
      puts "Found #{htg_coil.name} on #{air_loop.name}"
      found_hcoil += 1  #found necessary heating coil gas
    end
    # Get the heating coil directly from the airloop
    if component.to_CoilHeatingElectric.is_initialized
      htg_coil = component.to_CoilHeatingElectric.get
      puts "Found #{htg_coil.name} on #{air_loop.name}"
      found_hcoil += 1  #found necessary heating coil gas
    end
    # get the supply fan directly from the airloop
    if component.to_FanConstantVolume.is_initialized
      supply_fan = component.to_FanConstantVolume.get
      puts "Found #{supply_fan.name} on #{air_loop.name}"
      found_fan += 1  #found necessary Fan object
    end
    if component.to_FanOnOff.is_initialized
      supply_fan = component.to_FanOnOff.get
      puts "Found #{supply_fan.name} on #{air_loop.name}"
      found_fan += 1  #found necessary Fan object
    end 
  end
  puts "airloop #{air_loop.name} found = #{(found_coil + found_fan)} \n"
  
  #found too many objects on an airloop
  if (found_coil + found_fan) > 2
    puts "Too many objects on airloop #{air_loop.name}"
  #found a Fan and Cooling Coil DX Single Speed, get rest of info
  elsif (found_coil + found_fan) == 2 
      # get outdoorair controller
      if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
        controller_oa = air_loop.airLoopHVACOutdoorAirSystem.get.getControllerOutdoorAir
        puts "Found #{controller_oa.name} on #{air_loop.name}"
        # get actuator node name
        actuatorNodeName = air_loop.airLoopHVACOutdoorAirSystem.get.outboardOANode.get.name.get
        puts "Found #{actuatorNodeName} on #{air_loop.name}" 
        # get minimumFractionofOutdoorAirSchedule
        minimumFractionofOutdoorAirSchedule = controller_oa.minimumFractionofOutdoorAirSchedule
        # get minimumOutdoorAirSchedule
        minimumOutdoorAirSchedule = controller_oa.minimumOutdoorAirSchedule
        if minimumFractionofOutdoorAirSchedule.is_initialized && minimumOutdoorAirSchedule.is_initialized
          puts "Both minimumOutdoorAirSchedule and minimumFractionofOutdoorAirSchedule in Airloop #{air_loop.name} are missing."
        end
        if minimumFractionofOutdoorAirSchedule.is_initialized
          puts "Found #{minimumFractionofOutdoorAirSchedule.get.name} on #{air_loop.name}"
        else
          always_on = model.alwaysOnDiscreteSchedule
          controller_oa.setMinimumFractionofOutdoorAirSchedule(always_on)
          puts "Added #{controller_oa.minimumFractionofOutdoorAirSchedule.get.name} on #{air_loop.name}"
        end       
        if minimumOutdoorAirSchedule.is_initialized
          puts "Found #{minimumOutdoorAirSchedule.get.name} on #{air_loop.name}"
        else
          always_on = model.alwaysOnDiscreteSchedule
          controller_oa.setMinimumOutdoorAirSchedule(always_on) 
          puts "Added #{controller_oa.minimumOutdoorAirSchedule.get.name} on #{air_loop.name}"          
        end  
      end
  end
  puts "\n"
end  
  
  
nodes = [1,2,3]
ems_string = ""
  
ems_string << "EnergyManagementSystem:GlobalVariable," + "\n"
ems_string << "	FanPwrExp,  ! Exponent used in fan power law" + "\n"
ems_string << "	Stage1Speed,  ! Fan speed in cooling mode" + "\n"
ems_string << "	HeatSpeed,    ! Fan speed in heating mode" + "\n"
ems_string << "	VenSpeed,   ! Fan speed in ventilation mode" + "\n"
ems_string << "	EcoSpeed; ! Fan speed in economizer mode" + "\n"
ems_string << "\n"
ems_string << "EnergyManagementSystem:Program," + "\n"
ems_string << "	Set_FanCtl_Par1," + "\n"
ems_string << "	SET FanPwrExp = 2.2," + "\n"
ems_string << "	SET HeatSpeed = 0.9," + "\n"
ems_string << "	SET VenSpeed = 0.4," + "\n"
ems_string << "	SET Stage1Speed = 0.9," + "\n"
ems_string << "	SET EcoSpeed = 0.75;" + "\n"
ems_string << "\n"
ems_string << "EnergyManagementSystem:Program," + "\n"
ems_string << "	Set_FanCtl_Par2," + "\n"
nodes.each_with_index do |item, i|
  if i < nodes.size - 1
  ems_string << "SET PSZ#{i}_OADesignMass = PSZ#{i}_DesignFlowMass," + "\n"
  else
  ems_string << "SET PSZ#{i}_OADesignMass = PSZ#{i}_DesignFlowMass;" + "\n"
  end
end
ems_string << "\n"
ems_string << "EnergyManagementSystem:ProgramCallingManager," + "\n"
ems_string << "	Fan_Parameter_manager,  !- Name" + "\n"
ems_string << "	BeginNewEnvironment,  !- EnergyPlus Model Calling Point" + "\n"
ems_string << "	Set_FanCtl_Par1,        !- Program Name 1" + "\n"
ems_string << "	Set_FanCtl_Par2;        !- Program Name 1" + "\n"
ems_string << "\n"
  
File.open("ems_1", "w") do |f|
  f.write(ems_string)
end  
    #unique initial conditions based on
    # removed listing ranges for variable values since we are editing multiple fields vs. a single field.
    runner.registerInitialCondition("The building has #{emsProgram.size} EMS objects.")

    #reporting final condition of model
    runner.registerFinalCondition("The building finished with #{emsProgram.size} EMS objects.")
    #runner.registerValue("m value", mValue, "")
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AdvancedRTUControls.new.registerWithApplication