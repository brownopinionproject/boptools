"""
Tests the BOPResults class.
"""
from boptools.BOPResults import BOPResults
def test_produce_figures():
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
    bop_results = BOPResults(responses="https://docs.google.com/spreadsheets/d/e/2PACX-1vQgIEKkEjNmA418oM-RkNkd_71VlsKoz97dRKy86e6MwDWE6jJw6z9XWXk3Y1kw9tEr4SnKkTX5aIeX/pub?output=csv",
                             question_types=question_types_dict,
                             output="/Users/arjunshanmugam/Desktop",
                             weighting_variable_name="What graduation class are you?")

    bop_results.calculate_weights(truncate=True)
    bop_results.recode()
    bop_results.plot_figures()