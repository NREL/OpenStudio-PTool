#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

require 'json'

#start the measure
class OccupantFeedbackThermostatControl < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Occupant Feedback Thermostat Control"
  end

  # human readable description
  def description
    return "Traditional thermostats have heating and cooling setpoints set based on typical operating hours and assumptions about occupant comfort.  Occupant feedback thermostats actually enable occupants to modify these setpoints by reporting their feelings (hot, cold) to a central system, which uses this feedback to modify the heating and cooling operation.  This measure may increase energy consumption if the current setpoints are currently too cold in winter or too hot in summer.  It may also save less in buildings that already have aggressive nighttime setbacks."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Each zone is given a ZoneControl:Thermostat:ThermalComfort object with heating and cooling schedules set to a Predicted Mean Vote (PMV) of -0.5 during heating and +0.5 during cooling.  This object will set the heating and cooling setpoints such that 90% of the occupants are comfortable.  This control is applied 8am-6pm on weekdays.  During the rest of the time, the building follows the current setpoints. It is not applied to zones without people."
  end  
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make integer arg to run measure [1 is run, 0 is no run]
    run_measure = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("run_measure",true)
    run_measure.setDisplayName("Run Measure")
    run_measure.setDescription("integer argument to run measure [1 is run, 0 is no run]")
    run_measure.setDefaultValue(1)
    args << run_measure
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    run_measure = runner.getIntegerArgumentValue("run_measure",user_arguments)
    if run_measure == 0
      runner.registerAsNotApplicable("Run Measure set to #{run_measure}.")
      return true     
    end
    
    require 'json'
    
    # Get the last openstudio model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Could not load last OpenStudio model, cannot apply measure.")
      return false
    end
    model = model.get
    
    zones_applied = []
    
    idf_string = ""
    
    # Create global PMV schedules
    idf_string << "
    ThermostatSetpoint:ThermalComfort:Fanger:DualSetpoint,
      Dual Comfort Setpoint,   !- Name
      Heating PMV Setpoints,   !- Fanger Thermal Comfort Heating Schedule Name
      Cooling PMV Setpoints;   !- Fanger Thermal Comfort Cooling Schedule Name
      
    Schedule:Compact,
      Heating PMV Setpoints,   !- Name
      Any Number,              !- Schedule Type Limits Name
      Through: 12/31,          !- Field 1
      For: AllDays,            !- Field 2
      Until: 24:00,-0.5;       !- Field 7

    Schedule:Compact,
      Cooling PMV Setpoints,   !- Name
      Any Number,              !- Schedule Type Limits Name
      Through: 12/31,          !- Field 1
      For: AllDays,            !- Field 2
      Until: 24:00,0.5;        !- Field 7    
    
    Schedule:Compact,
      Zone Comfort Control Type Sched,  !- Name
      Comfort Control Type,    !- Schedule Type Limits Name
      Through: 12/31,           !- Field 1
      For: Weekdays,            !- Field 2
      Until: 8:00,0,          !- Field 3
      Until: 18:00,4,          !- Field 3
      Until: 24:00,0;          !- Field 3"    
    
    # Add a thermal comfort thermostat to all zones
    model.getThermalZones.each do |zone|
      # Skip zones with no people
      next if zone.numberOfPeople == 0.0
      zone_name = zone.name.get
      zones_applied << zone_name
      runner.registerInfo("Applied occupant feedback thermostat control to #{zone_name}.")
    
      idf_string << "    
      ZoneControl:Thermostat:ThermalComfort,
        #{zone_name} Comfort Control,  !- Name
        #{zone_name},               !- Zone or ZoneList Name
        PeopleAverage,           !- Averaging Method
        ,                        !- Specific People Name
        12.8,                    !- Minimum Dry-Bulb Temperature Setpoint {C}
        32.2,                    !- Maximum Dry-Bulb Temperature Setpoint {C}
        Zone Comfort Control Type Sched,  !- Thermal Comfort Control Type Schedule Name
        ThermostatSetpoint:ThermalComfort:Fanger:DualSetpoint,  !- Thermal Comfort Control 1 Object Type
        Dual Comfort Setpoint;   !- Thermal Comfort Control 1 Name"    
    end

    # Debugging variables
    # idf_string << "
    # Output:Variable,*,Zone Mean Air Temperature,hourly; !- Zone Average [C]
    # Output:Variable,*,Zone Thermostat Heating Setpoint Temperature,hourly; !- Zone Average [C]
    # Output:Variable,*,Zone Thermostat Cooling Setpoint Temperature,hourly; !- Zone Average [C]
    # Output:Variable,*,Zone Thermal Comfort Control Type,hourly; !- Zone Average []
    # Output:Variable,*,Zone Thermal Comfort Control Fanger Low Setpoint PMV,hourly; !- Zone Average []
    # Output:Variable,*,Zone Thermal Comfort Control Fanger High Setpoint PMV,hourly; !- Zone Average []
    # Output:Variable,*,Zone Thermal Comfort Fanger Model PMV,hourly; !- Zone Average []
    # Output:Variable,*,Zone Thermal Comfort Fanger Model PPD,hourly; !- Zone Average [%]"
    
    # Enable thermal comfort metrics for the existing people objects.
    # Not done in prototypes because of increased simulation time.
    workspace.getObjectsByType("People".to_IddObjectType).each do |people|
      people.setString(19,"Fanger")
    end
    
    idf_file = OpenStudio::IdfFile::load(idf_string, 'EnergyPlus'.to_IddFileType).get
    runner.registerInfo("Adding thermal comfort thermostats to workspace")
    workspace.addObjects(idf_file.objects)
    
    if zones_applied.size == 0
      runner.registerAsNotApplicable("Not Applicable.  Model contained no zones that have people in them, occupant feedback cannot be given wtihout occupants.")
      return true
    else
      runner.registerFinalCondition("Applied occupant feedback thermostat control to #{zones_applied.size} zones.") 
    end
    
    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
OccupantFeedbackThermostatControl.new.registerWithApplication