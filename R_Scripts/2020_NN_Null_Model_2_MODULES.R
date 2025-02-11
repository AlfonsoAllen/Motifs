# Load relevant libraries
library(infomapecology)
# Infomap installation guide: https://github.com/Ecological-Complexity-Lab/infomap_ecology_package
library(attempt)
library(igraph)
library(bipartite)
library(tidyverse)
library(magrittr)
library(ggalluvial)
source("R_scripts/functions.R")
source("R_scripts/run_infomap_monolayer2.R")

n_replicates = 500

#Access layers files
dir_ini <- getwd()

#Load data on pollinator visits
pollination <- read_csv2("Raw_Data/final_Pollinators_2020.csv")
# Remove points from ID names
pollination$ID <- sub("\\.", "", pollination$ID)
pollination$ID_Simple <- sub("\\.", "", pollination$ID_Simple)

# filter tabanidae
pollination<- pollination %>% filter(ID != "Tabanidae")

# Adding Line
pollination$Line <- NA

for (i in 1:nrow(pollination)){
  if(pollination$Plot[i] %in% c(1,2,3)){pollination$Line[i] <- 1}
  else if(pollination$Plot[i] %in% c(4,5,6)){pollination$Line[i] <- 2}
  else{pollination$Line[i] <- 3}
}


for (Plot_i in 1:9){

  #Filter pollination data
  pollination_20_i <- pollination %>% filter(Year==2020,!is.na(Plant),Plant!="0",Subplot!="OUT",Plant!="Ground")
  
  pollination_20_i <- pollination_20_i %>% select(Day,Month,Year,Line,Plot,Subplot,Plant,ID_Simple,Visits) %>%
    mutate(date_raw=as.Date(paste(Day,Month,Year,sep="/"), "%d/%m/%Y"),
           Week=as.numeric(format(date_raw, "%V"))) %>%
    rename(ID=ID_Simple)
  
  #------
  # FUNCTION: plant_pheno_overlap 
  # Returns the number of weeks of phenological overlap between plant1 and plant2 over
  # divided by the total duration of plant 1 phenology
  
  plant_pheno_overlap <- function(plant1,plant2,pollination_20_i) {
    
    plantsx <- sort(unique(pollination_20_i$Plant))
    if(sum(c(plant1,plant2) %in% plantsx)<2){
      print(paste("Error: At least one plant does not belong to plot ",
                  Plot_i," experimental phenology",sep=""))
    }else{
      pollination_plant1 <- pollination_20_i %>% filter(Plant==plant1)
      #Weeks in which plant 1 recieves visits
      plant_1_weeks <- min(pollination_plant1$Week):max(pollination_plant1$Week)
      
      pollination_plant2 <- pollination_20_i %>% filter(Plant==plant2)
      #Weeks in which plant 2 recieves visits
      plant_2_weeks <- min(pollination_plant2$Week):max(pollination_plant2$Week)
      
      #number of weeks with phenological overlap between plant1 and plant2
      overlap <- sum(plant_1_weeks %in% plant_2_weeks)
      
      #total_number of weeks in the experimental phenology of plot i
      total_weeks_1 <-  length(plant_1_weeks)
      
      return(overlap/total_weeks_1)
      #return(overlap)
      
    }  
  }
  
  
  
  ###########################
  # CREATE MULTILAYER FOR Plot_i
  ###########################
  
  folder_base <- paste(dir_ini,"/Processed_data/Multilayer_Species/",sep="")
  
  files_base <- list.files(folder_base)
  
  setwd(folder_base)
  
  # Extract layer files for Plot_i
  
  list_files_field_level <- files_base[grepl(paste("Plot_",Plot_i,sep = ""), files_base) &
                                         grepl("2020", files_base) ]
  
# Extract edge_list for each layer
for (i in 1:length(list_files_field_level)){

  # Extract the incidence matrix
  inc_matrix <- read.csv(list_files_field_level[i], header=T, row.names=1)
  
  # Create a graph for each layer
  g_i <- graph_from_incidence_matrix(inc_matrix, directed = FALSE, weighted = T)
  
  # Get the edge_list from the graph and add plant (layer) information
  plant <- strsplit(list_files_field_level[i],".csv")
  plant <- strsplit(plant[[1]][1],".layer_")
  plant <- plant[[1]][2]
  
  g_i_edge_list <- as_tibble(igraph::as_data_frame(g_i, 'edges')) %>% mutate(species=plant)

  if (i==1){
    plot_edge_list <- g_i_edge_list
  }
  else{
    plot_edge_list <- plot_edge_list %>% bind_rows(g_i_edge_list)
  }
}

plot_edge_list_REAL <- plot_edge_list

  for(k in  1:(n_replicates+1)){
    
    if(k==1){
        plot_edge_list <- plot_edge_list_REAL
      }else{
 
      
        plot_edge_list <- random_plot_edge_list_plants2(plot_edge_list_REAL,TRUE) #With complete random
        #plot_edge_list <- random_plot_edge_list_plant_organism2(plot_edge_list_REAL)
        
        layer_animal <- plot_edge_list %>% select(to,species) %>% unique() %>% group_by(to) %>% count()
        
        # # Infomap breaks if no interlayer links exists. The following chunck of code prevents the presence of such networks
        # 
        # while (sum(layer_animal$n > 1) == 0){
        #   plot_edge_list <- random_plot_edge_list_plants2(plot_edge_list_REAL,TRUE)
        #   layer_animal <- plot_edge_list %>% select(to,species) %>% unique() %>% group_by(to) %>% count()
        # }
        
        }
    
    plot_edge_list %>% group_by(to) %>% count(wt=weight)
    plot_edge_list_REAL %>% group_by(to) %>% count(wt=weight)
    
    plot_edge_list %>% group_by(from) %>% count(wt=weight)
    plot_edge_list_REAL %>% group_by(from) %>% count(wt=weight)
    
    plot_edge_list %>% group_by(species) %>% count(wt=weight)
    plot_edge_list_REAL %>% group_by(species) %>% count(wt=weight)
    
    sum(plot_edge_list$weight)
    sum(plot_edge_list_REAL$weight)
  
    # Fix those pollinator names that were modified during the extraction process
    
    plot_edge_list$to[plot_edge_list$to=="Lassioglosum_.immunitum"] <- "Lassioglosum_ immunitum"
    
    pollinators <- sort(unique(plot_edge_list$to)) 
    plants <- sort(unique(plot_edge_list$from))
    layer_plant <- sort(unique(plot_edge_list$species))
    intersect(pollinators, plants)
    A <- length(pollinators) # Number of pollinators
    P <- length(plants) # Number of plants
    S <- A+P
    
    # Create a table with node metadata
    physical_nodes <- tibble(node_id=1:S,
                             type=c(rep('plant',P),rep('pollinator',A)),
                             species=c(plants,pollinators))
    layer_metadata <- tibble(layer_id=1:length(layer_plant), layer_name=layer_plant)
    
    # Replace the node names with node_ids
    
    Plot_edgelist_complete <- tibble(layer_from=plot_edge_list$species,
                                     node_from=plot_edge_list$from,
                                     layer_to=plot_edge_list$species,
                                     node_to=plot_edge_list$to,
                                     weight=plot_edge_list$weight)
    
    ##########
    plant_strength <- Plot_edgelist_complete %>% group_by(layer_from,node_from) %>% 
      count(wt = weight) %>% rename(strength = n)
    
    pollinator_strength <- Plot_edgelist_complete %>% group_by(layer_from,node_to) %>% 
      count(wt = weight) %>% rename(strength = n)
    ##########
    
    #Create the scaled directed list (previous list was meant to be undirected)
    
    #From plant to pollinator
    
    S_Links_Plant_Poll <- Plot_edgelist_complete %>% left_join(plant_strength,
                                                               by=c("layer_from","node_from")) %>%
      mutate(weight=weight/strength) %>% select(-strength)
    
    S_Links_Poll_Plant <- Plot_edgelist_complete %>% left_join(pollinator_strength,
                                                               by=c("layer_from","node_to")) %>%
      
      mutate(weight=weight/strength) %>% select(-strength) %>%
      rename(node_from=node_to,node_to=node_from)
    
    
    S_edge_list <- bind_rows(S_Links_Plant_Poll,S_Links_Poll_Plant)
    
    ###############
    # To create the inter-links we rely on the previous Plot_edgelist_complete
    # Here we can extract information on interlayer connections
    
    for (i in 1:length(pollinators)){
      
      polinator_edges <- Plot_edgelist_complete %>% filter(node_to==pollinators[i])
      polinator_layers <- unique(polinator_edges$layer_to)
      #print (polinator_layers)
      if (length(polinator_layers)>1){
        combination_layers <- t(combn(polinator_layers, 2))
        for (j in 1:nrow(combination_layers)){
          
          #For undirected networks
          # interlink_i<- tibble(layer_from=combination_layers[j,1],
          #                      node_from=pollinators[i],
          #                      layer_to=combination_layers[j,2],
          #                      node_to=pollinators[i],
          #                      weight=1)
          
          #For directed networks
          interlink_i<- tibble(layer_from=c(combination_layers[j,1],combination_layers[j,2]),
                               node_from=c(pollinators[i],pollinators[i]),
                               layer_to=c(combination_layers[j,2],combination_layers[j,1]),
                               node_to=c(pollinators[i],pollinators[i]),
                               weight=c(plant_pheno_overlap(combination_layers[j,1],
                                                            combination_layers[j,2],
                                                            pollination_20_i),
                                        plant_pheno_overlap(combination_layers[j,2],
                                                            combination_layers[j,1],
                                                            pollination_20_i)))
          
          #For undirected
          #Plot_edgelist_complete <- bind_rows(Plot_edgelist_complete,interlink_i)
          
          #For directed
          S_edge_list <- bind_rows(S_edge_list,interlink_i)
        }
      }
    }
    
    S_edge_list_i <- S_edge_list %>% mutate(Plot=Plot_i)
    #if (Plot_i==1){S_edge_list_final <- S_edge_list_i}else{S_edge_list_final <- bind_rows(S_edge_list_final,S_edge_list_i)}
    
    
    # Replace the node names with node_ids
    S_edge_list_ID <- 
      S_edge_list %>% 
      left_join(physical_nodes, by=c('node_from' = 'species')) %>%  # Join for pollinators
      left_join(physical_nodes, by=c('node_to' = 'species')) %>%  # Join for plants
      select(-node_from, -node_to) %>% 
      select(layer_from, node_from=node_id.x, layer_to, node_to=node_id.y, weight) %>% 
      left_join(layer_metadata, by=c('layer_from' = 'layer_name')) %>%  # Join for plants
      left_join(layer_metadata, by=c('layer_to' = 'layer_name')) %>%  # Join for plants
      select(-layer_from, -layer_to) %>% 
      select(layer_from=layer_id.x, node_from, layer_to=layer_id.y, node_to, weight)
    
    #######################################
    # CREATE NETWORK OF NETWORKS LIST
    #######################################
    
    NN_edge_list <- S_edge_list 
    
    for (i in 1:nrow(NN_edge_list)){
      
      if(NN_edge_list$node_from[i] %in% pollinators){
        NN_edge_list$node_from[i] <- paste0(NN_edge_list$node_from[i]," ",NN_edge_list$layer_from[i])
      }
      
      if(NN_edge_list$node_to[i] %in% pollinators){
        NN_edge_list$node_to[i] <- paste0(NN_edge_list$node_to[i]," ",NN_edge_list$layer_to[i])
      }
      
    }
    
    NN_edge_list_final <- NN_edge_list %>% select(node_from,node_to,weight) %>%
      rename(from = node_from, to = node_to)
    
    nn_nodes <- NN_edge_list_final$from %>% unique()
    
    NN_node_ID <- tibble(node_id=as.numeric(1:length(nn_nodes)),species=nn_nodes)
    
    NN_edge_list_final_ID <- NN_edge_list_final %>% rename(species=from) %>%
      left_join(NN_node_ID,by="species") %>% select(-species) %>% rename(from=node_id,species=to) %>%
      left_join(NN_node_ID,by="species") %>% 
      select(-species) %>% rename(to=node_id) %>% select(from,to,weight)
    
    #######################################
    #Running Infomap
    #######################################
    
    #Running Infomap
    #Setting folder with infomap.exe
    folder_info <- paste(dir_ini,"/R_Scripts",sep="")
    
    # Check Infomap is running
    setwd(folder_info)
    check_infomap() # Make sure file can be run correctly. Should return TRUE
    
    
    #############################
    # NN Modules
    
    NN_node_ID2 <- NN_node_ID %>% rename(node_name=species)
    
    Plot_NN <- create_monolayer_object(x = NN_edge_list_final_ID, directed = T, bipartite = F, node_metadata = NN_node_ID2)
    
    Plot_NN2 <- Plot_NN
    Plot_NN2$nodes$node_name <- as.numeric(Plot_NN2$nodes$node_name)
    # Run Infomap
    #modules_relax_rate <- run_infomap_multilayer(Plot_multilayer, relax = F, silent = T, flow_model = 'undirected', trials = 250, seed = 497294, temporal_network = F)
    modules_relax_rate_NN <- run_infomap_monolayer2(Plot_NN2, flow_model = 'directed', silent=T,trials=1000, two_level=T, seed=200952)
    
    
  # Extract information
  
  L_i <- modules_relax_rate_NN$L
  m_i <- modules_relax_rate_NN$m
  
  if(k==1 & Plot_i==1){
    list_L <- c(L_i)
    list_m <- c(m_i)
    list_Plot <- c(Plot_i)
    list_OBS <- c("Real")
  }else{
    
    if(k==1){
      list_OBS <- c(list_OBS,"Real")
    }else{
      list_OBS <- c(list_OBS,"Random")
    }
    
    list_L <- c(list_L,L_i)
    list_m <- c(list_m,m_i)
    list_Plot <- c(list_Plot,Plot_i)
    
  }
  
}
results_test <- tibble(L=list_L,m=list_m,Plot=list_Plot,OBS=list_OBS)

# Commented for security reasons
# write_csv(results_test,paste0("../Processed_data/Data_2020_NULL1/2020_NN_results_test_modules_NULL2_",Plot_i,".csv"))

}

# Commented for security reasons
# result_test_1_7 <- read_csv("results_test_modules_NULL2_7.csv") %>% select(-X1)
# result_test_8_9 <- read_csv("results_test_modules_NULL2_9.csv") %>% select(-X1)
# results_test_final <- bind_rows(result_test_1_7,result_test_8_9)
# write_csv(results_test_final,"results_test_modules_NULL2.csv")
# 
# # Commented for security reasons
# results_test <- tibble(L=list_L,m=list_m,Plot=list_Plot,OBS=list_OBS)
# write.csv(results_test,"../Processed_data/Data_2020_NULL_modules/2020_NN_results_test_modules_NULL2.csv")

setwd(dir_ini)
results_test <- read_csv("Processed_data/Data_2020_NULL_modules/2020_NN_results_test_modules_NULL2.csv") %>%
  dplyr::select(-X1)




L_Plot <- results_test %>% filter(OBS=="Real") %>% select(L,Plot) %>% rename(L_real=L)
m_Plot <- results_test %>% filter(OBS=="Real") %>% select(m,Plot) %>% rename(m_real=m)

results_test <- results_test %>% left_join(L_Plot,by="Plot") %>% left_join(m_Plot,by="Plot")

results_test_fil <- results_test %>% filter(OBS!="Real")


sum(results_test$L[results_test$Plot==1 & results_test$OBS!="Real"] <
      results_test$L[results_test$Plot==1 & results_test$OBS=="Real"])/(length(results_test$L[results_test$Plot==1 & results_test$OBS!="Real"]))


plot_labs <-c(
  "Plot 1",
  "Plot 2",
  "Plot 3",
  "Plot 4",
  "Plot 5",
  "Plot 6",
  "Plot 7",
  "Plot 8",
  "Plot 9"
)
names(plot_labs) <- c(
  '1',
  '2',
  '3',
  '4',
  '5',
  "6",
  '7',
  '8',
  "9"
)




library(boot)
i=1
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=2
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=3
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)


i=4
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)


i=5
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=6
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=7
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=8
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

i=9
results_test_fil_Plot <- results_test_fil %>% filter(Plot==i)
b_L <- boot(results_test_fil_Plot$L, function(u,i) u[i], R = 1000)
boot.ci(b_L, type = c("norm", "basic", "perc"),conf = 0.95)
b_m <- boot(results_test_fil_Plot$m, function(u,i) u[i], R = 10000)
boot.ci(b_m, type = c("norm", "basic", "perc"),conf = 0.95)

png("New_Figures/figA93.png", width=1476*2, height = 1476*2*361/515, res=300*2)
ggplot(results_test_fil)+
  geom_histogram(aes(x=L),binwidth=0.05)+ theme_bw()+
  facet_wrap(vars(Plot),nrow = 3,ncol = 3,labeller=labeller(Plot= plot_labs))+
  geom_vline(data=filter(results_test_fil, Plot==1), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==2), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==3), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==4), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==5), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==6), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==7), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==8), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==9), aes(xintercept=L_real), colour="deepskyblue",linetype = "dashed",size=1)+
  labs(x="Map equation (in bits)", y = "Number of randomized networks")
dev.off()

png("New_Figures/figA94.png", width=1476*2, height = 1476*2*361/515, res=300*2)
ggplot(results_test)+
  geom_histogram(aes(x=m),binwidth=1)+
  facet_wrap(vars(Plot),nrow = 3,ncol = 3,labeller=labeller(Plot= plot_labs))+theme_bw()+
  geom_vline(data=filter(results_test_fil, Plot==1), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==2), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==3), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==4), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==5), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==6), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==7), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==8), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  geom_vline(data=filter(results_test_fil, Plot==9), aes(xintercept=m_real), colour="deepskyblue",linetype = "dashed",size=1)+
  
  labs(x="Number of modules", y = "Number of randomized networks")
dev.off()

ggplot(results_test)+
  geom_point(aes(x=m,y=L))+
  geom_smooth(aes(x=m,y=L),method = "loess")

ggplot(results_test %>% filter(OBS == "Real"))+
  geom_point(aes(x=m,y=L))+
  geom_smooth(aes(x=m,y=L),method = "loess")
