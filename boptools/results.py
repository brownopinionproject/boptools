"""
This file defines the BOPResults class, which
"""
import os
from math import sqrt

import numpy as np
import pandas as pd
from typing import List
from boptools.question import BOPMCQuestion, BOPCheckboxQuestion, BOPQuestion


class BOPResults:
    """
    Processes, analyzes, and graphs Brown Opinion Project poll results.
    """

    raw_data: pd.DataFrame
    recoded_data: pd.DataFrame
    questions: List[BOPQuestion]
    question_type_dict: dict
    display_values_dict: dict
    weights: pd.Series
    output_location: str
    weighting_variable_name: str
    moe: float

    def __init__(self,
                 raw_data_path: str,
                 question_types: dict,
                 weighting_variable_name: str,
                 output_location: str,
                 display_values_dict=None):
        """

        :param raw_data_path: Path to raw survey responses.
        :param question_types: Dictionary mapping question text to question type.
        :param weighting_variable_name: Name of the variable by which responses will be weighted.
        :param output_location: Folder to store output.
        :param display_values_dict:  Dictionary mapping checkbox question text to the values we want to analyze.
        """
        if display_values_dict is None:
            display_values_dict = {}
        self.raw_data = pd.read_csv(raw_data_path).loc[:, question_types.keys()]
        self.question_type_dict = question_types
        self.weighting_variable_name = weighting_variable_name
        self.output_location = output_location
        self.recoded_data = pd.DataFrame()
        self.questions = []
        self.display_values_dict = display_values_dict
        self.weights = pd.Series()

    def calculate_weights(self, truncate: bool):
        """
        Calculate the weights for each observation.
        :param truncate: Whether to truncate weight variable (if it is the class year of the respondent).
        """

        # When class year is used as the weighting variable, truncate so that we only have 4 buckets.
        if truncate:
            weighting_variable = np.trunc(self.raw_data[self.weighting_variable_name])
        else:
            weighting_variable = self.raw_data[self.weighting_variable_name]

        # Get dictionary mapping weighting variable values to relative frequencies.
        weighting_variable_values = weighting_variable.value_counts(normalize=True).to_dict()

        # Assume optimal distribution of weighting variable is uniform.
        optimal_portion = 1 / len(weighting_variable_values)

        values_to_replace = []
        new_values = []
        for weighting_variable_value in weighting_variable_values:
            values_to_replace.append(weighting_variable_value)
            # Calculate weight for each bucket.
            weight = optimal_portion / weighting_variable_values[weighting_variable_value]
            new_values.append(weight)

        # Replace the weighting variable values with the corresponding weights. Rename the Series.
        self.weights = weighting_variable.replace(to_replace=values_to_replace, value=new_values).rename("weights")

    def calculate_moe(self, critical_value=1.96):
        """
        Calculate overall margin of error for poll.
        :param critical_value: The critical value (z-score) in the margin of error formula.
        """
        # Make sure weights have already been calculated.
        if len(self.weights) == 0:
            raise RuntimeError("You must calculate weights before calculating the margin of error.")
        if len(self.recoded_data) == 0:
            raise RuntimeError("You must recode the data before calculating margin of error.")

        N = len(self.raw_data)
        design_effect = (N * sum(self.weights.pow(2))) / (sum(self.weights) ** 2)

        self.moe = sqrt(design_effect) * critical_value * sqrt(0.25 / N)

    def recode(self):
        """
        Recodes the dataset, column by column.
        """
        all_data = []  # Create list to store the Series and DataFrames which correspond to each question.
        for column in self.raw_data.columns:  # Loop through columns.
            question_type = self.question_type_dict[column]  # Get the question type.
            if question_type == "MC":
                mc_question = BOPMCQuestion(data=self.raw_data[column],
                                            weighting_variable=self.weights,
                                            output=self.output_location)
                mc_question.recode()
                self.questions.append(mc_question)  # Keep all BOPQuestions in a field.
                all_data.append(mc_question.data)
            elif question_type == "Checkbox":
                checkbox_question = BOPCheckboxQuestion(data=self.raw_data[column],
                                                        weighting_variable=self.weights,
                                                        output=self.output_location)
                if column in self.display_values_dict:
                    # Specify which values of the checkbox question we want to generate dummies for.
                    checkbox_question.recode(display_values=self.display_values_dict[column])
                else:
                    checkbox_question.recode()
                self.questions.append(checkbox_question)  # Keep all BOPQuestions in a field.
                all_data.append(checkbox_question.data)
            else:
                raise ValueError("Invalid question type dictionary specified. Valid question types are M.C. and Checkbox.")

        self.recoded_data = pd.concat(all_data, axis=1)

    def to_csv(self, sanitize: List[str] = None):
        """
        Saves results to a CSV file.
        :param sanitize: Remove these columns before saving poll results to CSV.
        """
        columns_to_keep = self.recoded_data.columns.tolist()
        if sanitize is not None:
            for column in sanitize:
                columns_to_keep.remove(column)
        self.recoded_data[columns_to_keep].to_csv(os.path.join(self.output_location, "poll_05_recoded.csv"))

    def plot_figures(self):
        """
        Plot all figures from poll.
        """
        for question in self.questions:
            question.plot_responses(weighted=True, moe=0)
            question.plot_responses(weighted=False, moe=0)
