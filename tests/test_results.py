"""
Tests the BOPResults class.
"""
import pytest

from boptools.results import BOPResults

@pytest.fixture
def bop_results_instance():
    # BOPResults instance corresponding to poll 3.
    question_types_dict = {
        "What gender do you identify with?": "MC",
        "What race(s) do you identify with?": "Checkbox",
        "What graduation class are you?": "MC",
        "What is your (intended) concentration area(s)?": "Checkbox",
        "What religious tradition(s) do you identify with?": "Checkbox",
        "Do you think you’re smarter than the average Brown student?": "MC",
        "Are you currently in a relationship?": "MC",
        "What is your favorite dining hall on campus?": "MC",
        "On average, how often do you change your sheets?": "MC",
        "Do you believe in God/gods or a higher power?": "MC",
        "What is your GPA?": "MC",
        "Do you think America is the greatest country in the world?": "MC",
        "Do you believe that there is other intelligent life in the universe?": "MC"
    }

    display_values_dict = {
        "What gender do you identify with?": {},
        "What race(s) do you identify with?": {},
        "What is your (intended) concentration area(s)?": {},
        "What religious tradition(s) do you identify with?": {},


    }

    bop_results = BOPResults(
        raw_data_path="https://docs.google.com/spreadsheets/d/e/2PACX-1vQgIEKkEjNmA418oM-RkNkd_71VlsKoz97dRKy86e6MwDWE6jJw6z9XWXk3Y1kw9tEr4SnKkTX5aIeX/pub?output=csv",
        question_types=question_types_dict,
        output_location="/Users/arjunshanmugam/Desktop",
        weighting_variable_name="What graduation class are you?")

    return bop_results

def test_produce_figures(bop_results_instance):

    bop_results_instance.calculate_weights(truncate=True)
    bop_results_instance.recode()
    bop_results_instance.plot_figures()

    """
    Sort happiness by Relationship, Covid take, concentration, class year
    Crosstabs on grade inflation opinions by concentration, legacy, and class year
    Happiness on every other question
    
    """
def test_calculate_moe(bop_results_instance):
    with pytest.raises(RuntimeError):
        bop_results_instance.calculate_moe()
    with pytest.raises(RuntimeError):
        bop_results_instance.calculate_weights(truncate=True)
        bop_results_instance.calculate_moe()