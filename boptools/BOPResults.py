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
    weights: pd.Series
    output: str
    weighting_variable_name: str
    moe: float

    def __init__(self, responses: str, question_types: dict, weighting_variable_name: str, output: str):
        self.raw_data = pd.read_csv(responses).loc[:, question_types.keys()]
        self.question_type_dict = question_types
        self.weighting_variable_name = weighting_variable_name
        self.output = output
        self.recoded_data = pd.DataFrame
        self.questions = []

    def calculate_weights(self, truncate: bool):
        """
        Calculate the weights for each observation.
        :param truncate: Whether to truncate weight variable (if it is the class year of the respondent).
        """
        if truncate:
            weighting_variable = np.trunc(self.raw_data[self.weighting_variable_name])
        else:
            weighting_variable = self.raw_data[self.weighting_variable_name]
        weighting_variable_values = weighting_variable.value_counts(normalize=True).to_dict()
        optimal_portion = 1 / len(weighting_variable_values)
        to_replace = []
        value = []
        for weighting_variable_value in weighting_variable_values:
            to_replace.append(weighting_variable_value)
            weight = optimal_portion / weighting_variable_values[weighting_variable_value]
            value.append(weight)
        self.weights = weighting_variable.replace(to_replace=to_replace, value=value).rename("weights")

    def calculate_moe(self, critical_value=1.96):
        """

        :param critical_value:
        """
        design_effect = (len(self.raw_data) * sum(self.weights.pow(2))) / (sum(self.weights) ** 2)

        self.moe = sqrt(design_effect) * critical_value * sqrt(0.25 / len(self.raw_data))

    def recode(self):
        """
        Recodes the dataset, column by column.
        """
        all_data = []
        for column in self.raw_data.columns:
            question_type = self.question_type_dict[column]
            if question_type == "MC":
                mc_question = BOPMCQuestion(data=self.raw_data[column],
                                            weighting_variable=self.weights,
                                            output=self.output)
                mc_question.recode()
                self.questions.append(mc_question)
                all_data.append(mc_question.data)
            elif question_type == "Checkbox":
                checkbox_question = BOPCheckboxQuestion(data=self.raw_data[column],
                                                        weighting_variable=self.weights,
                                                        output=self.output)
                checkbox_question.recode()
                self.questions.append(checkbox_question)
                all_data.append(checkbox_question.data)
            else:
                raise ValueError("Invalid question type dictionary specified. Valid question types are M.C. and Checkbox.")

        self.recoded_data = pd.concat(all_data, axis=1)
        self.recoded_data.to_csv(os.path.join(self.output, "poll_05_recoded.csv"))

    def plot_figures(self):
        """
        Plot all figures from poll.
        """
        for question in self.questions:
            question.plot_responses(weighted=True, moe=0)
            question.plot_responses(weighted=False, moe=0)