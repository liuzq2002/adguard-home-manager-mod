import 'dart:convert';

class LogsList {
  int loadStatus = 0;
  LogsData? logsData;

  LogsList({
    required this.loadStatus,
    this.logsData
  });
}

LogsData logsFromJson(String str) => LogsData.fromJson(json.decode(str));

String logsToJson(LogsData data) => json.encode(data.toJson());

class LogsData {
  List<Log> data;
  final DateTime? oldest;

  LogsData({
    required this.data,
    this.oldest,
  });

  factory LogsData.fromJson(Map<String, dynamic> json) => LogsData(
    data: json["data"] != null
        ? List<Log>.from(json["data"].map((x) => Log.fromJson(x)))
        : [],
    oldest: json["oldest"] is String && json["oldest"].isNotEmpty
        ? DateTime.tryParse(json["oldest"])
        : null,
  );

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
    "oldest": oldest?.toIso8601String(),
  };
}

class Log {
  final bool? answerDnssec;
  final bool cached;
  final String client;
  final ClientInfo? clientInfo;
  final String? clientProto;
  final String elapsedMs;
  final Question question;
  final String reason;
  final List<Rule> rules;
  final String? status;
  final DateTime time;
  final String? upstream;
  final String? destination;
  final List<Answer> answer;
  final int? filterId;
  final String? rule;
  final List<Answer>? originalAnswer;

  Log({
    this.answerDnssec,
    required this.cached,
    required this.client,
    this.clientInfo,
    required this.clientProto,
    required this.elapsedMs,
    required this.question,
    required this.reason,
    required this.rules,
    this.status,
    required this.time,
    required this.upstream,
    this.destination,
    required this.answer,
    this.filterId,
    this.rule,
    this.originalAnswer,
  });

  factory Log.fromJson(Map<String, dynamic> json) => Log(
    answerDnssec: json["answer_dnssec"],
    cached: json["cached"] == true,
    client: json["client"]?.toString() ?? "",
    clientInfo: json["client_info"] != null ? ClientInfo.fromJson(json["client_info"]) : null,
    clientProto: json["client_proto"]?.toString(),
    elapsedMs: json["elapsedMs"]?.toString() ?? "",
    question: Question.fromJson(json["question"]),
    reason: json["reason"]?.toString() ?? "NotFilteredNotFound",
    rules: json["rules"] != null ? List<Rule>.from(json["rules"].map((x) => Rule.fromJson(x))) : [],
    status: json["status"]?.toString(),
    time: DateTime.tryParse(json["time"]?.toString() ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0),
    upstream: json["upstream"]?.toString(),
    destination: json["destination"]?.toString(),
    answer: json["answer"] != null ? List<Answer>.from(json["answer"].map((x) => Answer.fromJson(x))) : [],
    filterId: json["filterId"],
    rule: json["rule"],
    originalAnswer: json["original_answer"] == null ? null : List<Answer>.from(json["original_answer"].map((x) => Answer.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "answer_dnssec": answerDnssec,
    "cached": cached,
    "client": client,
    "client_info": clientInfo?.toJson(),
    "client_proto": clientProto,
    "elapsedMs": elapsedMs,
    "question": question.toJson(),
    "reason":reason,
    "rules": List<dynamic>.from(rules.map((x) => x.toJson())),
    "status": status,
    "time": time.toIso8601String(),
    "upstream": upstream,
    "destination": destination,
    "answer": List<dynamic>.from(answer.map((x) => x.toJson())),
    "filterId": filterId,
    "rule": rule,
    "original_answer": originalAnswer == null ? null : List<dynamic>.from(originalAnswer!.map((x) => x.toJson())),
  };
}

class Answer {
  final String type;
  final String value;
  final int ttl;

  Answer({
    required this.type,
    required this.value,
    required this.ttl,
  });

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
    type: json["type"]?.toString() ?? "",
    value: json["value"]?.toString() ?? "",
    ttl: json["ttl"] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "type": type,
    "value": value,
    "ttl": ttl,
  };
}

class ClientInfo {
  final Whois whois;
  final String name;
  final String disallowedRule;
  final bool disallowed;

  ClientInfo({
    required this.whois,
    required this.name,
    required this.disallowedRule,
    required this.disallowed,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) => ClientInfo(
    whois: json["whois"] != null ? Whois.fromJson(Map<String, dynamic>.from(json["whois"])) : Whois(),
    name: json["name"]?.toString() ?? "",
    disallowedRule: json["disallowed_rule"]?.toString() ?? "",
    disallowed: json["disallowed"] == true,
  );

  Map<String, dynamic> toJson() => {
    "whois": whois.toJson(),
    "name": name,
    "disallowed_rule": disallowedRule,
    "disallowed": disallowed,
  };
}

class Whois {
  Whois();

  factory Whois.fromJson(Map<String, dynamic> json) => Whois();

  Map<String, dynamic> toJson() => {};
}

class Question {
  final String questionClass;
  final String? name;
  final String type;

  Question({
    required this.questionClass,
    required this.name,
    required this.type,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    questionClass: json["class"]?.toString() ?? "",
    name: json["name"]?.toString(),
    type: json["type"]?.toString() ?? "",
  );

  Map<String, dynamic> toJson() => {
    "class": questionClass,
    "name": name,
    "type": type,
  };
}

class Rule {
  final int filterListId;
  final String text;

  Rule({
    required this.filterListId,
    required this.text,
  });


  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
    filterListId: json["filter_list_id"] ?? 0,
    text: json["text"]?.toString() ?? "",
  );

  Map<String, dynamic> toJson() => {
    "filter_list_id": filterListId,
    "text": text,
  };
}
