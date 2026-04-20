library(anesrake)
library(pollster)
library(tidyverse)
library(dplyr)
library(tidyr)
library(stringr)
library(rlang)
library(ggplot2)
library(plotly)
library(shiny)
library(rsconnect)
library(survey)
library(viridis)
library(sortable)
library(lubridate)
library(bslib)

# Should be the only thing you have to change! Add the newest poll each time!
poll_file_paths <- c(
  "raw_polls/Poll 01 Intake Form.csv",
  "raw_polls/Poll 02 Intake Form.csv",
  "raw_polls/Poll 02 Intake Form.csv",
  "raw_polls/Poll 04 Intake Form.csv",
  "raw_polls/BOP Fall 2022 Poll.csv",
  "raw_polls/Poll 06 Intake.csv",
  "raw_polls/Poll 07 S23 Intake Form.csv",
  "raw_polls/Poll 08 Intake Form.csv",
  "raw_polls/BOP October 2023 Poll.csv",
  "raw_polls/BOP November 2023 Poll.csv",
  "raw_polls/BOP March 2024 Poll.csv",
  "raw_polls/BOP April 2024 Poll.csv",
  "raw_polls/BOP October 2024 Poll.csv",
  "raw_polls/BOP November 2024 Poll.csv",
  "raw_polls/BOP March 2025 Poll.csv",
  "raw_polls/BOP April 2025 Poll.csv",
  "raw_polls/BOP October 2025 Poll.csv",
  "raw_polls/BOP November 2025 Poll Coded.csv",
  "raw_polls/BOP March 2026 Poll.csv"
)

# Standardized poll display names — update dates for early unnumbered polls if known
poll_display_names <- c(
  "Poll #01",
  "Poll #02",
  "Poll #02 (duplicate)",       # same file loaded twice — fix path when possible
  "Poll #04",
  "Poll #05 — Fall 2022",
  "Poll #06",
  "Poll #07 — Spring 2023",
  "Poll #08",
  "Poll #09 — October 2023",
  "Poll #10 — November 2023",
  "Poll #11 — March 2024",
  "Poll #12 — April 2024",
  "Poll #13 — October 2024",
  "Poll #14 — November 2024",
  "Poll #15 — March 2025",
  "Poll #16 — April 2025",
  "Poll #17 — October 2025",
  "Poll #18 — November 2025",
  "Poll #19 — March 2026"
)

all_datasets <- lapply(poll_file_paths, read.csv)

str_change <- function(string) {
  no_periods <- str_replace_all(string, "\\.+", " ")
  str_replace_all(no_periods, "[Select|Check] all that apply", "")
}

random_gender <- function(length) {
  sample(c("Female", "Male"), length, replace = TRUE)
}

random_year <- function(min, max, length) {
  sample(min:max, length, replace = TRUE)
}

cleansing <- function(polling_data) {
  rows <- nrow(polling_data)

  edited_data <- polling_data %>%
    mutate(date = as.character(as.Date(Timestamp)), .keep = "unused") %>%
    rename(gender = contains("gender")) %>%
    mutate(gender = case_when(
      grepl("Female", gender) & grepl("Male", gender) ~ random_gender(rows),
      grepl("Female", gender) ~ "Female",
      grepl("Male", gender) ~ "Male",
      TRUE ~ random_gender(rows)
    )) %>%
    rename(race = contains("race")) %>%
    rename(orientation = contains("orientation")) %>%
    rename(concentration = contains("concentration")) %>%
    rename(year = contains("graduation")) %>%
    mutate(year = ifelse(
      grepl("[P|p]refer", year) | !grepl("^\\d+$", year), NA_character_, year
    )) %>%
    mutate(year = ifelse(
      is.na(year),
      as.character(random_year(
        min(year, na.rm = TRUE), max(year, na.rm = TRUE), rows
      )), year
    )) %>%
    mutate(year = as.integer(ceiling(as.numeric(year)))) %>%
    mutate(across(
      .cols = everything(),
      .fns = ~ ifelse(. == "", "Prefer not to answer", .)
    ))
  edited_data
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

  raking_weights <- anesrake(
    targets, dataset, caseid = seq_len(nrow(dataset)), verbose = FALSE, cap = 5,
    choosemethod = "total", type = "pctlim", pctlim = 0.000005, iterate = TRUE,
    force1 = TRUE
  )

  unname(as.vector(raking_weights[[1]]))
}

make_topline <- function(dataset, feature) {
  transformed_dataset <- dataset %>%
    separate_rows(!!sym(feature), sep = ";\\s*")

  design <- svydesign(ids = ~1, data = transformed_dataset, weights = ~weight)
  formula_feature <- as.formula(paste0("~ ", feature))
  svytable(formula_feature, design)
}

make_crosstab <- function(dataset, feature1, feature2) {
  topline_feature1 <- make_topline(dataset, feature1) %>%
    as.data.frame() %>%
    select(c("Freq"))

  transformed_dataset <- dataset %>%
    separate_rows(!!sym(feature1), sep = ";\\s*") %>%
    separate_rows(!!sym(feature2), sep = ";\\s*")

  design <- svydesign(ids = ~1, data = transformed_dataset, weights = ~weight)
  formula_feature <- as.formula(paste0("~ ", feature1, " + ", feature2))

  crosstab <- svytable(formula_feature, design) %>%
    as.data.frame() %>%
    pivot_wider(names_from = feature2, values_from = Freq) %>%
    cbind(topline_feature1) %>%
    mutate(across(.cols = where(is.numeric), ~.x / Freq)) %>%
    select(-c("Freq"))

  crosstab
}

bop_plot_theme <- theme_minimal(base_size = 13) +
  theme(
    plot.background   = element_rect(fill = "white", color = NA),
    panel.background  = element_rect(fill = "white", color = NA),
    panel.grid.major  = element_line(color = "#ede8e4", linewidth = 0.5),
    panel.grid.minor  = element_blank(),
    axis.text         = element_text(color = "#555555", size = 11),
    axis.title.x      = element_text(color = "#333333", size = 12, face = "bold", margin = margin(t = 10)),
    axis.title.y      = element_text(color = "#333333", size = 12, face = "bold", margin = margin(r = 10)),
    legend.title      = element_text(size = 11, face = "bold", color = "#333333"),
    legend.text       = element_text(size = 10, color = "#555555"),
    legend.background = element_rect(fill = "white", color = NA),
    plot.margin       = margin(15, 20, 15, 10),
    axis.text.x       = element_text(angle = 35, hjust = 1, color = "#555555", size = 10)
  )

# Apply shared plotly config + hover styling. Titles/captions go through here, not ggplot.
plotly_style <- function(p, title = NULL, caption = NULL, extra_annotations = list()) {
  annotations <- extra_annotations
  if (!is.null(caption)) {
    annotations <- c(annotations, list(list(
      text      = caption,
      x         = 1, y = -0.13,
      xref      = "paper", yref = "paper",
      showarrow = FALSE,
      xanchor   = "right",
      font      = list(size = 10, color = "#aaaaaa", family = "Inter, 'Segoe UI', sans-serif")
    )))
  }

  title_spec <- if (!is.null(title)) list(
    text    = paste0("<b>", title, "</b>"),
    font    = list(size = 14, color = "#2a1f1a", family = "Inter, 'Segoe UI', sans-serif"),
    x       = 0.01,
    xanchor = "left"
  ) else NULL

  p %>%
    config(
      displayModeBar        = TRUE,
      modeBarButtonsToRemove = c(
        "zoom2d", "pan2d", "select2d", "lasso2d",
        "zoomIn2d", "zoomOut2d", "autoScale2d", "resetScale2d"
      ),
      displaylogo           = FALSE,
      toImageButtonOptions  = list(format = "png", filename = "bop_chart", scale = 2)
    ) %>%
    layout(
      title       = title_spec,
      annotations = if (length(annotations) > 0) annotations else NULL,
      margin      = list(
        l = 60, r = 20,
        t = if (!is.null(title)) 55 else 25,
        b = if (!is.null(caption)) 55 else 25
      ),
      font        = list(family = "Inter, 'Segoe UI', sans-serif"),
      hoverlabel  = list(
        bgcolor     = "white",
        bordercolor = "#ddd5cf",
        font        = list(family = "Inter, 'Segoe UI', sans-serif", size = 12, color = "#333333")
      )
    )
}

logo_exists <- file.exists("www/bop_logo.png")

ui <- fluidPage(
  theme = bs_theme(primary = "#4E3629", base_font = font_google("Inter")),

  tags$head(tags$style(HTML("

    /* ── Base ── */
    body {
      background-color: #f4f5f7;
      font-family: 'Inter', 'Segoe UI', sans-serif;
    }

    /* ── Header ── */
    .bop-header {
      background: linear-gradient(135deg, #4E3629 0%, #7a4f3a 100%);
      color: white;
      padding: 18px 30px;
      margin-bottom: 24px;
      box-shadow: 0 2px 10px rgba(78,54,41,0.25);
    }
    .header-inner {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .bop-logo {
      height: 52px;
      width: 52px;
      border-radius: 10px;
      object-fit: contain;
      flex-shrink: 0;
    }
    .bop-title {
      font-size: 22px;
      font-weight: 700;
      margin: 0 0 2px 0;
      letter-spacing: -0.3px;
    }
    .bop-subtitle {
      font-size: 13px;
      opacity: 0.72;
      margin: 0;
      font-weight: 400;
    }

    /* ── Cards ── */
    .sidebar-card {
      background: white;
      border-radius: 12px;
      padding: 20px;
      box-shadow: 0 1px 8px rgba(0,0,0,0.07);
      position: sticky;
      top: 20px;
    }
    .main-card {
      background: white;
      border-radius: 12px;
      padding: 20px 24px;
      box-shadow: 0 1px 8px rgba(0,0,0,0.07);
      margin-bottom: 20px;
    }

    /* ── Card title row (title + download button) ── */
    .card-title-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 14px;
      padding-bottom: 10px;
      border-bottom: 2px solid #f0ebe7;
    }
    .card-title {
      font-size: 13px;
      font-weight: 700;
      color: #4E3629;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin: 0;
    }

    /* ── Download button ── */
    .dl-btn {
      font-size: 11px !important;
      font-weight: 600 !important;
      padding: 4px 12px !important;
      background: #4E3629 !important;
      color: white !important;
      border: none !important;
      border-radius: 6px !important;
      cursor: pointer;
      text-decoration: none !important;
      line-height: 1.6;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      transition: background 0.15s;
    }
    .dl-btn:hover { background: #3d2b20 !important; color: white !important; }
    .dl-btn:focus { outline: none; box-shadow: 0 0 0 3px rgba(78,54,41,0.2); }

    /* ── Section labels inside cards ── */
    .section-label {
      font-size: 10px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #4E3629;
      margin: 18px 0 6px 0;
    }
    .section-label:first-child { margin-top: 0; }

    .card-divider {
      border: none;
      border-top: 1px solid #f0ebe7;
      margin: 16px 0;
    }

    /* ── Inputs ── */
    .selectize-input {
      border-radius: 7px !important;
      border-color: #ddd5cf !important;
      font-size: 13px !important;
      box-shadow: none !important;
      padding: 7px 10px !important;
    }
    .selectize-input.focus {
      border-color: #4E3629 !important;
      box-shadow: 0 0 0 3px rgba(78,54,41,0.12) !important;
    }
    .form-control {
      border-radius: 7px !important;
      border-color: #ddd5cf !important;
      font-size: 13px !important;
    }
    .form-control:focus {
      border-color: #4E3629 !important;
      box-shadow: 0 0 0 3px rgba(78,54,41,0.12) !important;
    }

    /* ── Radio buttons ── */
    .radio { margin: 3px 0; }
    .radio label { font-size: 13px; cursor: pointer; color: #444; }
    input[type='radio']:checked + span { color: #4E3629; font-weight: 600; }

    /* ── Inline radio (chart type) ── */
    .radio-inline {
      font-size: 12px !important;
      color: #444;
      margin-right: 10px !important;
      cursor: pointer;
    }
    .radio-inline input[type='radio']:checked ~ span { color: #4E3629; font-weight: 600; }
    .shiny-input-container > .radio-inline:first-of-type { margin-left: 0 !important; }

    /* ── Rank list (sortable) ── */
    .rank-list-container { padding: 0 !important; }
    .rank-list-item {
      border-radius: 7px !important;
      border: 1px solid #ddd5cf !important;
      background: #faf7f5 !important;
      font-size: 12px !important;
      padding: 6px 10px !important;
      margin-bottom: 4px !important;
      cursor: grab;
      color: #444;
      transition: background 0.15s;
    }
    .rank-list-item:hover { background: #f0e9e4 !important; }

    /* ── Table ── */
    .table-responsive { overflow-x: auto; }
    table.dataTable, .shiny-table {
      width: 100% !important;
      border-collapse: separate !important;
      border-spacing: 0 !important;
      font-size: 13px;
    }
    .shiny-table thead th, table thead th {
      background-color: #4E3629 !important;
      color: white !important;
      padding: 11px 16px !important;
      font-weight: 600;
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      border: none !important;
      white-space: nowrap;
    }
    .shiny-table thead th:first-child, table thead th:first-child { border-radius: 8px 0 0 0; }
    .shiny-table thead th:last-child, table thead th:last-child   { border-radius: 0 8px 0 0; }
    .shiny-table tbody tr td, table tbody tr td {
      padding: 9px 16px !important;
      border-top: 1px solid #f0ebe7 !important;
      color: #444;
      vertical-align: middle;
    }
    .shiny-table tbody tr:nth-child(even) td, table tbody tr:nth-child(even) td {
      background-color: #faf7f5;
    }
    .shiny-table tbody tr:hover td, table tbody tr:hover td {
      background-color: #f0e9e4 !important;
    }

    /* ── Page padding ── */
    .page-body { padding: 0 24px 32px; }

    /* ── Plotly toolbar ── */
    .modebar { opacity: 0.4; transition: opacity 0.2s; }
    .modebar:hover { opacity: 1; }

  "))),

  # Header
  div(class = "bop-header",
    div(class = "header-inner",
      if (logo_exists) img(src = "bop_logo.png", class = "bop-logo", alt = "BOP Logo"),
      div(
        div(class = "bop-title", "Brown Opinion Project"),
        div(class = "bop-subtitle", "Toplines & Crosstabs Explorer")
      )
    )
  ),

  div(class = "page-body",
    fluidRow(

      # ── Sidebar ──
      column(3,
        div(class = "sidebar-card",

          div(class = "section-label", "Poll"),
          selectInput("pollnum", NULL,
            choices = setNames(seq_along(all_datasets), poll_display_names)
          ),

          hr(class = "card-divider"),
          div(class = "section-label", "Analysis Type"),
          radioButtons("analysis_choice", NULL,
            choices = c("Topline" = "topline", "Crosstab" = "crosstab")
          ),

          conditionalPanel(
            condition = "input.analysis_choice == 'topline'",
            hr(class = "card-divider"),
            div(class = "section-label", "Question"),
            selectInput("column_topline", NULL, "gender"),
            div(class = "section-label", "Chart Type"),
            radioButtons("chart_type_topline", NULL,
              choices  = c("Bar" = "bar", "Lollipop" = "lollipop", "Donut" = "donut"),
              selected = "bar", inline = TRUE
            ),
            div(class = "section-label", "Response Order"),
            uiOutput("level_order_topline_ui")
          ),

          conditionalPanel(
            condition = "input.analysis_choice == 'crosstab'",
            hr(class = "card-divider"),
            div(class = "section-label", "Group By"),
            selectInput("column1", NULL, "gender"),
            div(class = "section-label", "Question"),
            selectInput("column2", NULL, "year"),
            div(class = "section-label", "Chart Type"),
            radioButtons("chart_type_crosstab", NULL,
              choices  = c("Grouped" = "grouped", "Stacked" = "stacked", "Heatmap" = "heatmap"),
              selected = "grouped", inline = TRUE
            ),
            div(class = "section-label", "Group Order"),
            uiOutput("level_order1_ui"),
            div(class = "section-label", "Response Order"),
            uiOutput("level_order2_ui")
          )
        )
      ),

      # ── Main content ──
      column(9,
        div(class = "main-card",
          div(class = "card-title-row",
            div(class = "card-title", "Chart")
          ),
          plotlyOutput("plot", width = "100%", height = "460px")
        ),
        div(class = "main-card",
          div(class = "card-title-row",
            div(class = "card-title", "Data Table"),
            downloadButton("download_table", "\u2193 Download CSV", class = "dl-btn")
          ),
          div(class = "table-responsive",
            tableOutput("table_display")
          )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  cleaned_data <- reactive({
    req(input$pollnum)
    raw_data <- all_datasets[[as.numeric(input$pollnum)]]
    cleaned  <- cleansing(raw_data)
    weights  <- raking(cleaned)
    cleaned$weight <- weights / sum(weights)
    cleaned
  })

  observe({
    data        <- cleaned_data()
    choices     <- setdiff(colnames(data), c("weight", "date"))
    clean_names <- trimws(sapply(choices, str_change))
    named_choices <- setNames(choices, clean_names)

    updateSelectInput(session, "column_topline", choices = named_choices)
    updateSelectInput(session, "column1", choices = named_choices, selected = "gender")
    updateSelectInput(session, "column2", choices = named_choices, selected = "year")
  })

  rv <- reactiveValues(order_topline = NULL, order1 = NULL, order2 = NULL)

  observeEvent(input$level_order_topline_ui, { rv$order_topline <- input$level_order_topline })
  observeEvent(input$level_order1_ui,        { rv$order1        <- input$level_order1 })
  observeEvent(input$level_order2_ui,        { rv$order2        <- input$level_order2 })

  output$level_order_topline_ui <- renderUI({
    req(input$column_topline)
    levels <- names(make_topline(cleaned_data(), input$column_topline))
    rank_list(input_id = "level_order_topline", options = sortable_options(swap = TRUE), labels = levels)
  })

  output$level_order1_ui <- renderUI({
    req(input$column1)
    levels <- names(make_topline(cleaned_data(), input$column1))
    rank_list(input_id = "level_order1", options = sortable_options(swap = TRUE), labels = levels)
  })

  output$level_order2_ui <- renderUI({
    req(input$column2)
    levels <- names(make_topline(cleaned_data(), input$column2))
    rank_list(input_id = "level_order2", options = sortable_options(swap = TRUE), labels = levels)
  })

  # Shared reactive for table data (numeric — formatted in renderTable, raw for download)
  table_data_raw <- reactive({
    data <- cleaned_data()
    if (input$analysis_choice == "topline") {
      req(input$column_topline, input$level_order_topline)
      make_topline(data, input$column_topline) %>%
        as.data.frame() %>%
        arrange(input$level_order_topline) %>%
        rename(Percent = Freq) %>%
        mutate(Percent = round(Percent * 100, 1))
    } else {
      req(input$column1, input$column2, input$level_order1, input$level_order2)
      result <- make_crosstab(data, input$column1, input$column2) %>%
        as.data.frame() %>%
        arrange(input$level_order1)
      result <- result[, append(input$column1, input$level_order2)]
      result %>% mutate(across(where(is.numeric), ~round(.x * 100, 1)))
    }
  })

  output$table_display <- renderTable({
    df <- table_data_raw()
    if (input$analysis_choice == "topline") {
      df %>% mutate(Percent = paste0(Percent, "%"))
    } else {
      df %>% mutate(across(where(is.numeric), ~paste0(.x, "%")))
    }
  })

  output$download_table <- downloadHandler(
    filename = function() {
      safe_name <- gsub("[^a-zA-Z0-9]", "_", poll_display_names[as.numeric(input$pollnum)])
      paste0(safe_name, "_", input$analysis_choice, ".csv")
    },
    content = function(file) {
      write.csv(table_data_raw(), file, row.names = FALSE)
    }
  )

  output$plot <- renderPlotly({
    dataset    <- cleaned_data()
    n_count    <- nrow(dataset)
    poll_label <- poll_display_names[as.numeric(input$pollnum)]

    if (input$analysis_choice == "topline") {
      req(input$column_topline, input$level_order_topline)
      selected_col <- input$column_topline
      x_label      <- trimws(str_change(selected_col))

      topline <- make_topline(dataset, selected_col) %>%
        as.data.frame() %>%
        rename(Percent = Freq) %>%
        mutate(across(where(is.numeric), ~.x * 100)) %>%
        mutate(tooltip_text = paste0(
          "<b>", !!sym(selected_col), "</b><br>",
          "Percent: <b>", round(Percent, 1), "%</b><br>",
          "<i>N = ", n_count, "</i>"
        ))

      x_factor   <- factor(topline[[selected_col]], levels = input$level_order_topline)
      chart_type <- input$chart_type_topline %||% "bar"
      plot_title <- x_label
      caption    <- paste0("Weighted · ", poll_label, " · N = ", n_count)

      if (chart_type == "bar") {
        p <- ggplot(topline, aes(x = x_factor, y = Percent, text = tooltip_text)) +
          geom_bar(stat = "identity", fill = "#4E3629", width = 0.65) +
          scale_x_discrete(labels = function(x) str_wrap(x, width = 22)) +
          scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
          labs(x = x_label, y = "Weighted %") +
          bop_plot_theme

        ggplotly(p, tooltip = "text") %>% plotly_style(title = plot_title, caption = caption)

      } else if (chart_type == "lollipop") {
        p <- ggplot(topline, aes(x = x_factor, y = Percent, text = tooltip_text)) +
          geom_linerange(aes(ymin = 0, ymax = Percent), color = "#4E3629", linewidth = 1.5) +
          geom_point(size = 6, color = "#4E3629", show.legend = FALSE) +
          geom_point(size = 3, color = "white",   show.legend = FALSE) +
          scale_x_discrete(labels = function(x) str_wrap(x, width = 22)) +
          scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
          labs(x = x_label, y = "Weighted %") +
          bop_plot_theme

        ggplotly(p, tooltip = "text") %>% plotly_style(title = plot_title, caption = caption)

      } else if (chart_type == "donut") {
        ordered_topline <- topline %>%
          mutate(label_col = factor(!!sym(selected_col), levels = input$level_order_topline)) %>%
          arrange(label_col)

        pal <- viridis(nrow(ordered_topline), option = "D", begin = 0.1, end = 0.9)

        plot_ly(
          ordered_topline,
          labels    = ~label_col,
          values    = ~Percent,
          type      = "pie",
          hole      = 0.45,
          textinfo  = "percent",
          hoverinfo = "label+percent",
          textfont  = list(size = 13, color = "white", family = "Inter"),
          marker    = list(colors = pal, line = list(color = "white", width = 2)),
          sort      = FALSE
        ) %>%
          layout(
            showlegend    = TRUE,
            legend        = list(font = list(family = "Inter", size = 11, color = "#333333")),
            paper_bgcolor = "white"
          ) %>%
          plotly_style(
            title = plot_title,
            caption = caption,
            extra_annotations = list(list(
              text      = paste0("N = ", n_count),
              x         = 0.5, y = 0.5,
              showarrow = FALSE,
              font      = list(size = 12, color = "#aaaaaa", family = "Inter")
            ))
          )
      }

    } else if (input$analysis_choice == "crosstab") {
      req(input$column1, input$column2, input$level_order1, input$level_order2)
      col1 <- input$column1
      col2 <- input$column2

      x_label    <- trimws(str_change(col1))
      fill_label <- trimws(str_change(col2))
      plot_title <- paste0(x_label, "  \u00d7  ", fill_label)
      caption    <- paste0("Weighted · ", poll_label, " · N = ", n_count)

      crosstab   <- make_crosstab(dataset, col1, col2)
      chart_type <- input$chart_type_crosstab %||% "grouped"

      crosstab_long <- crosstab %>%
        pivot_longer(cols = !matches(col1), names_to = col2, values_to = "Percent") %>%
        mutate(across(where(is.numeric), ~.x * 100)) %>%
        mutate(tooltip_text = paste0(
          "<b>", x_label, ":</b> ", !!sym(col1), "<br>",
          "<b>", fill_label, ":</b> ", !!sym(col2), "<br>",
          "Percent: <b>", round(Percent, 1), "%</b>"
        ))

      if (chart_type == "grouped") {
        p <- ggplot(crosstab_long, aes(
          x    = factor(!!sym(col1), levels = input$level_order1),
          y    = Percent,
          fill = factor(!!sym(col2), levels = input$level_order2),
          text = tooltip_text
        )) +
          geom_bar(stat = "identity",
            position = position_dodge(width = 0.75), width = 0.65, color = NA
          ) +
          scale_fill_viridis(discrete = TRUE, option = "D", begin = 0.15, end = 0.85) +
          scale_x_discrete(labels = function(x) str_wrap(x, width = 20)) +
          scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
          labs(x = x_label, y = "Weighted %", fill = fill_label) +
          bop_plot_theme

        ggplotly(p, tooltip = "text") %>% plotly_style(title = plot_title, caption = caption)

      } else if (chart_type == "stacked") {
        p <- ggplot(crosstab_long, aes(
          x    = factor(!!sym(col1), levels = input$level_order1),
          y    = Percent,
          fill = factor(!!sym(col2), levels = input$level_order2),
          text = tooltip_text
        )) +
          geom_bar(stat = "identity",
            position = "stack", width = 0.65, color = "white", linewidth = 0.4
          ) +
          scale_fill_viridis(discrete = TRUE, option = "D", begin = 0.15, end = 0.85) +
          scale_x_discrete(labels = function(x) str_wrap(x, width = 20)) +
          scale_y_continuous(expand = expansion(mult = c(0, 0.04))) +
          labs(x = x_label, y = "Weighted %", fill = fill_label) +
          bop_plot_theme

        ggplotly(p, tooltip = "text") %>% plotly_style(title = plot_title, caption = caption)

      } else if (chart_type == "heatmap") {
        p <- ggplot(crosstab_long, aes(
          x    = factor(!!sym(col2), levels = input$level_order2),
          y    = factor(!!sym(col1), levels = rev(input$level_order1)),
          fill = Percent,
          text = tooltip_text
        )) +
          geom_tile(color = "white", linewidth = 0.8) +
          geom_text(
            aes(label = paste0(round(Percent, 1), "%"), color = Percent > 52),
            size = 3.2, fontface = "bold", show.legend = FALSE
          ) +
          scale_color_manual(values = c("TRUE" = "white", "FALSE" = "#333333"), guide = "none") +
          scale_fill_gradient(low = "#f5ede8", high = "#4E3629", name = "%", limits = c(0, 100)) +
          scale_x_discrete(labels = function(x) str_wrap(x, width = 12)) +
          scale_y_discrete(labels = function(x) str_wrap(x, width = 20)) +
          labs(x = fill_label, y = x_label) +
          bop_plot_theme +
          theme(
            panel.grid  = element_blank(),
            axis.text.x = element_text(angle = 30, hjust = 1, color = "#555555", size = 10)
          )

        ggplotly(p, tooltip = "text") %>% plotly_style(title = plot_title, caption = caption)
      }
    }
  })
}

shinyApp(ui = ui, server = server)
