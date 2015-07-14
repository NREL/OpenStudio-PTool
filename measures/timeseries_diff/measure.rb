# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

require 'csv'

# start the measure
class TimeseriesDiff < OpenStudio::Ruleset::ReportingUserScript

  # human readable name
  def name
    return "timeseries diff"
  end

  # human readable description
  def description
    return "objective function"
  end

  # human readable description of modeling approach
  def modeler_description
    return "objective function"
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the sql file
    csv_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_name", true)
    csv_name.setDisplayName("CSV file name")
    csv_name.setDescription("CSV file name.")
    csv_name.setDefaultValue("mtr.csv")
    args << csv_name
    
    csv_var = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_var", true)
    csv_var.setDisplayName("CSV variable name")
    csv_var.setDescription("CSV variable name")
    csv_var.setDefaultValue("Whole Building:Facility Total Electric Demand Power [W](TimeStep)")
    args << csv_var
    
    sql_key = OpenStudio::Ruleset::OSArgument.makeStringArgument("sql_key", true)
    sql_key.setDisplayName("SQL key")
    sql_key.setDescription("SQL key")
    sql_key.setDefaultValue("Whole Building")
    args << sql_key  

    sql_var = OpenStudio::Ruleset::OSArgument.makeStringArgument("sql_var", true)
    sql_var.setDisplayName("SQL var")
    sql_var.setDescription("SQL var")
    sql_var.setDefaultValue("Facility Total Electric Demand Power")
    args << sql_var    
    
    norm = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("norm", true)
    norm.setDisplayName("norm of the difference of csv and sql")
    norm.setDescription("norm of the difference of csv and sql")
    norm.setDefaultValue(1)
    args << norm     

    find_avail = OpenStudio::Ruleset::OSArgument.makeBoolArgument("find_avail", true)
    find_avail.setDisplayName("find_avail")
    find_avail.setDescription("find_avail")
    find_avail.setDefaultValue(true)
    args << find_avail 

    compute_diff = OpenStudio::Ruleset::OSArgument.makeBoolArgument("compute_diff", true)
    compute_diff.setDisplayName("compute_diff")
    compute_diff.setDescription("compute_diff")
    compute_diff.setDefaultValue(true)
    args << compute_diff
    
    verbose_messages = OpenStudio::Ruleset::OSArgument.makeBoolArgument("verbose_messages", true)
    verbose_messages.setDisplayName("verbose_messages")
    verbose_messages.setDescription("verbose_messages")
    verbose_messages.setDefaultValue(true)
    args << verbose_messages  

    return args
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)
    
    # assign the user inputs to variables
    csv_name = runner.getStringArgumentValue("csv_name", user_arguments)
    csv_var = runner.getStringArgumentValue("csv_var", user_arguments)
    sql_key = runner.getStringArgumentValue("sql_key", user_arguments)
    sql_var = runner.getStringArgumentValue("sql_var", user_arguments)
    norm = runner.getStringArgumentValue("norm", user_arguments)
    find_avail = runner.getBoolArgumentValue("find_avail", user_arguments) 
    compute_diff = runner.getBoolArgumentValue("compute_diff", user_arguments) 
    verbose_messages = runner.getBoolArgumentValue("verbose_messages", user_arguments)
    
    diff = [0.0]
    simdata = [0.0]
    csvdata = [0.0]
    #map = {'Whole Building:Facility Total Electric Demand Power [W](TimeStep)'=>['Whole Building','Facility Total Electric Demand Power'],'OCCUPIED_TZ:Zone Mean Air Temperature [C](TimeStep)'=>['OCCUPIED_TZ','Zone Mean Air Temperature']}

    map = {"#{csv_var}" => { key: sql_key, var: sql_var, index: 0 }}
    cal = {1=>'January',2=>'February',3=>'March',4=>'April',5=>'May',6=>'June',7=>'July',8=>'August',9=>'September',10=>'October',11=>'November',12=>'December'}
    runner.registerInfo("csv_name: #{csv_name}")
    
    csv = CSV.read(csv_name)
    #sql = OpenStudio::SqlFile.new(OpenStudio::Path.new('sim.sql'))
    sql = sqlFile
    env = sql.availableEnvPeriods[0]
    runner.registerInfo("env: #{env}")
    stp = 'Zone Timestep'
    runner.registerInfo("map: #{map}")
    runner.registerInfo("")
    
    if find_avail 
      ts = sql.availableTimeSeries
      runner.registerInfo("available timeseries: #{ts}")
      runner.registerInfo("")
      envs = sql.availableEnvPeriods
      envs.each do |env_s|
        freqs = sql.availableReportingFrequencies(env_s)
        runner.registerInfo("available EnvPeriod: #{env_s}, available ReportingFrequencies: #{freqs}")
        freqs.each do |freq|
          vn = sql.availableVariableNames(env_s,freq.to_s)
          runner.registerInfo("available variable names: #{vn}")
          vn.each do |v|  
            kv = sql.availableKeyValues(env_s,freq.to_s,v)
            runner.registerInfo("variable names: #{v}")
            runner.registerInfo("available key value: #{kv}")
          end
        end  
      end  
    end

    runner.registerInfo("")
    if !csv[1][0].split('  ')[0].nil? && !csv[1][0].split('  ')[1].nil?
      if !csv[1][0].split('  ')[0].split('/')[0][-2,2].nil? && !csv[1][0].split('  ')[0].split('/')[1].nil? && !csv[1][0].split('  ')[1].split(':')[0].nil? && !csv[1][0].split('  ')[1].split(':')[1].nil?
        runner.registerInfo("CSV Time format is correct: #{csv[1][0]}")
      else
        runner.registerError("CSV Time format not correct: #{csv[1][0]}. Correct format Ex: June 24 1:30am Should be 06/24  01:30:00")
        return false
      end      
    else  
      runner.registerError("CSV Time format not correct: #{csv[1][0]}. Correct format Ex: June 24 1:30am Should be 06/24  01:30:00")
      return false
    end  
    
    runner.registerInfo("")
    csv[0].each do |hdr|
      if hdr != 'Date/Time'
        if !map.key? hdr
          runner.registerInfo("CSV hdr not in map: #{hdr}") if verbose_messages
          next
        end
        runner.registerInfo("hdr is: #{hdr}")
        runner.registerInfo("csv_var is: #{csv_var}")
        #next unless map.key? hdr
        key = map[hdr][:key]
        var = map[hdr][:var]
        diff_index = map[hdr][:index]
        runner.registerInfo("var: #{var}")
        runner.registerInfo("key: #{key}")        
        #runner.registerInfo("diff_index: #{diff_index}")  
        if sql.timeSeries(env,stp,var,key).is_initialized
          ser = sql.timeSeries(env,stp,var,key).get
        else
          runner.registerWarning("sql.timeSeries not initialized env: #{env},stp: #{stp},var: #{var},key: #{key}.")
          next
        end    
        csv.each_index do |row|
          if row > 0
            if csv[row][0].nil?
              runner.registerWarning("empty csv row number #{row}")
              next
            end
            mon = csv[row][0].split('  ')[0].split('/')[0][-2,2].to_i
            day = csv[row][0].split('  ')[0].split('/')[1].to_i
            hou = csv[row][0].split('  ')[1].split(':')[0].to_i
            min = csv[row][0].split('  ')[1].split(':')[1].to_i
            dat = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(cal[mon]),day)
            tim = OpenStudio::Time.new(0,hou,min,0)
            dtm = OpenStudio::DateTime.new(dat,tim)
            runner.registerInfo("dtm: #{dtm}") if verbose_messages
            csv[row].each_index do |col|
              if col > 0
                mtr = csv[row][col].to_s
                if csv[0][col] == hdr
                  sim = ser.value(dtm) 
                  if norm == 1
                    dif = mtr.to_f - sim.to_f
                  elsif norm == 2  
                    dif = sim.to_f - mtr.to_f
                  else
                    dif = (mtr.to_f - sim.to_f).abs
                  end              
                  diff[diff_index] = diff[diff_index] + dif.to_f
                  simdata[diff_index] = simdata[diff_index] + sim.to_f
                  csvdata[diff_index] = csvdata[diff_index] + mtr.to_f
                  runner.registerInfo("mtr value is #{mtr}") if verbose_messages
                  runner.registerInfo("sim value is #{sim}") if verbose_messages
                  runner.registerInfo("dif value is #{dif}") if verbose_messages
                  runner.registerInfo("diff value is #{diff.inspect}") if verbose_messages
                end
              end
            end
          end
        end
      end
    end

    runner.registerValue("diff", diff[0], "")
    runner.registerValue("simdata", simdata[0], "")
    runner.registerValue("csvdata", csvdata[0], "")

    return true

  end
  
end

# register the measure to be used by the application
TimeseriesDiff.new.registerWithApplication
