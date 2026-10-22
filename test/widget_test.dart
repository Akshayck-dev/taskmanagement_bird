// Unit tests for TaskFlow's models and workflow status logic.
//
// (This replaces the default Flutter template "counter" test, which did
// not match this app and could never pass.)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow_minimalist/models/app_models.dart';

TaskModel makeTask({bool isDone = false, String? status}) {
  return TaskModel(
    id: 't1',
    title: 'Test task',
    description: 'desc',
    assignedTo: 'user2',
    assignedBy: 'user1',
    isDone: isDone,
    status: status,
    deadline: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('TaskModel status workflow', () {
    test('new task defaults to To Do', () {
      expect(makeTask().status, TaskStatus.todo);
    });

    test('legacy done task derives Done status', () {
      expect(makeTask(isDone: true).status, TaskStatus.done);
    });

    test('explicit status wins over isDone', () {
      expect(makeTask(isDone: false, status: TaskStatus.inProgress).status,
          TaskStatus.inProgress);
    });

    test('toMap keeps isDone in sync with status', () {
      final map = makeTask(status: TaskStatus.done).toMap();
      expect(map['status'], TaskStatus.done);
      expect(map['isDone'], isTrue);

      final map2 = makeTask(status: TaskStatus.inProgress).toMap();
      expect(map2['status'], TaskStatus.inProgress);
      expect(map2['isDone'], isFalse);
    });
  });

  group('Recurrence', () {
    test('defaults to none and serialises', () {
      expect(makeTask().recurrence, 'none');
      final t = TaskModel(
        id: 't2',
        title: 'Weekly report',
        description: '',
        assignedTo: 'user2',
        assignedBy: 'user1',
        isDone: false,
        recurrence: 'weekly',
        deadline: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );
      expect(t.toMap()['recurrence'], 'weekly');
      expect(TaskRecurrence.label('weekly'), 'Weekly');
      expect(TaskRecurrence.label('none'), 'No repeat');
    });
  });

  group('TaskStatus labels', () {
    test('labels are human readable', () {
      expect(TaskStatus.label(TaskStatus.todo), 'To Do');
      expect(TaskStatus.label(TaskStatus.inProgress), 'In Progress');
      expect(TaskStatus.label(TaskStatus.done), 'Done');
      expect(TaskStatus.label('unknown'), 'To Do');
    });
  });

  group('CommentModel parsing', () {
    test('missing timestamp does not crash', () {
      final c = CommentModel.fromMap({
        'uid': 'u1',
        'userName': 'A',
        'userPhoto': '',
        'text': 'hi',
      });
      expect(c.text, 'hi');
    });

    test('timestamp round-trips', () {
      final dt = DateTime(2026, 5, 4, 12, 30);
      final c = CommentModel.fromMap({
        'uid': 'u1',
        'userName': 'A',
        'userPhoto': '',
        'text': 'hi',
        'timestamp': Timestamp.fromDate(dt),
      });
      expect(c.timestamp, dt);
    });
  });

  group('Pickers', () {
    test('categories and priorities are non-empty and unique', () {
      expect(TaskCategories.all.toSet().length, TaskCategories.all.length);
      expect(TaskPriorities.all, containsAll(['Normal', 'Urgent']));
      expect(TaskPriorities.all.length, 2);
      // Legacy values map onto the two levels.
      expect(TaskPriorities.normalize('High'), 'Urgent');
      expect(TaskPriorities.normalize('Medium'), 'Normal');
      expect(TaskPriorities.normalize('Low'), 'Normal');
      expect(TaskPriorities.normalize('Urgent'), 'Urgent');
      expect(TaskPriorities.normalize(null), 'Normal');
    });
  });
}
