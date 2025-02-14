import 'package:flutter/material.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:get/get.dart';

class QuizBottomSheet extends StatefulWidget {
  final Map<String, dynamic> quiz;

  const QuizBottomSheet({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  State<QuizBottomSheet> createState() => _QuizBottomSheetState();
}

class _QuizBottomSheetState extends State<QuizBottomSheet> {
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _showExplanation = false;
  int _correctAnswers = 0;
  bool _quizCompleted = false;

  List<Map<String, dynamic>> get questions =>
      List<Map<String, dynamic>>.from(widget.quiz['questions']);

  Map<String, dynamic> get currentQuestion => questions[_currentQuestionIndex];

  void _handleAnswerSelection(String answer) {
    if (_showExplanation)
      return; // Prevent changing answer after showing explanation

    setState(() {
      _selectedAnswer = answer;
      _showExplanation = true;
      if (answer == currentQuestion['correctAnswer']) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < questions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _showExplanation = false;
      } else {
        _quizCompleted = true;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswer = null;
      _showExplanation = false;
      _correctAnswers = 0;
      _quizCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: _quizCompleted
                ? _buildQuizComplete()
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Progress indicator
                          LinearProgressIndicator(
                            value:
                                (_currentQuestionIndex + 1) / questions.length,
                            backgroundColor:
                                AppTheme.primaryColor.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),

                          // Question counter
                          Text(
                            'Question ${_currentQuestionIndex + 1}/${questions.length}',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Question
                          Text(
                            currentQuestion['question'],
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Options
                          ...List<String>.from(currentQuestion['options'])
                              .map((option) => _buildOptionButton(option)),

                          if (_showExplanation) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _selectedAnswer ==
                                        currentQuestion['correctAnswer']
                                    ? AppTheme.successColor.withOpacity(0.1)
                                    : AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedAnswer ==
                                            currentQuestion['correctAnswer']
                                        ? 'Correct!'
                                        : 'Incorrect',
                                    style: TextStyle(
                                      color: _selectedAnswer ==
                                              currentQuestion['correctAnswer']
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    currentQuestion['explanation'],
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _nextQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _currentQuestionIndex < questions.length - 1
                                    ? 'Next Question'
                                    : 'See Results',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(String option) {
    final bool isSelected = _selectedAnswer == option;
    final bool isCorrect = option == currentQuestion['correctAnswer'];
    final bool showResult = _showExplanation;

    Color getBackgroundColor() {
      if (!showResult)
        return isSelected
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor;
      if (isCorrect) return AppTheme.successColor.withOpacity(0.1);
      if (isSelected) return AppTheme.errorColor.withOpacity(0.1);
      return AppTheme.surfaceColor;
    }

    Color getBorderColor() {
      if (!showResult)
        return isSelected ? AppTheme.primaryColor : Colors.transparent;
      if (isCorrect) return AppTheme.successColor;
      if (isSelected) return AppTheme.errorColor;
      return Colors.transparent;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleAnswerSelection(option),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: getBackgroundColor(),
              border: Border.all(color: getBorderColor()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (showResult && isCorrect)
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                  )
                else if (showResult && isSelected && !isCorrect)
                  Icon(
                    Icons.cancel,
                    color: AppTheme.errorColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizComplete() {
    final percentage = (_correctAnswers / questions.length * 100).round();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Quiz Complete!',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 8,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_correctAnswers/${questions.length}',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            _getFeedbackMessage(percentage),
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _restartQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFeedbackMessage(int percentage) {
    if (percentage == 100) {
      return 'Perfect! You\'ve mastered this content! 🎉';
    } else if (percentage >= 80) {
      return 'Great job! You\'ve shown excellent understanding!';
    } else if (percentage >= 60) {
      return 'Good effort! Keep practicing to improve further.';
    } else {
      return 'Keep learning! Review the content and try again.';
    }
  }
}
