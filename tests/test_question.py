"""
This file tests the BOPCheckboxQuestion and BOPMCQuestion classes.
"""
import numpy as np
import pandas as pd
import pytest as pytest
import boptools.question


@pytest.fixture
def poll_03_raw_data():
    FILENAMES = [
        'https://docs.google.com/spreadsheets/d/e/2PACX-1vTAHfGjhQpmRDxCogsvqUORaKiSc8PGCF4-UXY5W27WUfA9TSIBR8lClcUMgBBzQdoQnG4Yxy89Yo14/pub?gid=938058835&single=true&output=csv',
        'https://docs.google.com/spreadsheets/d/e/2PACX-1vQ3MzWxGZBipj1tQsSq9cnIwvZMLybB4s9SoDt85wLVLju7yjMpYGV5TB9W5JC_eWtGK4cgqtr5cRxe/pub?gid=739468815&single=true&output=csv',
        'https://docs.google.com/spreadsheets/d/e/2PACX-1vTboCkU4YN4NOZMNJwuTGYtYub9lV5BJ5m4xKn3O74SjMbPGkZ_rgs6BPL8JIIfzWfVjCVlf2gm7h3M/pub?gid=782729277&single=true&output=csv']

    dfs = []
    for filename in FILENAMES:
        dfs.append(pd.read_csv(filename))
    return pd.concat(dfs, axis=0).reset_index(drop=True)


def test_multiple_choice_recode(poll_03_raw_data):
    weighting_variable = np.trunc(poll_03_raw_data['What graduation class are you?'])
    weighting_variable_values = weighting_variable.value_counts(normalize=True).to_dict()
    optimal_portion = 1 / len(weighting_variable_values)
    to_replace = []
    value = []
    for weighting_variable_value in weighting_variable_values:
        to_replace.append(weighting_variable_value)
        weight = optimal_portion / weighting_variable_values[weighting_variable_value]
        value.append(weight)
    weighting_variable = weighting_variable.replace(to_replace=to_replace, value=value).rename("weights")

    smart_column = poll_03_raw_data["Should Brown require applicants to submit a standardized test score (ACT/SAT)?"]
    mc_question = boptools.question.BOPMCQuestion(data=smart_column,
                                                  weighting_variable=weighting_variable,
                                                  output="/Users/arjunshanmugam/Desktop")
    mc_question.recode()
    mc_question.plot_responses(weighted=True, moe=0)
    mc_question.plot_responses(weighted=False, moe=0)


def test_checkbox_recode(poll_03_raw_data):
    weighting_variable = np.trunc(poll_03_raw_data['What graduation class are you?'])
    weighting_variable_values = weighting_variable.value_counts(normalize=True).to_dict()
    optimal_portion = 1 / len(weighting_variable_values)
    to_replace = []
    value = []
    for weighting_variable_value in weighting_variable_values:
        to_replace.append(weighting_variable_value)
        weight = optimal_portion / weighting_variable_values[weighting_variable_value]
        value.append(weight)
    weighting_variable = weighting_variable.replace(to_replace=to_replace, value=value).rename("weights")

    race_column = poll_03_raw_data['What race do you identify with?']
    checkbox_question = boptools.question.BOPCheckboxQuestion(data=race_column,
                                                              weighting_variable=weighting_variable,
                                                              output="/Users/arjunshanmugam/Desktop")
    major_values = {"White", "Asian", "Black", "Non-white Hispanic", "Prefer not to answer",
                    "Native Hawaiian/Pacific Islander", "American Indian/Alaska Native"}
    checkbox_question.recode(display_values=major_values)
    assert len(checkbox_question.data.columns) == 7
    assert checkbox_question.data['White'].mean() == pytest.approx(.5770, 0.005)
    assert checkbox_question.data['Asian'].mean() == pytest.approx(.3046, 0.005)
    assert checkbox_question.data['Black'].mean() == pytest.approx(.1049, 0.005)
    assert checkbox_question.data['Non-white Hispanic'].mean() == pytest.approx(.0474, 0.005)
    assert checkbox_question.data['Prefer not to answer'].mean() == pytest.approx(.0203, 0.005)
    assert checkbox_question.data['Native Hawaiian/Pacific Islander'].mean() == pytest.approx(.0135, 0.005)
    assert checkbox_question.data['American Indian/Alaska Native'].mean() == pytest.approx(.0118, 0.005)
    checkbox_question.plot_responses(weighted=False, moe=0)
    checkbox_question.plot_responses(weighted=True, moe=0)

    drug_column = poll_03_raw_data[
        '[CW: The following question refers to drug use] Which of the following drugs have you used recreationally in the past six months?'].fillna(
        "None of the above")
    checkbox_question = boptools.question.BOPCheckboxQuestion(data=drug_column,
                                                              weighting_variable=weighting_variable,
                                                              output="/Users/arjunshanmugam/Desktop")
    major_values = {"Alcohol", "Cocaine", "Inhalants (Poppers/Whip-its)", "LSD (Acid)", "Marijuana",
                    "MDMA (Ecstasy/Molly)", "Nicotine", "Psilocybin (Psychedelic mushrooms)", "None of the above",
                    "Unsure", "Prefer not to answer"}
    checkbox_question.recode(display_values=major_values)
    assert len(checkbox_question.data.columns) == 11
    assert checkbox_question.data['Alcohol'].mean() == pytest.approx(0.7750, 0.005)
    assert checkbox_question.data['Marijuana'].mean() == pytest.approx(0.5042, 0.005)
    assert checkbox_question.data['Nicotine'].mean() == pytest.approx(0.1878, 0.005)
    assert checkbox_question.data['None of the above'].mean() == pytest.approx(0.1624, 0.005)
    assert checkbox_question.data['Psilocybin (Psychedelic mushrooms)'].mean() == pytest.approx(0.0880, 0.005)
    assert checkbox_question.data['Cocaine'].mean() == pytest.approx(0.0643, 0.005)
    assert checkbox_question.data['Inhalants (Poppers/Whip-its)'].mean() == pytest.approx(0.0609, 0.005)
    assert checkbox_question.data['LSD (Acid)'].mean() == pytest.approx(0.0372, 0.005)
    assert checkbox_question.data['Prefer not to answer'].mean() == pytest.approx(0.0271, 0.05)
    assert checkbox_question.data['MDMA (Ecstasy/Molly)'].mean() == pytest.approx(0.0186, 0.05)
    assert checkbox_question.data['Unsure'].mean() == pytest.approx(0.00340, 0.005)
    checkbox_question.plot_responses(weighted=False, moe=0)
    checkbox_question.plot_responses(weighted=True, moe=0)

    with pytest.raises(ValueError):
        drug_column = poll_03_raw_data[
            '[CW: The following question refers to drug use] Which of the following drugs have you used recreationally in the past six months?']
        checkbox_question = boptools.question.BOPCheckboxQuestion(data=drug_column,
                                                                  weighting_variable=weighting_variable,
                                                                  output='')
        checkbox_question.recode()  # Should raise ValueError because this column contains missing data.
