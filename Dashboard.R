library(anesrake)
library(pollster)
library(tidyverse)
library(stringr)
library(rlang)
library(ggplot2)
library(shiny)
library(rsconnect)
library(survey)
library(viridis)
library(sortable)

#Should be the only thing you have to change! Add the newest poll each time!
all_datasets <- list(
  read.csv("raw_polls/Poll 01 Intake Form.csv"), 
  read.csv("raw_polls/Poll 02 Intake Form.csv"), 
  read.csv("raw_polls/Poll 02 Intake Form.csv"), 
  read.csv("raw_polls/Poll 04 Intake Form.csv"), 
  read.csv("raw_polls/BOP Fall 2022 Poll.csv"), 
  read.csv("raw_polls/Poll 06 Intake.csv"), 
  read.csv("raw_polls/Poll 07 S23 Intake Form.csv"), 
  read.csv("raw_polls/Poll 08 Intake Form.csv"), 
  read.csv("raw_polls/BOP October 2023 Poll.csv")
)

#formatting the column names correctly
str_change <- function(string) {
  no_periods <- str_replace_all(string, "\\.+", " ")
  no_select <- str_replace_all(no_periods, "[Select|Check] all that apply", "")
  return (no_select)
}

#randomly samples either Male/Female
random_gender <- function(length) {
  return(sample(c("Female", "Male"), length, replace = TRUE))  
}

random_year <- function(min, max, length) {
  return(sample(min:max, length, replace = TRUE))
}


cleansing <- function(polling_data) {
  rows = nrow(polling_data)
  
  edited_data <- polling_data %>% 
    select(-"Timestamp") %>%
    #Working with the gender column
    rename(gender = contains("gender")) %>%
    #for data purposes, we have to put either Female/Male for each person
    #if a person puts both or neither, randomize gender, otherwise apply gender
    mutate(gender = case_when(
      grepl("Female", gender) & grepl("Male", gender) ~ random_gender(rows),
      grepl("Female", gender) ~ "Female", 
      grepl("Male", gender) ~ "Male", 
      TRUE ~ random_gender(rows)
    )) %>%
    #Simplifyng name of race, orientation, and concentration column
    rename(race = contains("race")) %>%
    rename(orientation = contains("orientation")) %>%
    rename(concentration = contains("concentration")) %>%
    rename(year = contains("graduation")) %>%
    # Assuming year is a character column. Convert non-numeric entries to NA temporarily.
    mutate(year = ifelse(grepl("[P|p]refer", year) | !grepl("^\\d+$", year), NA_character_, year)) %>%
    # Now, handle NA entries
    mutate(year = ifelse(is.na(year), as.character(random_year(
      min(year, na.rm = TRUE), max(year, na.rm = TRUE), rows)), year)) %>%
    mutate(year = as.integer(ceiling(as.numeric(year)))) %>%
    mutate(across(.cols = everything(), 
                  .fns = ~ ifelse(. == "", "Prefer not to answer", .)))
  
  return (edited_data)
}

raking <- function(dataset) {
  dataset$gender <- as.factor(dataset$gender)
  dataset$year <- as.factor(dataset$year)
  
  gender <- c(0.51, 0.49)
  names(gender) <- levels(dataset$gender)
  
  year <- c(0.25, 0.25, 0.25, 0.25)
  names(year) <- levels(dataset$year)
  
  targets <- list(gender, year)
  
  names(targets) <- c("gender", "year")
  
  raking_weights <- anesrake(targets, dataset, caseid = 1:nrow(dataset), verbose = FALSE, cap = 5, choosemethod = "total", type="pctlim", pctlim=0.05, iterate = TRUE, force1 = TRUE)
  
  weights <- unname(as.vector(raking_weights[[1]]))
  
  return(weights)
}

#Makes a topline for a given dataset and feature, saves it, and then adds it to a pdf
make_topline <- function(dataset, feature) {
  transformed_dataset <- dataset %>%
    separate_rows(!!sym(feature), sep = ";\\s*")
  
  # Create a Survey Design with Weights
  # For a simple random sample, using "ids=~1" indicates no stratification or clustering.
  # The "weights" argument specifies the weight column from the data.
  design <- svydesign(ids = ~1, data=transformed_dataset, weights = ~weight)
  
  # Calculate Toplines
  # The svytable function computes the weighted frequency for each race.
  # Convert the feature to a formula
  #formatted_feature <- ifelse(grepl("\\s", feature), paste0("`", feature, "`"), feature)
  formula_feature <- as.formula(paste0("~ ", feature))
  
  # Calculate toplines using svytable
  topline <- svytable(formula_feature, design)
  
  # Convert to percentages out of the total respondents
  return(topline)
  
}

make_crosstab <- function(dataset, feature1, feature2) {
  topline_feature1 <- make_topline(dataset, feature1) %>% 
    as.data.frame() %>%
    select(c("Freq"))
  
  transformed_dataset <- dataset %>%
    separate_rows(!!sym(feature1), sep = ";\\s*") %>%
    separate_rows(!!sym(feature2), sep = ";\\s*")

  # Create a Survey Design with Weights
  # For a simple random sample, using "ids=~1" indicates no stratification or clustering.
  # The "weights" argument specifies the weight column from the data.
  design <- svydesign(ids = ~1, data=transformed_dataset, weights = ~weight)
  
  # Calculate Toplines
  # The svytable function computes the weighted frequency for each race.
  # Convert the feature to a formula
  
  formula_feature <- as.formula(paste0("~ ", feature1, " + ", feature2)) 
  
  crosstab <- svytable(formula_feature, design) %>%
    as.data.frame() %>%
    pivot_wider(
      names_from = feature2, 
      values_from = Freq
    ) %>%
    cbind(topline_feature1) %>%
    mutate(across(.cols = where(is.numeric), ~.x / Freq)) %>%
    select(-c("Freq"))
  
  return(crosstab)
}


ui <- fluidPage(
  titlePanel("Brown Opinion Project Toplines and Crosstabs"),
  
  # Questions on the top
  fluidRow(
    column(3, 
           selectInput("pollnum", "Select Poll Number", 
                       choices = 1:length(all_datasets)),
           radioButtons("analysis_choice", "Choose analysis type:", c("topline" = "topline", "crosstab" = "crosstab")),
           conditionalPanel(condition = "input.analysis_choice == 'topline'",
                            selectInput("column_topline", "Select question", "gender"),
                            uiOutput("level_order_topline_ui")
           ),
           conditionalPanel(condition = "input.analysis_choice == 'crosstab'",
                            selectInput("column1", "Select question to crosstab by", "gender"),
                            selectInput("column2", "Select question to get results", "year"), 
                            uiOutput("level_order1_ui"), 
                            uiOutput("level_order2_ui")
           ) 
    ), 
    column(6, plotOutput("plot", width = "1000px"))
  ),
  
  # Data frame output below the questions
  fluidRow(
    column(12, 
           tableOutput("table_display")
    )
  )
)

server <- function(input, output, session) {
  
  # Reactive expression to read and clean the data
  cleaned_data <- reactive({
    req(input$pollnum)
    raw_data <- all_datasets[[as.numeric(input$pollnum)]]
    cleaned <- cleansing(raw_data)
    weights <- raking(cleaned)
    cleaned$weight <- weights / sum(weights)
    cleaned
  })
  
  # Observe the cleaned_data and update the selectInput(s) accordingly
  observe({
    data <- cleaned_data()
    updateSelectInput(session, "column_topline", choices = colnames(data))
    updateSelectInput(session, "column1", choices = colnames(data), selected = "gender")
    updateSelectInput(session, "column2", choices = colnames(data), selected = "year")
  })

  rv <- reactiveValues(order_topline = NULL, order1 = NULL, order2 = NULL)
  
  observeEvent(input$level_order_topline_ui, {
    rv$order_topline <- input$level_order_topline
  })
  
  observeEvent(input$level_order1_ui, {
    rv$order1 <- input$level_order1
  })
  
  observeEvent(input$level_order2_ui, {
    rv$order2 <- input$level_order2
  })
  
  output$level_order_topline_ui <- renderUI({
    req(input$column_topline)
    data <- cleaned_data()
    selected_col <- input$column_topline
    topline <- make_topline(data, selected_col)

    # Get the unique levels of the selected question
    levels <- names(topline)

    # Create the sortable input
    rank_list(
      input_id = "level_order_topline",
      options = sortable_options(swap = TRUE),
      labels = levels
    )
  })  
  
  output$level_order1_ui <- renderUI({
    req(input$column1)
    data <- cleaned_data()
    selected_col <- input$column1
    topline <- make_topline(data, selected_col)
    
    # Get the unique levels of the selected question
    levels <- names(topline)
    
    # Create the sortable input
    rank_list(
      input_id = "level_order1",
      options = sortable_options(swap = TRUE),
      labels = levels
    )
  })
  
 
  output$level_order2_ui <- renderUI({
    req(input$column2)
    data <- cleaned_data()
    selected_col <- input$column2
    topline <- make_topline(data, selected_col)
    
    # Get the unique levels of the selected question
    levels <- names(topline)
    
    # Create the sortable input
    rank_list(
      input_id = "level_order2",
      options = sortable_options(swap = TRUE),
      labels = levels
    )
  })
  
  # Display the selected columns of the cleaned data
  output$table_display <- renderTable({
    data <- cleaned_data()
    
    if (input$analysis_choice == "topline") {
      req(input$column_topline, input$level_order_topline)
      selected_col <- input$column_topline
      data <- make_topline(data, selected_col) %>% as.data.frame() %>%
        arrange(input$level_order_topline)
    } else if (input$analysis_choice == "crosstab") {
      req(input$column1, input$column2, input$level_order1, input$level_order2)
      col1 <- input$column1
      col2 <- input$column2
      data <- make_crosstab(data, col1, col2) %>% as.data.frame() %>%
        arrange(input$level_order1)
      data <- data[, append(col1, input$level_order2)]
    }
    data
  })
  
  output$plot <- renderPlot({
    dataset <- cleaned_data()
    
    if (input$analysis_choice == "topline") {
      req(input$column_topline, input$level_order_topline)
      selected_col <- input$column_topline
      topline <- make_topline(dataset, selected_col) %>% as.data.frame() %>%
        rename(Percent = Freq) %>%
        mutate(across(where(is.numeric), ~.x * 100))
      
      ggplot(data = topline, aes(x = factor(!!sym(selected_col), levels = input$level_order_topline), 
                                 y = Percent)) +
        geom_bar(stat = "identity") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1)) + 
        xlab(str_change(selected_col)) +
        scale_x_discrete(labels = function(x) str_wrap(x, width = 20))
      
      
    } else if (input$analysis_choice == "crosstab") {
      req(input$column1, input$column2, input$level_order1, input$level_order2)
      col1 <- input$column1
      col2 <- input$column2
      crosstab <- make_crosstab(dataset, col1, col2) %>%
        pivot_longer(
        cols = !matches(col1), 
        names_to = col2,
        values_to = "Percent"
      ) %>%
        mutate(across(where(is.numeric), ~.x * 100))  # Arrange rows based on the sortable input

      ggplot(data = crosstab, aes(x = factor(!!sym(col1), levels = input$level_order1), 
                                    y = Percent, fill = 
                                    factor(!!sym(col2), levels = input$level_order2))) +
        geom_bar(stat = "identity", position = position_dodge(), color = "black") + 
        scale_fill_viridis(discrete = TRUE, option = "D") + 
        theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
        labs(fill=col2) +
        xlab(str_change(col1)) + 
        scale_x_discrete(labels = function(x) str_wrap(x, width = 20))
      
      
    }
  })
}

shinyApp(ui = ui, server = server)
