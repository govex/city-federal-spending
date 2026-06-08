# Title: City Federal Spending - Figures plotCity
# Description:
# Author: Derek Crowe
# Last Edited: 3/29/24


# Map cities to sanity check recipients intersections with boundaries ================================

# Create date-based directory for plots
dir.create(glue("./data-processed/plots/city-bounds/{Sys.Date()}"))

plotCity <- function(place) {
  p <-   
    city_places_sf |>  
    filter(city_label == place) |>  
    ggplot() +     
    geom_sf(fill = "#21918c", alpha = .2) +     
    geom_sf(data = recip_coords_city_zip_trans_sf |>              
              filter(city_label == place),             
            aes()) +   
    theme_minimal() +         
    theme(plot.margin = unit(c(1,1,.5,1), "cm"),           
          plot.background = element_rect(fill = "white", color = "white"),          
          strip.background = element_rect(fill = "grey90", color = "grey90"),          
          strip.text.x = element_text(face = "bold", size = 6),          
          plot.title = element_text(face = "bold"),          
          plot.subtitle = element_text(margin = unit(c(0,0,0,0),"cm")),          
          axis.title.x = element_text(margin = unit(c(0,0,0,0),"cm")),          
          axis.title.y = element_text(margin = unit(c(0,0,0,0),"cm")),          
          axis.text.x = element_text(angle = 0, vjust = 0, hjust=.5),           
          text = element_text(family = "")) +           
    labs(title = glue("USA Spending Recipients in {place}"),                
         subtitle = "",                
         x = "",                
         y = "") 		
  
  ggsave(glue("./data-processed/plots/city-bounds/{Sys.Date()}/{place}.png"), p)
  
}

map(city_places_sf$city_label, ~ plotCity(.x))
