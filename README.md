# Brown Opinion Project Utilities

The dashboard lives in two different places:
* ShinyApps, at https://brownopinionproject.shinyapps.io/boptools/
* Github pages (backup), at https://brownopinionproject.github.io/boptools/

To add a new poll to the dashboard, you'll first need [clone this repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository) and complete the R set-up steps below (if you haven't already) - you'll only need to perform those steps once. 

Then download the dataset straight from the Google Form as a `.csv` (do not export it to Sheets first) by clicking "Responses", the three dots on the top right, and then "Download responses (.csv)". 

For the `.csv`, ensure that none of the questions (i.e. the first row of data) besides the demographics ones contain the keywords "gender", "race", "orientation", "concentration", or "graduation" - the inclusion of these keywords are used to determine which question is a demographics question.

Then add the new `.csv` file inside the `raw_polls` folder. You'll then want to make sure that the app imports the new data - in `app.R`, you'll need to add to the `all_datasets` line:
```r
all_datasets <- list(
    <other previous datasets>
    ..., 
    read.csv("raw_polls/<POLL_FILE_NAME>.csv")
)
```

Then you'll need to deploy the app, either through ShinyApps or Github pages:

### ShinyApps deployment
Open up the R console (make sure you've already performed the set-up per the section below; see that section as well if you need a refresher on how to open the console) and run the following 2 commands:
```r
library(rsconnect)
rsconnect::deployApp(appFiles = c("app.R", list.files("raw_polls", recursive = TRUE, full.names = TRUE)))
```

### Github pages deployment (backup)
The site can also be deployed through Github pages as a backup option. (Github pages does not have a backend server, so all data is loaded and processed each time the page is loaded, so it takes a while to start up when visiting the page.)

To deploy it with Github pages, open up the R console, and run the following command.
```r
shinylive::export(".", "docs")
```

Then commit and push the changes to the repository - Github will automatically then deploy the site, as exported to the `docs/` folder.

## R Set-up

You'll first want to [install R](https://cran.rstudio.com/)! (As of March 2025, it appears that ShinyApps only supports up to R version 4.4.1, so try to install that or an earlier version.) Then, you'll want to [clone the repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository) and open up the R console in your IDE of choice. Instructions are given below for using [VSCode](https://code.visualstudio.com/) and [RStudio](https://posit.co/download/rstudio-desktop/).

### VSCode

First, install the [R extension](https://marketplace.visualstudio.com/items?itemName=REditorSupport.r). Then, to open the R interactive console, first click "Terminal" in the top right, which will cause a terminal will appear as a new window at the bottom of your screen. Click the dropdown error next to the "+" in the top right of the new window, and then click "R terminal" to open the console.

### RStudio

After opening the repository in RStudio, the console will appear as a window on the left side of the screen, labeled as such.

### Installing dependencies and setting up ShinyApps

Once you have an R console open, you'll want to install any dependencies used by the dashboard and for its deployment. To do so, run the following command in your terminal
```
install.packages(c("anesrake", "pollster", "tidyverse", "stringr", "rlang", "ggplot2", "shiny", "rsconnect", "survey", "viridis", "sortable", "lubridate", "shinylive"))
```

You'll then need to provide the `rsconnect` package with authorization to deploy to BOP's ShinyApps account. To do so, log in to [ShinyApps](https://www.shinyapps.io/) using BOP's Google account (`brownopinionproject.pres@gmail.com`). Then click "Account" on the bar in the top left, and then "Tokens" in the dropdown menu that appears. You should see a list containing one authentication token - click "Show" for that token, and then follow the steps it provides. Now you're all set to deploy changes to the dashboard!