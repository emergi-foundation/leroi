filter_graph_data <- function(clean_data, group_columns, metric_name){
  graph_data <- clean_data %>% 
    {if(!is.null(group_columns)) group_by_at(., .vars=vars(all_of(group_columns))) else .} %>% 
    mutate(group_households = sum(households)) %>% 
    mutate(group_household_weights = ifelse(group_households==0,0,households/group_households)) %>% 
    arrange(!!sym(metric_name)) %>% 
    mutate(group_percentile = cumsum(households * group_household_weights),
           overall_percentile = cumsum(households)/sum(households)
    ) %>% 
    ungroup()
  return(graph_data)
}

grouped_weighted_metrics <- function(graph_data, 
                                     group_columns, 
                                     metric_name, 
                                     metric_cutoff_level, 
                                     upper_quantile_view=1.0, 
                                     lower_quantile_view=0.0){
  # grouped_weighted_medians <- graph_data %>% 
  #    group_by_at(.vars=vars(all_of(group_columns))) %>% 
  #    summarise(metric_median = if( sum(!is.na(households))<3 ){NA} else { weighted.median(!!sym(metric_name), households, na.rm=TRUE)})
  
  weighted_metrics <- graph_data %>% 
    {if(!is.null(group_columns)) group_by_at(., .vars=vars(all_of(group_columns))) else .} %>% 
    summarise(household_count = sum(households),
              total_na = sum(is.na(!!sym(metric_name)) * households, na.rm = TRUE), 
              households_below_cutoff = 
                sum((!!sym(metric_name) < metric_cutoff_level) * households, na.rm = TRUE), 
              metric_max = max(!!sym(metric_name), na.rm = TRUE),
              metric_min = min(!!sym(metric_name), na.rm = TRUE),
              metric_mean = if( sum(!is.na(households*!!sym(metric_name)))<3 || 
                                all(households==0) ){NA}else{
                                  weighted.mean(x=!!sym(metric_name), w=households, na.rm = TRUE) },
              metric_median = if( sum(!is.na(households*!!sym(metric_name)))<3 || 
                                  all(households==0) ){NA}else{
                                    weighted.quantile(x=!!sym(metric_name), w=households, probs=c(.5), na.rm=TRUE)},
              metric_upper = if( sum(!is.na(households*!!sym(metric_name)))<3 || 
                                 all(households==0) ){NA}else{
                                   weighted.quantile(x=!!sym(metric_name), w=households,
                                                     probs=c(upper_quantile_view), na.rm=TRUE)},
              metric_lower = if( sum(!is.na(households*!!sym(metric_name)))<3 || 
                                 all(households==0) ){NA}else{
                                   weighted.quantile(x=!!sym(metric_name), w=households,
                                                     probs=c(lower_quantile_view), na.rm=TRUE)}) %>% 
    mutate(households_pct = household_count/sum(household_count),
           pct_in_group_below_cutoff = households_below_cutoff/household_count,
           pct_total_below_cutoff = households_below_cutoff/sum(households_below_cutoff))
  
  # overall_weighted_metrics <- graph_data %>% ungroup() %>%
  #   summarise(metric_median = if( sum(!is.na(households))<3 ){NA} else { weighted.quantile(x=!!sym(metric_name), w=households, probs=c(.5), na.rm=TRUE)},
  #             metric_upper = if( sum(!is.na(households))<3 ){NA} else { weighted.quantile(x=!!sym(metric_name), w=households, 
  #                                                                                           probs=c(upper_quantile_view), na.rm=TRUE)},
  #             metric_lower = if( sum(!is.na(households))<3 ){NA} else { weighted.quantile(x=!!sym(metric_name), w=households, 
  #                                                                                           probs=c(lower_quantile_view), na.rm=TRUE)}
  #   )
  
  #  all_groups <- as.data.frame(matrix(rep("All",length(group_columns)),nrow=1))
  #  names(all_groups) <- group_columns
  #  overall_weighted_median <- as_tibble(cbind(all_groups, overall_weighted_median))
  
  #  weighted_quantiles <- bind_rows(grouped_weighted_medians,overall_weighted_median) %>% ungroup() %>% 
  #    mutate_at(.vars=vars(all_of(group_columns)), .funs=as.factor)
  
  #  return(weighted_quantiles)
  return(weighted_metrics)
}

calculate_weighted_metrics <- function(graph_data, 
                                       group_columns, 
                                       metric_name, 
                                       metric_cutoff_level, 
                                       upper_quantile_view, 
                                       lower_quantile_view){
  
  weighted_metrics <- grouped_weighted_metrics(graph_data, 
                                               group_columns=NULL, 
                                               metric_name, 
                                               metric_cutoff_level, 
                                               upper_quantile_view, 
                                               lower_quantile_view)
  
  if(!is.null(group_columns)){
    all_groups <- as.data.frame(matrix(rep("All",length(group_columns)),nrow=1))
    names(all_groups) <- group_columns
    weighted_metrics <- as_tibble(cbind(all_groups, weighted_metrics))
    
    grouped_weighted_metrics <- grouped_weighted_metrics(graph_data, 
                                                         group_columns=group_columns, 
                                                         metric_name, 
                                                         metric_cutoff_level, 
                                                         upper_quantile_view, 
                                                         lower_quantile_view)
    
    weighted_metrics <- bind_rows(grouped_weighted_metrics,weighted_metrics) %>% ungroup() %>% 
      mutate_at(.vars=vars(all_of(group_columns)), .funs=as.factor)
    
    
  }else{
    weighted_metrics <- data.frame(group=as.factor(rep("All", nrow(weighted_metrics))), weighted_metrics)
  }
  
  return(weighted_metrics)
}

# weighted_metrics <- calculate_weighted_metrics(graph_data, 
#                                          group_columns, 
#                                          metric_name, 
#                                          metric_cutoff_level, 
#                                          upper_quantile_view, 
#                                          lower_quantile_view)
# weighted_metrics

#' @rdname ggplot2-ggproto
#' @format NULL
#' @usage NULL
#' @export
#' 

StatEcdf <- ggproto("StatEcdf", Stat,
                    compute_group = function(data, scales, weight, n = NULL, pad = TRUE) {
                      # If n is NULL, use raw values; otherwise interpolate
                      if (is.null(n)) {
                        x <- unique(data$x)
                      } else {
                        x <- seq(min(data$x), max(data$x), length.out = n)
                      }
                      
                      if (pad) {
                        x <- c(-Inf, x, Inf)
                      }
                      y <- ewcdf(data$x, weights=data$weight/sum(data$weight))(x)
                      
                      data.frame(x = x, y = y)
                    },
                    
                    default_aes = aes(y = stat(y)),
                    
                    required_aes = c("x")
)

stat_ewcdf <- function(mapping = NULL, data = NULL,
                       geom = "step", position = "identity",
                       weight =  NULL, 
                       ...,
                       n = NULL,
                       pad = TRUE,
                       na.rm = FALSE,
                       show.legend = NA,
                       inherit.aes = TRUE) {
  layer(
    data = data,
    mapping = mapping,
    stat = StatEcdf,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      n = n,
      pad = pad,
      na.rm = na.rm,
      weight = weight,
      ...
    )
  )
}

density_chart <- function(graph_data, 
                          metric_name, 
                          metric_label,
                          group_columns, 
                          metric_cutoff_level, 
                          metric_cutoff_label, 
                          chart_title, 
                          chart_subtitle){
  
  if(!is.null(group_columns)){
    pal_n <- length(levels(interaction(graph_data[,group_columns])))
  } else {
    pal_n <- 1
  }
  
  movie <- "Darjeeling1" #"GrandBudapest1"
  #pal <- wes_palette(name=movie, n=pal_n, type="continuous")
  pal <- sample(x=wes_palette(name=movie, n=pal_n, type="continuous"), 
                size = pal_n, 
                replace = FALSE)
  
  weighted_metrics <- calculate_weighted_metrics(graph_data, 
                                                 group_columns, 
                                                 metric_name, 
                                                 metric_cutoff_level, 
                                                 upper_quantile_view, 
                                                 lower_quantile_view)
  
  
  chart <- graph_data %>% #subset(!is.na(households)) %>% head()
    # ggplot(aes(x=!!sym(metric_name), 
    #            weight=group_household_weights,
    #            color=interaction(!!!sym(group_columns)),
    #            fill=interaction(!!!sym(group_columns))
    # )) + 
    ggplot(aes_string(x=metric_name, 
                      weight="group_household_weights",
                      color=if(is.null(group_columns)){group_columns}else{
                        #interaction(!!!sym(group_columns))
                        paste0("interaction(", paste0(group_columns, collapse =  ", "), ")")
                      },
                      fill=if(is.null(group_columns)){group_columns}else{
                        #interaction(!!!sym(group_columns))
                        paste0("interaction(", paste0(group_columns, collapse =  ", "), ")")
                      },
                      linetype=if(is.null(group_columns)){group_columns}else{
                        #interaction(!!!sym(group_columns))
                        paste0("interaction(", paste0(group_columns, collapse =  ", "), ")")
                      }
    )) + 
    stat_ewcdf(geom='line',  alpha=1, na.rm=T) + 
    stat_ewcdf(aes(ymin=..y.., ymax=1), geom='ribbon', alpha=.1, na.rm=T) + 
    theme_minimal() + 
    scale_color_manual(values=pal) + 
    scale_fill_manual(values=pal) + 
    scale_x_continuous(labels = scales::dollar_format(accuracy=1),
                       breaks=seq(from=0,to=10,by=1), 
                       minor_breaks=seq(from=0,to=10,by=.25),
                       name=metric_label) + 
    scale_y_continuous(labels = scales::label_percent(accuracy = 1), 
                       breaks=seq(from=0,to=1,by=.1), 
                       minor_breaks=seq(from=0,to=1,by=.05),
                       name="Proportion of Households") + 
    theme(legend.justification = c(1, 1), 
          legend.position = c(0.25, 1), 
          legend.title=element_blank(),
          panel.background = element_rect(fill="#f1f1f1"),
          panel.grid.major = element_line(color="#DCDCDC"),
          panel.grid.minor = element_line(color="#DCDCDC"),
          axis.line = element_line(color = "black",
                                   size = 0.5, 
                                   linetype = "solid"),
          axis.text.x=element_text(angle=45, 
                                   hjust=1,
                                   vjust=NULL,
                                   margin=margin(t = 5, 
                                                 r = 0, 
                                                 b = 0, 
                                                 l = 0, 
                                                 unit = "pt")),
          axis.text.y=element_text(angle=10, 
                                   hjust=1,
                                   vjust=0.5,
                                   margin=margin(t = 0, 
                                                 r = 5, 
                                                 b = 0, 
                                                 l = 0, 
                                                 unit = "pt")),
          axis.ticks=element_line(color = "black"),
          axis.ticks.length = unit(-0.1, "cm")) + 
    # geom_segment(y = 0,
    #              x = as.numeric(weighted_medians[weighted_medians$group=="All",c("median_eroi")]),
    #              yend = 0.5,
    #              xend = as.numeric(weighted_medians[weighted_medians$group=="All",c("median_eroi")]),
    #              color="gray25",
    #              linetype="dotted",
    #              size=0.25,
    #              alpha=0.5) +
    # geom_segment(y = 0.5,
    #              x = as.numeric(weighted_medians[weighted_medians$group=="All",c("median_eroi")]),
    #              yend = 0.5,
  #              xend = 0,
  #              color="gray25",
  #              linetype="dotted",
  #              size=0.25,
  #              alpha=0.5) +
  geom_vline(xintercept = metric_cutoff_level,
             linetype="dotted",
             color = "red",
             size=1.0,
             alpha=0.75) +
    annotate("text",
             y = 0,
             x = metric_cutoff_level,
             angle = 0,
             color="red",
             label = metric_cutoff_label,
             vjust = -0.5,
             hjust = 0.0,
             parse = FALSE,
             alpha=0.75) +
    # annotate("text", 
    #          y = 0, 
    #          x = max(weighted_medians$median_eroi), 
    #          angle = 0, 
    #          color="gray25", 
    #          label = "Median", 
    #          vjust = -0.25, 
    #          hjust = -0.1, 
    #          parse = FALSE, 
    #          alpha=0.75) + 
    labs(
      title=chart_title,
      subtitle=chart_subtitle,
      caption=if(is.null(group_columns)){
        group_columns
      } else {
        paste0("By ",paste(group_columns,
                           sep="_",
                           collapse="+"))
      }) + 
    coord_flip(xlim=c(0,10),
               ylim=c(0,1),
               expand=FALSE)
  
  return(chart)
}


make_all_charts <- function(clean_data,
                            group_columns,
                            metric_name,
                            metric_label, 
                            metric_cutoff_level,
                            metric_cutoff_label,
                            upper_quantile_view,
                            lower_quantile_view,
                            chart_title,
                            chart_subtitle){
  graph_data <- filter_graph_data(clean_data, group_columns, metric_name)
  
  weighted_metrics <- calculate_weighted_metrics(graph_data, 
                                                 group_columns, 
                                                 metric_name, 
                                                 metric_cutoff_level, 
                                                 upper_quantile_view=1.0, 
                                                 lower_quantile_view=0.0)
  
  density_chart <- density_chart(graph_data, 
                                 metric_name, 
                                 metric_label, 
                                 group_columns, 
                                 metric_cutoff_level, 
                                 metric_cutoff_label, 
                                 chart_title, 
                                 chart_subtitle)
  
  return(density_chart)
}