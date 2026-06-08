# Title: City Federal Spending - Figures plotSpending
# Description:
# Author: Derek Crowe
# Last Edited: 06/05/24

# Plot all spending for each FY for each Place ================================

# save each plot separately
dir.create(glue("./data-processed/plots/city-spending/timeline/{Sys.Date()}"))

plotSpending <- function(place) {
  p2 <-   
    city_trans_filtered |>  
    filter(city_label == place) |>  
    group_by(city_label, FY) |>  
    summarise(total_obligations = sum(federal_action_obligation)) |>   
    ggplot(aes(x = FY, y = total_obligations, group = 1)) +       
    geom_line() +       
    scale_y_continuous(limits = c(0, NA), 
                       labels = label_number(suffix = " M", 
                                             scale = 1e-6, accuracy = 1)) +     
    theme_minimal() +       
    theme(plot.margin = unit(c(1,1,.5,1), "cm"),           
          plot.background = element_rect(fill = "white", color = "white"),          
          strip.background = element_rect(fill = "grey90", color = "grey90"),          
          strip.text.x = element_text(face = "bold", size = 6),          
          plot.title = element_text(face = "bold", size = 16),          
          plot.subtitle = element_text(margin = unit(c(0,0,.5,0),"cm")),          
          axis.title.x = element_text(margin = unit(c(.5,0,0,0),"cm")),          
          axis.title.y = element_text(margin = unit(c(0,.75,0,0),"cm")),          
          axis.text.x = element_text(angle = 0, vjust = 0, hjust=.5),           
          text = element_text(family = "")) +           
    labs(title = glue("Federal Spending in {place}"),                
         subtitle = "Prime Awards to local government entities by fiscal year",                
         x = "",                
         y = "Total Federal Obligations") 
  
  ggsave(glue("data-processed/plots/city-spending/timeline/{Sys.Date()}/{place}.png"), p2) 
}

map(city_places$city_label, ~ plotSpending(.x))



city_order <- 
  city_trans_filtered |>
  group_by(city_label) |>
  summarise(total_obligations = sum(federal_action_obligation)) |>
  arrange(-total_obligations) |>
  pull(city_label) |>
  as.factor()

p3 <- 
  city_trans_filtered |>
  group_by(city_label, FY) |>
  summarise(total_obligations = sum(federal_action_obligation)) |>
  ggplot(aes(x = FY, y = total_obligations, group = 1)) + 
  geom_line(color = viridis(1)) + 
  facet_wrap(~factor(city_label, 
                     levels = city_order), 
             scales = "free_y", 
             labeller = label_wrap_gen(width=25)) + 
  scale_y_continuous(limits = c(NA, NA), 
                     labels = label_number(suffix = " M", 
                                           scale = 1e-6, 
                                           accuracy = 1)) +
  theme_minimal() + 
  theme(plot.margin = unit(c(1,1,.5,1), "cm"), 
        plot.background = element_rect(fill = "white", color = "white"),
        strip.background = element_rect(fill = "white", color = "white"),
        strip.text.x = element_text(size = 6),
        plot.title = element_text(face = "bold", size = 16),
        plot.subtitle = element_text(margin = unit(c(0,0,.5,0),"cm")),
        axis.title.x = element_text(margin = unit(c(.5,0,0,0),"cm")),
        axis.title.y = element_text(margin = unit(c(0,.75,0,0),"cm")),
        axis.text.x = element_text(angle = 45, vjust = .5, hjust=.75), 
        legend.position = "bottom",
        text = element_text(family = "")) + 
  labs(title = glue("Federal Spending"), 
       subtitle = "Prime Awards to local government entities by fiscal year", 
       x = "", 
       y = "Total Federal Obligations")

ggsave(
  plot = p3,
  filename = glue("data-processed/plots/city-spending/timeline/AllPlaces_{Sys.Date()}.png"),
  bg = 'transparent', 
  width = 8000,
  height = 4200,
  units = "px", 
  dpi = 350
)

# save each plot separately
dir.create(glue("./data-processed/plots/city-spending/bars/{Sys.Date()}"))

plotSpending_bars <- function(place) {

p4 <-   
  city_trans_filtered |>  
  filter(city_label == place) |>  
  #group_by(city_label, action_date_year_month) |>  
  group_by(city_label, FY) |> 
  summarise(total_obligations = sum(federal_action_obligation))  |>
  #mutate(year_month = lubridate::ym(action_date_year_month)) |>
  mutate(FY = lubridate::ymd(FY, truncated = 2L)) |>
  #ggplot(aes(x = year_month, y = total_obligations, group = 1)) +  
  ggplot(aes(x = FY, y = total_obligations, group = 1)) +
  geom_col() +       
  scale_y_continuous(limits = c(NA, NA), 
                     labels = label_number(suffix = " M", 
                                           scale = 1e-6, 
                                           accuracy = 1)) +    
  scale_x_date(date_breaks = '1 year', date_labels = '%Y') + 
  theme_minimal() +       
  theme(plot.margin = unit(c(1,1,.5,1), "cm"),           
        plot.background = element_rect(fill = "white", color = "white"),          
        strip.background = element_rect(fill = "grey90", color = "grey90"),          
        strip.text.x = element_text(face = "bold", size = 6),          
        plot.title = element_text(face = "bold", size = 16),          
        plot.subtitle = element_text(margin = unit(c(0,0,.5,0),"cm")),          
        axis.title.x = element_text(margin = unit(c(.5,0,0,0),"cm")),          
        axis.title.y = element_text(margin = unit(c(0,.75,0,0),"cm")),          
        axis.text.x = element_text(angle = 0, vjust = 0, hjust=.5),           
        text = element_text(family = "")) +           
  labs(title = glue("Federal Obligations to {place}"),                
       subtitle = "Prime Awards to local government entities by year",                
       x = "",                
       y = "Total Federal Obligations") 

ggsave(glue("data-processed/plots/city-spending/bars/{Sys.Date()}/{place}.png"), p4) 

}

map(city_places$city_label, ~ plotSpending_bars(.x))


p5 <- 
  city_trans_filtered |>  
  #group_by(city_label, action_date_year_month) |>
  group_by(city_label, FY) |>  
  summarise(total_obligations = sum(federal_action_obligation)) |>  
  #mutate(year_month = lubridate::ym(action_date_year_month)) |>
  mutate(FY = lubridate::ymd(FY, truncated = 2L)) |>
  #ggplot(aes(x = year_month, y = total_obligations, group = 1)) +
  ggplot(aes(x = FY, y = total_obligations, group = 1)) +       
  geom_col() +       
  facet_wrap(~factor(city_label, 
                     levels = city_order), 
             scales = "free_y", 
             labeller = label_wrap_gen(width=25)) + 
  scale_y_continuous(limits = c(NA, NA), 
                     labels = label_number(suffix = " M", 
                                           scale = 1e-6, 
                                           accuracy = 1)) +    
  scale_x_date(date_breaks = '1 year', date_labels = '%Y') + 
  theme_minimal() + 
  theme(plot.margin = unit(c(1,1,.5,1), "cm"), 
        plot.background = element_rect(fill = "white", color = "white"),
        strip.background = element_rect(fill = "white", color = "white"),
        strip.text.x = element_text(size = 6),
        plot.title = element_text(face = "bold", size = 16),
        plot.subtitle = element_text(margin = unit(c(0,0,.5,0),"cm")),
        axis.title.x = element_text(margin = unit(c(.5,0,0,0),"cm")),
        axis.title.y = element_text(margin = unit(c(0,.75,0,0),"cm")),
        axis.text.x = element_text(angle = 45, vjust = .5, hjust=.75), 
        legend.position = "bottom",
        text = element_text(family = "")) + 
  labs(title = glue("Federal Spending"), 
       subtitle = "Prime Awards to local government entities by fiscal year", 
       x = "", 
       y = "Total Federal Obligations")

#ggsave(glue("data-processed/plots/bars/AllPlaces_{Sys.Date()}.png"), p5) 

ggsave(
  plot = p5,
  filename = glue("data-processed/plots/city-spending/bars/AllPlaces_{Sys.Date()}.png"),
  bg = 'transparent', 
  width = 8000,
  height = 4200,
  units = "px", 
  dpi = 350
)











