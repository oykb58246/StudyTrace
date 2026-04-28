class AiFlashCard {
  final String question;
  final String answer;
  final String courseName;
  final String hint;

  const AiFlashCard({
    required this.question,
    required this.answer,
    this.courseName = '',
    this.hint = '',
  });
}
