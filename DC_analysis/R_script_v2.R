#source file after changing the directory to run in below (variable = dirs)
#make sure there are only 1 results.RData and 1 metadata.RData in the directory
#clear workspace
rm(list = ls())

dirs = "5_5"  #directory name to run in
a <- list.files(path=dirs)
#find RData files in the directory
for(i in 1:length(a)){
  if (unlist(strsplit(a,"[.]")[i])[2] == "RData"){
   load(paste(dirs,"/",a[i],sep=""))
   }
}  

#Find all the building types, climate zones and vintages to loop over
building_type <- unique(results$create_doe_prototype_building.building_type)
climate_zone <- unique(results$create_doe_prototype_building.climate_zone)
building_vintage <- unique(results$create_doe_prototype_building.template)

#Look in the metadata dataframe to find variable/output names
#Find all the variables to loop over
variables <- metadata$name[which(metadata$type_of_variable == "variable")]
#Get the displayname for the variables
variables_display <- metadata$display_name_short[which(metadata$type_of_variable == "variable")]
#Find all the objective functions to compute histograms for
outputs <- metadata$name[which( metadata$type_of_variable=="output")]
#Find all the '.applicable' variables for each variable. This is the True/False flag if the measure was applicable or not
applicable <- outputs[which(grepl("applicable",outputs))]
#Remove the '.applicable' variables from the output list.
outputs <- outputs[which(!grepl("applicable",outputs))]
#Remove the create_DOE_prototype measure from the applicable list since it always runs
applicable <- applicable[applicable != "create_doe_prototype_building.applicable"]
#Get display name for the outputs
outputs_display <- metadata$display_name_short[which( metadata$name %in% outputs)]

#loop over each variable and create one collection of histograms for all outputs
for (p in 1:length(variables)){
  applicable_variable <- NULL
  #find the '.applicable' data for the corresponding variable
  # ex, find add_cooling_tower_controls.applicable for the variable add_cooling_tower_controls.run_measure
  for (r in 1:length(applicable)){
    if (unlist(strsplit(variables[p],"[.]"))[1] == unlist(strsplit(applicable[r],"[.]"))[1]){
      applicable_variable = applicable[r]
    }
  }
  #skip if couldnt find the '.applicable' data
  if (is.null(applicable_variable)){
    print(paste("variable",variables[p],"not found"))
    next
  }
  #define the PNG object for the histograms
  png(paste(dirs,"/",gsub(" ","_",variables_display[p]),".png",sep=""), width=10.0, height=10.0, units="in", pointsize=10, res=200)
  #4 rows and 5 columns
  par(mfrow=c(4,5))
  
  result <- results
  #if more than one variable, Loop over all the variables and reduce dataframe to just those where all the measures were not applied
  if(length(variables)>1){
    for(x in 1:length(variables)){
      #remove all other variable runs except for the p_th variable
      if(variables[x] != variables[p]){
        result <- subset(result, result[,variables[x]]==0)
      }
    }
  }
  
  #loop over the outputs and create histogram for each output
  for (m in 1:length(outputs)){
    #get the data for the m_th output variable
    output <- result[,outputs[m]]
    #get the applicable data for the m_th output variable
    output_applicable <- result[,applicable_variable]
    #set the index for the %Diff variable
    n <- 1
    percent_diff <- c(0)
    failed <- 0
    #loop over building type, climate zone and vintage
    for (i in 1:length(building_type)){
      for (j in 1:length(climate_zone)){
        for (k in 1:length(building_vintage)){
          #find the row in the output_applicable data for the output variable that matches the specific building type, climate zone and vintage and also has the variable measure set to run (not the baseline)
          output_applied <- output_applicable[intersect(intersect(intersect(which(result$create_doe_prototype_building.building_type == building_type[i]),which(result$create_doe_prototype_building.climate_zone == climate_zone[j])),which(result$create_doe_prototype_building.template == building_vintage[k])),which(result[,variables[p]] == 1))]
          #if nothing was found then skip (possibly due to a failed model)
          if(length(output_applied) == 0){
            print("argument length zero")
            next
          }
          #if value is FALSE, then the measure was not applicable so skip
          if(!output_applied){
            print(paste("not applied building_type:",building_type[i],"climate_zone:",climate_zone[j],"building_vintage:",building_vintage[k]))
            next
          }
          #debugging variables
          temp1 <- building_type[i]
          temp2 <- climate_zone[j]
          temp3 <- building_vintage[k]
          applied <- NA
          baseline <- NA
          #get the output value for the applied measure value for the specific building type, climate zone and vintage
          applied <- output[intersect(intersect(intersect(which(result$create_doe_prototype_building.building_type == building_type[i]),which(result$create_doe_prototype_building.climate_zone == climate_zone[j])),which(result$create_doe_prototype_building.template == building_vintage[k])),which(result[,variables[p]] == 1))]
          if(length(applied) > 1){
            print(paste("too many applied found:",building_type[i],"climate_zone:",climate_zone[j],"building_vintage:",building_vintage[k]))
            stop
          }
          #setup temp copy of the results dataframe
          #temp <- results
          #Loop over all the variables and reduce dataframe to just those where all the measures were not applied to find baselines
          #for(x in 1:length(variables)){
          #  temp <- subset(temp, temp[,variables[x]]==0)
          #}
          #find the specific building type, climate zone and vintage in the baseline models dataframe (temp)
          baseline <- output[intersect(intersect(intersect(which(result$create_doe_prototype_building.building_type == building_type[i]),which(result$create_doe_prototype_building.climate_zone == climate_zone[j])),which(result$create_doe_prototype_building.template == building_vintage[k])),which(result[,variables[p]] == 0))]
          #there should only be one value for the baseline.  If not, then error out
          if(length(baseline) > 1){
            print(paste("too many baselines found:",building_type[i],"climate_zone:",climate_zone[j],"building_vintage:",building_vintage[k]))
            stop
          }
          #check if the baseline value is actually a finite number and compute the % difference
          if((length(applied) > 0 ) && (length(baseline) > 0)){
            if(!is.na(baseline) && !is.na(applied)){
              # do % diff unless baseline is 0, then do relative diff
              if (baseline != 0){
                diff <- (applied - baseline)/ (baseline) * 100
              } else {
                #next
                diff <- (applied - baseline)
              }              
              #if diff is not a number, then set to zero
              if(!is.nan(diff) && is.finite(diff)){
                percent_diff[n] <- diff
              } else {
                #next
                percent_diff[n] <- 0
              } 
              #increment the index on percent difference
              n <- n+1
            } else {
              failed = failed + 1
            }
          } else {
            failed = failed + 1
          }          
        }
      }
    }
    print(outputs[m])
    print(paste("n:",n-1))
    print(paste("failed:",failed))
    #png(paste(gsub(" ","_",variables_display[p]),"_",outputs_display[m],".png",sep=""), width=8, height=8.0, units="in", pointsize=10, res=200)
    #hist(percent_diff, breaks=c(-5,-2,-1,1,2,5), freq=F, main=outputs_display[m], xlab="% Difference")    
    hist(percent_diff, breaks=20, freq=T, main=outputs_display[m], xlab="% Difference")
  }
  applicable_display <- metadata$display_name_short[which( metadata$name==variables[p])]
  #setup temp copy of the results dataframe

  #output_applicable <- result[,applicable_variable]
  hist(output_applicable*1, breaks=c(0,0.25,0.75,1), freq=T, main=applicable_display, xlab="Is Measure Applicable",xaxt="n")
  axis(side=1,at=c(0,1),labels=c("False","True"))
  dev.off()
}

  
  