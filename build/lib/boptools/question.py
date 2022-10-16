"""
Defines the BOPQuestion class, an abstract class.
"""
import os
from abc import ABC, abstractmethod
from typing import Union
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import weightedcalcs as wc


class BOPQuestion(ABC):
    """
    An abstract class meant to be inherited by BOPCheckboxQuestion and BOPMultipleChoiceQuestion
    """
    data: Union[pd.Series, pd.DataFrame]
    output: str
    name: str

    def __init__(self, data: pd.Series, weighting_variable: pd.Series, output: str):
        self.data = data
        self.output = output
        self.name = data.name
        self.weighting_variable = weighting_variable

    @abstractmethod
    def recode(self):
        """
        Recodes this question.
        """
        pass

    @abstractmethod
    def plot_responses(self, weighted: bool, moe: float):
        """
        Generate raw_data_path plot.
        :param moe:
        :param weighted:
        """
        pass


class BOPCheckboxQuestion(BOPQuestion):
    """
    A class that recodes, analyzes, and plots "check all that apply" questions.
    """
    num_categories: int

    def recode(self, major_values: set = None):
        """

        :param major_values: Pass a set of values for which this method will generate dummy variables.
        """
        # For checkbox questions, data is a Series of comma-delimited strings. Make a series of lists, then build DF.
        data_as_lists = self.data.str.split(", ")

        # Check for missing data.
        if data_as_lists.isna().sum() > 0:
            raise ValueError(f"Question \"{self.name}\" contains at least one missing response.")

        # Build DataFrame
        data_as_frame = pd.DataFrame(row for row in data_as_lists)

        # Now, get unique values in checkbox question.
        unique_values = set(data_as_frame.values.flatten())
        # Restrict to specified values if requested.
        if major_values is not None:
            unique_values = unique_values.intersection(major_values)

        # Recode values.
        recoded_data = pd.DataFrame()
        for value in unique_values:
            recoded_data.loc[:, value] = np.where(data_as_lists.str.contains(value, na=False, regex=False), 1, 0)
        self.data = recoded_data
        self.num_categories = len(self.data.columns)

    def plot_responses(self, weighted: bool, moe: float):
        """

        :param moe: Margin of error.
        :param weighted: Whether to produce weighted graphs.
        """

        if weighted:
            filename = (self.name + '(Weighted).png').replace("/", "")
            title = (self.name + '(Weighted).png').replace("/", "")
            calc = wc.Calculator(self.weighting_variable.name)
            bar_heights = []
            data_with_weights = pd.concat([self.data, self.weighting_variable], axis=1)
            for column in self.data.columns:
                bar_heights.append(round(100 * (calc.mean(data_with_weights, column)), 2))
        else:
            filename = (self.name + '(Unweighted).png').replace("/", "")
            title = (self.name + '(Unweighted).png').replace("/", "")
            bar_heights = (self.data.mean(axis=0) * 100).round(2)

        fig, ax = plt.subplots()
        ind = np.arange(self.num_categories)
        p = ax.bar(ind, bar_heights, yerr=moe)
        ax.set_ylabel("Percent")
        ax.set_title(title)
        ax.set_xticks(ind)
        ax.set_xticklabels(self.data.columns, rotation='vertical')
        ax.bar_label(p, label_type='edge')

        plt.savefig(os.path.join(self.output, filename), bbox_inches='tight')
        plt.close(fig)

class BOPMCQuestion(BOPQuestion):
    """
    A class that recodes, analyzes, and plots multiple choice questions.
    """
    def recode(self):
        """
        Recode multiple choice question.
        """
        # Raise error if data contains NaN values.
        if self.data.isna().sum() > 0:
            raise ValueError(f"Question \"{self.name}\" contains at least one missing response.")

    def plot_responses(self, weighted: bool, moe: float):
        """

        :param weighted: Whether to produce weighted graphs.
        :param moe: Margin of error.
        """
        if weighted:
            filename = (self.name + ' (Weighted).png').replace("/", "")
            title = self.name + ' (Weighted).png'
            calc = wc.Calculator(self.weighting_variable.name)
            data_with_weights = pd.concat([self.data, self.weighting_variable], axis=1)
            weighted_distribution = (calc.distribution(data_with_weights, self.name).sort_index() * 100).round(2)
            labels = weighted_distribution.index
            bar_heights = weighted_distribution.values
        else:
            filename = (self.name + ' (Unweighted).png').replace("/", "")
            title = self.name + ' (Unweighted).png'
            distribution = (self.data.value_counts(normalize=True).sort_index() * 100).round(2)
            labels = distribution.index
            bar_heights = distribution.values

        fig, ax = plt.subplots()
        ind = np.arange(len(labels))
        p = ax.bar(ind, bar_heights, yerr=moe)
        ax.set_ylabel("Percent")
        ax.set_title(title)
        ax.set_xticks(ind)
        ax.set_xticklabels(labels, rotation='vertical')
        ax.bar_label(p, label_type='edge')

        plt.savefig(os.path.join(self.output, filename), bbox_inches='tight')
        plt.close(fig)