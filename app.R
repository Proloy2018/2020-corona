
# Libraries ---------------------------------------------------------------

# library(curl)
library(dplyr)
library(ggplot2)
library(ggrepel)
library(httr)
library(readr)
library(rvest)
library(tidyr)
library(scales)
library(shiny)
library(shinythemes)
library(shinyWidgets)
library(shinyjs)



# Data preparation --------------------------------------------------------

cases_deaths = "cases" #cases deaths

source(here::here("R/download_or_load.R"))
source(here::here("R/fetch_worldometers_safely.R"))
source(here::here("R/data-download.R"))
source(here::here("R/data-preparation.R"))

source(here::here("R/fetch_last_update_date.R"))


data_download()
data_preparation()

# Time last commit of source file
last_commit_time = fetch_last_update_date()$result


# UI ----------------------------------------------------------------------

ui <- 
    function(request) {
        fluidPage(
            tags$head(includeHTML(("google-analytics.html"))),
            useShinyjs(),
            

    titlePanel(windowTitle = "Coronavirus tracker",
               title = HTML("<a href=\"https://gorkang.shinyapps.io/2020-corona/\">Coronavirus tracker</a>")),
    theme = shinytheme("flatly"),
    
    sidebarLayout(
        sidebarPanel(
            width = 2,

    selectInput(inputId = 'countries_plot', 
                label = 'Country',
                choices = V1_alternatives,
                multiple = TRUE, 
                selectize = TRUE, 
                width = "100%", 
                selected = c(top_countries, "United Kingdom", "Denmark", "Chile")),
    
    uiOutput('highlight2'),
    
    selectInput(inputId = "cases_deaths", label = "Cases or deaths", selected = "cases", 
                 choices = c("cases", "deaths")),

    radioButtons(inputId = "accumulated_daily_pct", label = "Accumulated, daily or %", selected = "accumulated", 
                 choices = c("accumulated", "daily", "%"), inline = TRUE),
    
    # Dynamically change with cases_deaths
    sliderInput('min_n_cases', paste0("Day 0 after ___ cases"), min = 1, max = 200, value = 100), 
    sliderInput('min_n_deaths', paste0("Day 0 after ___ deaths"), min = 1, max = 200, value = 10),
    
    # Dynamically change with accumulated_daily_pct
    sliderInput("growth_accumulated", "Daily growth (%):", min = 0, max = 100, value = 30),
    sliderInput("growth_daily", "Daily growth (%):", min = 0, max = 100, value = 20),
    sliderInput("growth_pct", "Daily growth (%):", min = -50, max = 0, value = -10),
    
    HTML("<BR>"),
    
    div(style="display:inline-block;width;45%;text-align: center;",
        shinyWidgets::switchInput(inputId = "log_scale", label = "Log", value = TRUE, size = "mini", labelWidth = "40%")
        ), 
    HTML("&nbsp;&nbsp;"),
    div(style="display:inline-block;45%;text-align: center;",
        shinyWidgets::switchInput(inputId = "smooth", label = "Smooth", value = FALSE, size = "mini", labelWidth = "40%")
        ),
    
    HTML("<BR><BR>"),
    
    div( HTML("&nbsp;&nbsp;"), style="display:inline-block;65%;text-align: center;",
        bookmarkButton(label = "URL")
    ), 
    HTML("&nbsp;&nbsp;"),
    div(style="display:inline-block;30%;text-align: center;",
        downloadButton('downloadPlot', 'Plot')
    ),
    
    HTML("<BR><BR>"),
    
    span(
        h6("REMEMBER: Number of cases are not directly comparable between countries (different countries employ different testing strategies)."),
        style="color:darkred"),
    
    hr(),
    
    HTML(paste0("Simple visualization using the ", a(" @JHUSystems Coronavirus", href="https://github.com/CSSEGISandData/COVID-19", target = "_blank"), 
                " and ", a("worldometers.info", href="https://www.worldometers.info/coronavirus/#countries", target = "_blank"), " data.",
                "<BR><BR>Using code and ideas from ",  
                a(" @JonMinton", href="https://github.com/JonMinton/COVID-19", target = "_blank"), ", ", 
                a(" @christoph_sax", href="https://gist.github.com/christophsax/dec0a57bcbc9d7517b852dd44eb8b20b", target = "_blank"), ", ",
                a(" @nicebread303", href="https://github.com/nicebread/corona", target = "_blank"), ", ",
                a("@rubenivangaalen", href="https://twitter.com/rubenivangaalen", target = "_blank"), ", ",
                a("@jburnmurdoch", href="https://twitter.com/jburnmurdoch", target = "_blank"), " and ", a(" @sdbernard", href="https://twitter.com/sdbernard", target = "_blank"))),
    
    

    
    HTML("<BR><BR>"),
    HTML(paste0("By ", a(" @gorkang", href="https://twitter.com/gorkang", target = "_blank")))
    
    ), 

                
        # SHOW PLOT
        mainPanel(
            p(HTML(
                paste0(
                    a(img(src = "github_small.png", title = "Github repo"), href="https://github.com/gorkang/2020-corona", target = "_blank"),
                    "&nbsp;",
                    a("[Issues]", href="https://github.com/gorkang/2020-corona/issues", target = "_blank"),
                    hr(),
                    a("Johns Hopkins Data", href="https://github.com/CSSEGISandData/COVID-19", target = "_blank"), " updated on: ", as.character(last_commit_time), " GMT",
                    "<BR>", a("worldometers.info", href="https://www.worldometers.info/coronavirus/#countries", target = "_blank"), " (last point) updated on: ", as.POSIXct(time_worldometer, format = "%B %d, %Y, %H:%M", tz = "GMT"), "GMT")
                )
              ),
            hr(),
           plotOutput("distPlot", height = "700px", width = "100%"),
           
           hr(),
           
           HTML(
               paste(
                   h3(paste("Data shown in plot"), downloadButton('downloadData', ''))
                   )
           ),
           hr(),
           
           div(
               DT::dataTableOutput("mytable", width = "100%"), 
               align = "center"
           )
           
        )
    )
)
}


# Server ------------------------------------------------------------------

server <- function(input, output, session) {

    setBookmarkExclude(
        c('mytable_rows_current',
          'mytable_rows_all',
          'mytable_state',
          'mytable_search_columns',
          'mytable_search',
          'mytable_cell_clicked',
          'mytable_rows_selected'))
    
    
    # Dynamic menus -----------------------------------------------------------
    
    observeEvent(input$cases_deaths,{
        if (input$cases_deaths == "cases") {
            hide("min_n_deaths")
            show("min_n_cases")
        } else {
            hide("min_n_cases")
            show("min_n_deaths")
        }
    })
    
    VAR_min_n = reactive({
        if (input$cases_deaths == "cases") {
                input$min_n_cases
        } else {
                input$min_n_deaths
        }
    })
    
    
    observeEvent(input$accumulated_daily_pct,{
        if (input$accumulated_daily_pct == "accumulated") {
            hide("growth_daily")
            hide("growth_pct")
            show("growth_accumulated")
        } else if (input$accumulated_daily_pct == "daily") {
            hide("growth_accumulated")
            hide("growth_pct")
            show("growth_daily")
        } else {
            hide("growth_daily")
            hide("growth_accumulated")
            show("growth_pct")
        }
    })
    
    
    VAR_growth = reactive({
        if (input$accumulated_daily_pct == "accumulated") {
            input$growth_accumulated
            
        } else if (input$accumulated_daily_pct == "daily") {
            input$growth_daily
        } else {
            input$growth_pct
        }
    })
    
    VAR_highlight = reactive({
        
        if (is.null(input$highlight)) {
            " "
        } else {
            input$highlight
        }
    })

    
    # Dinamically set highlight choices bases on input$countries_plot
    outVar = reactive({ c(" ", input$countries_plot %>% sort()) })
    output$highlight2 = renderUI({
        selectInput(inputId = 'highlight', 
                    label = 'Highlight countries',
                    choices = outVar(),
                    multiple = TRUE, 
                    selectize = TRUE, 
                    width = "100%", 
                    selected = " ")
    })
    
    

    # final_df() creation -----------------------------------------------------
    
    final_df = reactive({ 

        withProgress(message = 'Preparing data', value = 0, {
            
            # req(input$highlight)
            req(VAR_highlight())
            req(VAR_min_n())
            req(input$cases_deaths)
            req(input$countries_plot)
            
            # Launch data preparation
            data_preparation(cases_deaths = input$cases_deaths)

            if (!is.null(input$countries_plot)) {
                
                dta_temp = dta %>%
                    
                    # selection
                    filter(country %in% input$countries_plot) %>% 
                    
                    # filter
                    filter(value >= VAR_min_n()) %>% 
                    
                    # If repeated values the same day, keep higher
                    group_by(country, time) %>% 
                    distinct(KEY = paste0(country, time, value), .keep_all = TRUE) %>% 
                    select(-KEY) %>% 
                    # top_n(n = 1, wt = value) %>% 
                    ungroup() %>% 
                
                    # re-adjust after filtering
                    group_by(country) %>%
                    mutate(days_after_100 = as.numeric(0:(length(country) - 1)),
                           days_after_100 = 
                               case_when(
                                   source == "worldometers" ~ lag(days_after_100) + round(as.POSIXlt(as.POSIXct(time_worldometer, format = "%B %d, %Y, %H:%M", tz = "GMT"))$hour/24, 2), #.1
                                   TRUE ~ days_after_100
                               )) %>% 
                    group_by(country) %>%
                    mutate(
                        name_end =
                            case_when(
                                days_after_100 == max(days_after_100) & source == "worldometers" ~ paste0(as.character(country), ": ", format(value, big.mark=","), " - ", days_after_100, " days"),
                                TRUE ~ ""))

                
                # Highlight
                 if (any(' ' != VAR_highlight())) {
                     
                     # Create colors diccionary
                     DF_colors_temp =
                         dta_temp %>% 
                         filter(country %in% VAR_highlight()) %>% 
                         distinct(country)
                         
                     # If the selected country does not have observations over the threshold
                     if (nrow(DF_colors_temp) > 0) { 
                         DF_colors = DF_colors_temp %>% 
                             bind_cols(highlight = hue_pal(l = 50)(nrow(.)))
                     } else {
                         DF_colors = DF_colors_temp %>% 
                             mutate(highlight = "")
                     }
                     
                     
                    dta_temp %>% 
                         left_join(DF_colors) %>% 
                         mutate(highlight = 
                                case_when(
                                    is.na(highlight) ~ "grey",
                                    TRUE ~ highlight
                                ))
                } else {
                    dta_temp %>% mutate(highlight = country)
                }
                
            } else {
                tibble(value = 0, 
                       days_after_100 = 0,
                       country = "",
                       source = "",
                       name_end = "")
                
            }
        })
    }) 
    

    growth_line = reactive({
        # We use 1.1 * to avoid overlaping
        if (input$accumulated_daily_pct == "%") {
            tibble(
                value = cumprod(c(100, rep((100 + VAR_growth()) / 100, 1.1 * max(final_df()$days_after_100, na.rm = TRUE)))),
                days_after_100 = 0:(1.1 * max(final_df()$days_after_100, na.rm = TRUE)))
        } else {
            tibble(
                value = cumprod(c(VAR_min_n(), rep((100 + VAR_growth()) / 100, 1.1 * max(final_df()$days_after_100, na.rm = TRUE)))),
                days_after_100 = 0:(1.1 * max(final_df()$days_after_100, na.rm = TRUE)))
        }
        
    })
    
    
    # Show plot
    output$distPlot <- renderPlot({
        
        withProgress(message = 'Loading plot', value = 0, {
            
            # Show accumulated or daily plot
            if (input$accumulated_daily_pct == "daily") {
                DF_plot = final_df() %>% rename(value_temp = value,
                                                value = diff)
            } else if (input$accumulated_daily_pct == "%") {
                DF_plot = final_df() %>% rename(value_temp = value,
                                                value = diff_pct) %>% 
                    mutate(value = value * 100)
            } else {
                DF_plot = final_df()
            }
            
            # Define which countries get a smooth (have enough points)
            VALUE_span = 3
            counts_filter = DF_plot %>% count(country) %>% filter(n > VALUE_span)

            
            # Draw plot ---------------------------------------------
            p_temp = ggplot(data = DF_plot, 
                            aes(x = days_after_100, y = value, group = as.factor(country), color = highlight)) +
                scale_color_hue(l = 50) +
                
                # Trend line
                geom_line(data = growth_line(), aes(days_after_100, value), linetype = "dotted", inherit.aes = FALSE) +

                # Country points (last one bigger)
                geom_point(aes(size = 1 + as.integer(final_df()$name_end != "") - .5), alpha = .7) +
                
                # Country label
                ggrepel::geom_label_repel(aes(label = name_end), show.legend = FALSE, segment.color = "grey", segment.size  = .3, alpha = .7) + 
                
                scale_x_continuous(breaks = seq(0, max(final_df()$value), 2)) +
                labs(
                    title = paste0("Coronavirus confirmed ", input$cases_deaths ,""),
                    subtitle = paste0("Arranged by number of days since ",  VAR_min_n() ," or more ", input$cases_deaths),
                    x = paste0("Days after ",  VAR_min_n() ," confirmed ", input$cases_deaths),
                    y = paste0("Confirmed ", input$accumulated_daily_pct, " ", input$cases_deaths, " (log scale)"), 
                    caption = paste0("Sources: Johns Hopkins CSSE and worldometers.info\n gorkang.shinyapps.io/2020-corona/")
                ) +
                theme_minimal(base_size = 14) +
                theme(legend.position = "none")
            
            # Smooth or not
            if(input$smooth == FALSE) {
                p_temp = p_temp + geom_line(alpha = .7) 
            } else {
                p_temp = p_temp +  
                    geom_smooth(data = DF_plot %>% filter(country %in% counts_filter$country),
                                # method = "lm", formula = y ~ poly(x, VALUE_span - 1), se = FALSE, size = .8, alpha = .6, na.rm = TRUE)
                                method = "loess", span = 1.5, se = FALSE, size = .8, alpha = .6, na.rm = TRUE)
            }

            # if (VAR_highlight() != " ") {p_temp =  p_temp + scale_color_identity()}
            if (any(' ' != VAR_highlight())) { p_temp =  p_temp + scale_color_identity() }
            
            
            # Scale, log or not
            if (input$log_scale == TRUE) {
                p_temp = p_temp +
                    scale_y_log10(labels = function(x) format(x, big.mark = ",", scientific = FALSE))
            } else {
                p_temp = p_temp +
                    scale_y_continuous(labels = function(x) format(x, big.mark = ",", scientific = FALSE)) +
                    labs(y = paste0("Confirmed ", input$accumulated_daily_pct, " ", input$cases_deaths))
            }
            
            
            # Annotation trend line
            if (input$accumulated_daily_pct == "%") {
                y_axis = min(growth_line()$value) 
            } else {
                y_axis = max(growth_line()$value) 
            }

            p_final <<- p_temp + 
                annotate(geom = "text",
                         x = max(growth_line()$days_after_100) - .5, 
                         y = y_axis, 
                         vjust = 1, 
                         hjust = 1, 
                         label = paste0(VAR_growth(), "% growth"))
                
            p_final
            
        })
    })

        
    # Show table
    output$mytable = DT::renderDataTable({
        DT::datatable(final_df() %>%
                          arrange(desc(time), country) %>% 
                          select(-name_end, -highlight) %>%
                          rename_(.dots=setNames("value", ifelse(input$cases_deaths == "cases", "cases_sum", "deaths_sum"))) %>% 
                          rename_(.dots=setNames("diff", ifelse(input$cases_deaths == "cases", "cases_diff", "deaths_diff"))) %>% 
                          rename_(.dots=setNames("days_after_100", paste0("days_after_", VAR_min_n()))),
                          filter = 'top',
                      rownames = FALSE, 
                      options = list(pageLength = 10, 
                                     dom = 'ltipr',
                                     autoWidth = FALSE)) %>% 
            DT::formatPercentage(c("diff_pct"), 2)
    })
    
    
    output$downloadPlot <- downloadHandler(
        filename = function() { paste(Sys.Date(), "_corona.png", sep = "") },
        content = function(file) { ggsave(file, plot = p_final, device = "png", width = 14, height = 10) }
    )

    output$downloadData <- downloadHandler(
        filename = function() { 
            paste("dataset-", Sys.Date(), ".csv", sep="")
        },
        content = function(file) {
            write.csv(final_df() %>%
                          arrange(desc(time), country) %>% 
                          select(-name_end, -highlight) %>%
                          rename_(.dots=setNames("value", ifelse(input$cases_deaths == "cases", "cases_sum", "deaths_sum"))) %>% 
                          rename_(.dots=setNames("diff", ifelse(input$cases_deaths == "cases", "cases_diff", "deaths_diff"))) %>% 
                          rename_(.dots=setNames("days_after_100", paste0("days_after_", VAR_min_n()))), file)
        })
    
}

# Run the application 
shinyApp(ui = ui, server = server, enableBookmarking = "url", options = "test.mode")
