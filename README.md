# boptools
Brown Opinion Project utilities.

To view the dashboard, go to **[this link](https://ashlab11.shinyapps.io/boptools/)**

In the future, to change this dashboard post-poll, a person must only change the all_datasets line. Currently, it reads in all the previous polls. We want to add the newest poll at the END by changing the function call to look like this:

```r
all_datasets <- list(
    <other previous datasets>..., 
    read.csv("raw_polls/<NEW_DATASET_NAME>")
)
```

Be sure to put the new dataset inside the raw_polls folder, and also be sure to download the dataset straight from the google form instead of form -> sheets. 

Afterwards, press the blue button at the top right and press yes to publish!