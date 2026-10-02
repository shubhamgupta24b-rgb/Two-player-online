import 'person.dart';

class GpQuestion {
  final String id;
  final String label; // short button text, e.g. "GLASSES"
  final String prompt; // full question, e.g. "Does the person have glasses?"
  final bool Function(Person) test;
  const GpQuestion(this.id, this.label, this.prompt, this.test);
}

class AskedQuestion {
  final GpQuestion question;
  final bool answer;
  const AskedQuestion(this.question, this.answer);
}
